"""
release_readiness.registry — the machine-readable capability registry and its verifier.

`config/production-readiness-registry.json` is the single source of truth for WHAT each component is and HOW FAR
it has been verified. It is checked against the running code (MCP tools, collectors, adapters, engines), the
agent registry, the capability matrix and the test scripts on disk. A claim without its evidence is a finding:

  TESTED_WITH_SYNTHETIC_FIXTURES  needs >= 1 existing tests/test_*.sh
  PILOT_VALIDATED / CERTIFIED     need a valid pilot record whose evidence files exist and hash correctly
  UNSUPPORTED / DISABLED          need a stated reason
  an adapter's claim must equal what the code actually reports (no overstated — or stale — status)

Version handling is numeric (mcp_gateway.versions): never lexicographic, and "latest" is never assumed supported.
"""
from __future__ import annotations

import json
import os
import re

from .common import MATURITY_ORDER, REAL_ENVIRONMENT_STATES, ReadinessError, parse_utc, sha256_file

REGISTRY_REL = "config/production-readiness-registry.json"
KINDS = ("adapter", "mcp_tool", "collector", "engine", "agent", "domain", "skill_domain")
PLATFORMS = ("ANY", "Linux", "Solaris", "Windows", "AIX", "HP-UX")
ARCHITECTURES = ("Standalone", "RAC", "CDB", "non-CDB", "ASM", "DataGuard", "ANY")
CODE_STATUS_TO_MATURITY = {"VERIFIED_FIXTURE": "TESTED_WITH_SYNTHETIC_FIXTURES", "VERIFIED_LAB": "PILOT_VALIDATED",
                           "CONTRACT_ONLY": "CONTRACT_ONLY", "DISABLED": "DISABLED", "UNSUPPORTED": "UNSUPPORTED",
                           "NOT_INTEGRATION_TESTED": "CONTRACT_ONLY"}
ENGINES = ("rca_engine", "change_documentation_knowledge", "mcp_gateway", "capacity_engine", "release_readiness")
_COMMON_KEYS = {"id", "kind", "domain", "maturity", "notes", "test_refs"}
_OPTIONAL_COMMON = {"reason", "pilot_record"}
_KIND_KEYS = {
    "adapter": (set(), {"adapter_name"}),
    "mcp_tool": (set(), {"tool_name"}),
    "collector": ({"collector_id", "oracle_versions", "platforms", "architectures", "min_privileges", "license", "limits", "sanitization"}, {"adapters"}),
    "engine": ({"package"}, set()),
    "agent": ({"agent_id"}, {"backed_by"}),
    "domain": ({"capability_matrix_id", "oracle_versions", "license_dependent"}, set()),
    "skill_domain": ({"skill_domain", "skill_count"}, set()),
}
MAX_REGISTRY_BYTES = 1_000_000


def _no_dupes(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate key")
    return dict(pairs)


def load_json_strict(path: str, max_bytes: int = MAX_REGISTRY_BYTES):
    try:
        if os.path.islink(path) or os.path.getsize(path) > max_bytes:
            raise ReadinessError("E_INPUT")
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f, object_pairs_hook=_no_dupes, parse_constant=lambda _c: (_ for _ in ()).throw(ValueError("non-finite")))
    except ReadinessError:
        raise
    except (OSError, ValueError, UnicodeDecodeError):
        raise ReadinessError("E_INPUT")


def load_registry(root: str) -> dict:
    doc = load_json_strict(os.path.join(root, REGISTRY_REL))
    if not isinstance(doc, dict) or doc.get("schema_version") != "1.0.0" or not isinstance(doc.get("components"), list):
        raise ReadinessError("E_REGISTRY")
    return doc


# --- facts taken from the repository / running code -----------------------------------------------------
def actual_facts(root: str) -> dict:
    from mcp_gateway import catalog
    from mcp_gateway.adapters import AdapterRegistry
    from mcp_gateway.gateway import tool_list
    collectors = catalog.load_collectors()
    adapters = AdapterRegistry(catalog.DEFAULT_FIXTURES_DIR)
    facts = {"tools": sorted(t["name"] for t in tool_list()), "collectors": collectors,
             "adapters": {name: adapters.status_of(name) for name in sorted(adapters._adapters)}}
    facts["engines"] = [e for e in ENGINES if os.path.isfile(os.path.join(root, e, "__init__.py"))]
    reg_md = _read_text(os.path.join(root, "agents", "REGISTRY.md"))
    facts["agents"] = sorted(set(re.findall(r'^\| `([a-z0-9-]+)` \|', reg_md, re.M)))
    facts["matrix"] = parse_capability_matrix(_read_text(os.path.join(root, "config", "capability-matrix.yaml")))
    skills_md = _read_text(os.path.join(root, "skills", "REGISTRY.md"))
    counts = {}
    for dom in re.findall(r'^\| `([a-z0-9-]+)/[a-z0-9-]+` \|', skills_md, re.M):
        counts[dom] = counts.get(dom, 0) + 1
    facts["skill_domains"] = counts
    return facts


def _read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


def parse_capability_matrix(text: str) -> dict:
    """{domain_id: {"license_dependent": bool, "versions": {v: status}}} from the flow-style YAML of the matrix."""
    out = {}
    for block in re.split(r'\n  - id: ', text)[1:]:
        dom = block.split("\n", 1)[0].strip()
        lic = re.search(r'license_dependent:\s*(true|false)', block)
        ver = re.search(r'versions:\s*\{([^}]*)\}', block)
        versions = {}
        if ver:
            for part in ver.group(1).split(","):
                if ":" in part:
                    k, v = part.split(":", 1)
                    versions[k.strip()] = v.strip()
        out[dom] = {"license_dependent": bool(lic and lic.group(1) == "true"), "versions": versions}
    return out


def matrix_declared_versions(versions: dict) -> list:
    from mcp_gateway.versions import FAMILIES
    return [v for v in FAMILIES if versions.get(v) in ("SUPPORTED", "PARTIAL", "LICENSE_DEPENDENT")]


# --- pilot records ----------------------------------------------------------------------------------------
_ID_PIL = re.compile(r'^PIL-[A-Za-z0-9-]{3,40}\Z')
_ID_REV = re.compile(r'^REV-[A-Za-z0-9-]{3,40}\Z')
_RUN_ID = re.compile(r'^RUN-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}\Z')
_PILOT_KEYS = {"record_id", "component_id", "environment_class", "oracle_versions", "platform", "readonly_privileges_validated",
               "sanitization_boundary_validated", "integration_run_id", "evidence_files"}


def validate_pilot_record(rec, root: str, component_id: str, need_acceptance: bool) -> list:
    """Problems (list of codes) with a pilot record; empty list = valid. Evidence files must exist under `root` and hash correctly."""
    from mcp_gateway.versions import family_of
    p = []
    if not isinstance(rec, dict):
        return ["PILOT_RECORD_NOT_AN_OBJECT"]
    extra = set(rec) - _PILOT_KEYS - {"administrator_acceptance"}
    if extra or (_PILOT_KEYS - set(rec)):
        p.append("PILOT_RECORD_KEYS")
        return p
    if not (isinstance(rec["record_id"], str) and _ID_PIL.match(rec["record_id"])):
        p.append("PILOT_RECORD_ID")
    if rec["component_id"] != component_id:
        p.append("PILOT_RECORD_COMPONENT_MISMATCH")
    if rec["environment_class"] != "NON_PRODUCTION_REPRESENTATIVE":
        p.append("PILOT_ENVIRONMENT_CLASS")
    vs = rec["oracle_versions"]
    if not (isinstance(vs, list) and vs and all(isinstance(v, str) and family_of(v) for v in vs)):
        p.append("PILOT_ORACLE_VERSIONS")
    if not (isinstance(rec["platform"], str) and rec["platform"] in PLATFORMS and rec["platform"] != "ANY"):
        p.append("PILOT_PLATFORM")
    if rec["readonly_privileges_validated"] is not True:
        p.append("PILOT_READONLY_NOT_VALIDATED")
    if rec["sanitization_boundary_validated"] is not True:
        p.append("PILOT_SANITIZATION_NOT_VALIDATED")
    if not (isinstance(rec["integration_run_id"], str) and _RUN_ID.match(rec["integration_run_id"])):
        p.append("PILOT_INTEGRATION_RUN_ID")
    files = rec["evidence_files"]
    if not (isinstance(files, list) and files):
        p.append("PILOT_EVIDENCE_FILES_MISSING")
    else:
        for f in files:
            ok = isinstance(f, dict) and set(f) == {"path", "sha256"} and isinstance(f["path"], str) and isinstance(f["sha256"], str)
            if not ok or os.path.isabs(f["path"]) or ".." in f["path"].replace("\\", "/").split("/"):
                p.append("PILOT_EVIDENCE_FILE_ENTRY")
                continue
            full = os.path.join(root, f["path"])
            if not os.path.isfile(full) or os.path.islink(full) or sha256_file(full) != f["sha256"]:
                p.append("PILOT_EVIDENCE_FILE_HASH")
    acc = rec.get("administrator_acceptance")
    if need_acceptance:
        if not (isinstance(acc, dict) and set(acc) == {"reviewer_id", "decision", "decision_at_utc", "verification"}
                and isinstance(acc["reviewer_id"], str) and _ID_REV.match(acc["reviewer_id"]) and acc["decision"] == "ACCEPTED"
                and parse_utc(acc["decision_at_utc"]) and acc["verification"] == "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"):
            p.append("PILOT_ADMINISTRATOR_ACCEPTANCE")
    return sorted(set(p))


# --- verification -----------------------------------------------------------------------------------------
def _f(findings: list, code: str, cid: str, detail: str = "") -> None:
    findings.append({"code": code, "component": cid, "detail": detail})


def verify_registry(root: str, registry: dict = None, facts: dict = None) -> dict:
    """Compare the registry with the code. Returns {findings[], counts{}, maturity_summary{}}. Empty findings = consistent."""
    reg = registry if registry is not None else load_registry(root)
    facts = facts if facts is not None else actual_facts(root)
    findings, seen, by_kind = [], set(), {k: {} for k in KINDS}
    for comp in reg["components"]:
        if not isinstance(comp, dict) or not isinstance(comp.get("id"), str) or comp.get("kind") not in KINDS:
            _f(findings, "REG_SCHEMA", str(comp.get("id")) if isinstance(comp, dict) else "?", "component malformed")
            continue
        cid, kind = comp["id"], comp["kind"]
        if cid in seen:
            _f(findings, "REG_DUPLICATE_ID", cid)
        seen.add(cid)
        required, optional = _KIND_KEYS[kind]
        keys = set(comp)
        if (_COMMON_KEYS | required) - keys or keys - (_COMMON_KEYS | required | optional | _OPTIONAL_COMMON):
            _f(findings, "REG_SCHEMA", cid, "keys differ from the schema for this kind")
            continue
        by_kind[kind][cid] = comp
        _verify_maturity(findings, root, comp)
    _verify_adapters(findings, by_kind["adapter"], facts)
    _verify_tools(findings, by_kind["mcp_tool"], facts)
    _verify_collectors(findings, by_kind["collector"], facts)
    _verify_engines(findings, by_kind["engine"], facts)
    _verify_agents(findings, by_kind["agent"], by_kind["engine"], facts)
    _verify_domains(findings, by_kind["domain"], facts)
    _verify_skill_domains(findings, by_kind["skill_domain"], facts)
    summary = {}
    for comp in reg["components"]:
        if isinstance(comp, dict) and comp.get("maturity") in MATURITY_ORDER:
            summary[comp["maturity"]] = summary.get(comp["maturity"], 0) + 1
    return {"findings": findings, "counts": {k: len(v) for k, v in by_kind.items()}, "maturity_summary": dict(sorted(summary.items()))}


def _verify_maturity(findings, root, comp) -> None:
    cid, m = comp["id"], comp["maturity"]
    if m not in MATURITY_ORDER:
        _f(findings, "REG_MATURITY_UNKNOWN", cid, "not a defined maturity state")
        return
    refs = comp["test_refs"]
    if not isinstance(refs, list) or any(not isinstance(r, str) for r in refs):
        _f(findings, "REG_SCHEMA", cid, "test_refs must be a list of paths")
        return
    for r in refs:
        if not re.fullmatch(r'tests/test_[A-Za-z0-9_.+-]+\.sh', r) or not os.path.isfile(os.path.join(root, r)):
            _f(findings, "REG_TEST_REF_MISSING", cid, "a referenced test script does not exist")
    if m == "TESTED_WITH_SYNTHETIC_FIXTURES" and not refs:
        _f(findings, "REG_EVIDENCE_MISSING", cid, "fixture-tested claim without a test script")
    if m in ("UNSUPPORTED", "DISABLED") and not (isinstance(comp.get("reason"), str) and comp["reason"].strip()):
        _f(findings, "REG_REASON_MISSING", cid, "state requires a reason")
    if m in REAL_ENVIRONMENT_STATES:
        rel = comp.get("pilot_record")
        problems = ["PILOT_RECORD_MISSING"]
        if isinstance(rel, str) and not os.path.isabs(rel) and ".." not in rel.replace("\\", "/").split("/") and os.path.isfile(os.path.join(root, rel)):
            try:
                problems = validate_pilot_record(load_json_strict(os.path.join(root, rel)), root, cid, need_acceptance=(m == "CERTIFIED"))
            except ReadinessError:
                problems = ["PILOT_RECORD_UNREADABLE"]
        if problems:
            _f(findings, "REG_PILOT_RECORD_INVALID", cid, ",".join(problems))
    elif comp.get("pilot_record") is not None:
        _f(findings, "REG_PILOT_RECORD_UNEXPECTED", cid, "only PILOT_VALIDATED/CERTIFIED may reference a pilot record")


def _verify_adapters(findings, comps, facts) -> None:
    claimed = {c.get("adapter_name"): c for c in comps.values()}
    for name, status in facts["adapters"].items():
        c = claimed.get(name)
        if c is None:
            _f(findings, "REG_ADAPTER_UNREGISTERED", f"adapter:{name}", "adapter exists in code but not in the registry")
            continue
        expected = CODE_STATUS_TO_MATURITY.get(status, "DISABLED")
        if c["maturity"] != expected:
            over = c["maturity"] in MATURITY_ORDER and MATURITY_ORDER.index(c["maturity"]) > MATURITY_ORDER.index(expected)
            _f(findings, "REG_MATURITY_OVERSTATED" if over else "REG_MATURITY_STALE", c["id"], f"registry says {c['maturity']}, code reports {status}")
    for name in claimed:
        if name not in facts["adapters"]:
            _f(findings, "REG_ADAPTER_NOT_IN_CODE", f"adapter:{name}", "registry lists an adapter the code does not have")


def _verify_tools(findings, comps, facts) -> None:
    claimed = {c.get("tool_name") for c in comps.values()}
    for t in sorted(set(facts["tools"]) - claimed):
        _f(findings, "REG_TOOL_UNREGISTERED", f"mcp_tool:{t}", "tool is exposed by the gateway but not registered")
    for t in sorted(claimed - set(facts["tools"])):
        _f(findings, "REG_TOOL_NOT_IN_CODE", f"mcp_tool:{t}", "registry lists a tool the gateway does not expose")
    for c in comps.values():
        if c["maturity"] in ("TESTED_WITH_SYNTHETIC_FIXTURES",) and not any(a == "VERIFIED_FIXTURE" for a in facts["adapters"].values()):
            _f(findings, "REG_TOOL_WITHOUT_FIXTURE_ADAPTER", c["id"], "no fixture adapter is available")


def _verify_collectors(findings, comps, facts) -> None:
    from mcp_gateway.catalog import POLICIES
    from mcp_gateway.versions import FAMILIES, family_of
    claimed = {c.get("collector_id"): c for c in comps.values()}
    for cid in sorted(set(facts["collectors"]) - set(claimed)):
        _f(findings, "REG_COLLECTOR_UNREGISTERED", f"collector:{cid}", "collector exists in the gateway catalog but not in the registry")
    for cid in sorted(set(claimed) - set(facts["collectors"])):
        _f(findings, "REG_COLLECTOR_NOT_IN_CODE", f"collector:{cid}", "registry lists a collector the catalog does not have")
    for cid, c in claimed.items():
        col = facts["collectors"].get(cid)
        if col is None:
            continue
        cc = c["id"]
        vs = c["oracle_versions"]
        if not (isinstance(vs, list) and vs and all(isinstance(v, str) and v in FAMILIES and family_of(v) == v for v in vs)):
            _f(findings, "REG_VERSION_INVALID", cc, "oracle_versions must be supported family tokens")
        elif sorted(vs, key=FAMILIES.index) != sorted(col.supported_oracle_versions, key=FAMILIES.index):
            _f(findings, "REG_VERSION_MISMATCH", cc, "registry versions differ from the versions the gateway will actually allow")
        if not (isinstance(c["platforms"], list) and c["platforms"] and all(p in PLATFORMS for p in c["platforms"])):
            _f(findings, "REG_PLATFORM_INVALID", cc)
        if not (isinstance(c["architectures"], list) and c["architectures"] and all(a in ARCHITECTURES for a in c["architectures"])):
            _f(findings, "REG_ARCHITECTURE_INVALID", cc)
        if sorted(c["min_privileges"] if isinstance(c["min_privileges"], list) else [None]) != sorted(col.privileges_required):
            _f(findings, "REG_PRIVILEGE_MISMATCH", cc, "registry minimum privileges differ from the certified query")
        if c["license"] != (col.license_requirements or "none"):
            _f(findings, "REG_LICENSE_MISMATCH", cc, "registry license differs from the certified query")
        lim = c["limits"]
        if not (isinstance(lim, dict) and set(lim) == {"rows", "timeout_seconds"} and lim["rows"] == col.row_limit and lim["timeout_seconds"] == col.timeout_seconds):
            _f(findings, "REG_LIMITS_MISMATCH", cc, "registry limits differ from the collector limits")
        policies = [f["policy"] for f in col.output_fields.values()]
        if c["sanitization"] != "DEFAULT_DENY_FIELD_POLICY" or not policies or any(p not in POLICIES for p in policies):
            _f(findings, "REG_SANITIZATION_MISMATCH", cc, "collector output fields lack an explicit sanitization policy")
        if "adapters" in c and set(c["adapters"]) != set(col.adapters):
            _f(findings, "REG_COLLECTOR_ADAPTERS_MISMATCH", cc)


def _verify_engines(findings, comps, facts) -> None:
    claimed = {c.get("package") for c in comps.values()}
    for e in sorted(set(facts["engines"]) - claimed):
        _f(findings, "REG_ENGINE_UNREGISTERED", f"engine:{e}", "package exists but is not registered")
    for e in sorted(claimed - set(facts["engines"])):
        _f(findings, "REG_ENGINE_NOT_IN_CODE", f"engine:{e}", "registry lists a package that does not exist")


def _verify_agents(findings, comps, engines, facts) -> None:
    claimed = {c.get("agent_id"): c for c in comps.values()}
    for a in sorted(set(facts["agents"]) - set(claimed)):
        _f(findings, "REG_AGENT_UNREGISTERED", f"agent:{a}", "agent is in agents/REGISTRY.md but not in the capability registry")
    for a in sorted(set(claimed) - set(facts["agents"])):
        _f(findings, "REG_AGENT_NOT_IN_REGISTRY_MD", f"agent:{a}", "registry lists an agent that agents/REGISTRY.md does not")
    packages = {c.get("package") for c in engines.values()}
    for a, c in claimed.items():
        if "backed_by" in c and c["backed_by"] not in packages:
            _f(findings, "REG_AGENT_BACKING_ENGINE_UNKNOWN", c["id"])


def _verify_domains(findings, comps, facts) -> None:
    claimed = {c.get("capability_matrix_id"): c for c in comps.values()}
    matrix = facts["matrix"]
    for d in sorted(set(matrix) - set(claimed)):
        _f(findings, "REG_DOMAIN_UNREGISTERED", f"domain:{d}", "domain is in the capability matrix but not in the registry")
    for d in sorted(set(claimed) - set(matrix)):
        _f(findings, "REG_DOMAIN_NOT_IN_MATRIX", f"domain:{d}", "registry lists a domain the capability matrix does not")
    for d, c in claimed.items():
        m = matrix.get(d)
        if m is None:
            continue
        if c["oracle_versions"] != matrix_declared_versions(m["versions"]):
            _f(findings, "REG_DOMAIN_VERSIONS_MISMATCH", c["id"], "registry versions differ from the capability matrix")
        if c["license_dependent"] != m["license_dependent"]:
            _f(findings, "REG_DOMAIN_LICENSE_MISMATCH", c["id"])


def _verify_skill_domains(findings, comps, facts) -> None:
    claimed = {c.get("skill_domain"): c for c in comps.values()}
    actual = facts["skill_domains"]
    for d in sorted(set(actual) - set(claimed)):
        _f(findings, "REG_SKILL_DOMAIN_UNREGISTERED", f"skill_domain:{d}")
    for d in sorted(set(claimed) - set(actual)):
        _f(findings, "REG_SKILL_DOMAIN_NOT_IN_REGISTRY_MD", f"skill_domain:{d}")
    for d, c in claimed.items():
        if d in actual and c["skill_count"] != actual[d]:
            _f(findings, "REG_SKILL_COUNT_MISMATCH", c["id"], f"registry {c['skill_count']} vs skills/REGISTRY.md {actual[d]}")
