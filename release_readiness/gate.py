"""
release_readiness.gate — the release readiness gate.

Every check EXECUTES something (the real gateway over stdio, the real catalog and capability evaluation, an AST
scan of the sources, the registry verifier, the governance validators, `git diff --check`, the evidence
verifier). A sentence in a document never satisfies a check. Any failure exits non-zero.

Verdict logic (fail closed):
    release_gate = FAIL          if any check failed
                   INCONCLUSIVE  if none failed but a check (e.g. evidence) could not be established
                   PASS          only if every check passed AND the evidence tree identity is VERIFIED

The three readiness answers are derived, never asserted:
    READY_FOR_RELEASE                 release_gate == PASS
    READY_FOR_LOCAL_FIXTURE_PILOT     release_gate == PASS and the fixture chain is fully fixture-tested
    READY_FOR_REAL_ENVIRONMENT_PILOT  needs a real adapter at PILOT_VALIDATED/CERTIFIED with a valid pilot record,
                                      a code status of VERIFIED_LAB and an enabled target — none exists today
"""
from __future__ import annotations

import ast
import json
import os
import re
import shlex

from . import evidence, fingerprint, governance, registry
from .common import (FAIL, INCONCLUSIVE, NOT_APPLICABLE, PASS, REAL_ENVIRONMENT_STATES, SCHEMA_VERSION, TOOL_VERSION, TREE_VERIFIED,
                     ReadinessError, dumps_pretty, now_utc, worst)
from .redact import redact_text, residual_personal_paths
from .runner import git, probe_gateway

DOC_REQUIREMENTS = {
    "docs/PRODUCTION_READINESS.md": ("Alcance real", "Estados de madurez", "Criterios por entorno", "Tres decisiones de preparación"),
    "docs/OPERATIONS_RUNBOOK.md": ("Instalación local", "Healthcheck", "Observabilidad y logging", "Recuperación del gateway",
                                   "Rotación y revocación de credenciales", "Retención y borrado", "Desinstalación"),
    "docs/SECURITY_AND_PRIVACY.md": ("Modelo de amenazas", "Flujo de evidencia", "Frontera de confianza", "Retención y privacidad", "Riesgos residuales"),
    "docs/RELEASE_AND_ROLLBACK.md": ("Pruebas y evidencias", "Revisión y publicación", "Reversa manual"),
    "docs/GOVERNANCE_AND_EVOLUTION.md": ("Roles", "Ciclo de vida", "Cambio normal, urgente y excepción", "Excepciones", "Conocimiento"),
    "docs/PILOT_ACCEPTANCE_CHECKLIST.md": ("Piloto local con fixtures", "Piloto de entorno real", "Bloqueos"),
    "docs/PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md": ("Descubrimiento", "Matriz de brechas"),
}
GOVERNANCE_FILES = ("config/governance/risk-register.json", "config/governance/lifecycle-records.json")
FORBIDDEN_TOOL_PROPERTIES = frozenset({"sql", "query", "command", "cmd", "shell", "script", "path", "file", "filename", "url", "uri", "dsn",
                                       "connection", "connection_string", "host", "hostname", "user", "username", "password", "secret",
                                       "token", "env", "args", "argv", "eval", "code"})
FORBIDDEN_IMPORTS = frozenset({"subprocess", "socket", "ssl", "http", "urllib", "ftplib", "smtplib", "telnetlib", "socketserver", "xmlrpc",
                               "asyncio", "ctypes", "pickle", "marshal", "shelve", "importlib", "webbrowser", "requests", "paramiko",
                               "oracledb", "cx_Oracle", "pyodbc", "multiprocessing", "concurrent"})
FORBIDDEN_CALLS = frozenset({"eval", "exec", "__import__"})
FORBIDDEN_ATTR_CALLS = frozenset({"os.system", "os.popen", "os.startfile", "os.execv", "os.execve", "os.execl", "os.execlp", "os.spawnl",
                                  "os.spawnv", "os.kill", "os.fork"})
ENV_ATTRS = frozenset({"os.environ", "os.getenv", "os.putenv"})
WRITE_ATTR_CALLS = frozenset({"os.remove", "os.unlink", "os.rmdir", "os.rename", "os.replace", "os.makedirs", "os.mkdir", "os.chmod",
                              "shutil.rmtree", "shutil.copy", "shutil.copyfile", "shutil.move"})
SCAN_PACKAGES = {  # package -> policy
    "mcp_gateway": {"env": False, "writes": False},
    "rca_engine": {"env": False, "writes": True},
    "change_documentation_knowledge": {"env": False, "writes": True},
    "capacity_engine": {"env": True, "writes": True},
    "release_readiness": {"env": False, "writes": True, "subprocess_only_in": "runner.py", "env_only_in": "runner.py"},
}
TEXT_EXTENSIONS = (".md", ".py", ".sh", ".json", ".yaml", ".yml", ".txt", ".cfg", ".toml")


def _check(cid: str, status: str, detail: str, data=None) -> dict:
    c = {"id": cid, "status": status, "detail": detail}
    if data is not None:
        c["data"] = data
    return c


# --- individual checks -------------------------------------------------------------------------------
def check_git_state(root: str, require_clean: bool) -> tuple:
    state = evidence._git_state(root)
    dirty = state["status_entries"] > 0
    if require_clean and dirty:
        return _check("C01_GIT_STATE", FAIL, "the tree is not clean and a clean tree was required", state), state
    return _check("C01_GIT_STATE", PASS, f"branch {state['branch']}, HEAD {state['head'][:12]}, {'uncommitted changes present' if dirty else 'clean'}", state), state


def check_registry(root: str, facts=None) -> dict:
    try:
        res = registry.verify_registry(root, facts=facts)
    except ReadinessError:
        return _check("C02_REGISTRY_CONSISTENCY", FAIL, "the capability registry is missing or malformed")
    f = res["findings"]
    return _check("C02_REGISTRY_CONSISTENCY", FAIL if f else PASS,
                  f"{len(f)} finding(s): " + "; ".join(sorted({x['code'] for x in f})) if f else f"{sum(res['counts'].values())} components consistent with the code",
                  {"counts": res["counts"], "maturity_summary": res["maturity_summary"], "findings": f[:20]})


def _closed_objects(schema, path="") -> list:
    bad = []
    if isinstance(schema, dict):
        if schema.get("type") == "object" and schema.get("additionalProperties") is not False:
            bad.append(path or "$")
        for k, v in schema.items():
            if k == "properties" and isinstance(v, dict):
                for name, sub in v.items():
                    if name.lower() in FORBIDDEN_TOOL_PROPERTIES:
                        bad.append(f"{path}/{name}:forbidden-property")
                    bad += _closed_objects(sub, f"{path}/{name}")
            elif k == "items":
                bad += _closed_objects(v, path + "/[]")
    return bad


def check_mcp_surface(root: str, registered_tools) -> dict:
    """Start the real gateway over stdio and inspect what it actually exposes and how it refuses."""
    msgs = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "gate", "version": "0"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "os.exec_shell", "arguments": {"cmd": "id"}}},
        {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {
            "collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-primary-19c", "sql": "select 1 from dual"}}},
        {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {
            "collector_id": "Q-DISC-IDENTITY-001", "target_alias": "lab-oracle-disabled"}}},
        {"jsonrpc": "2.0", "id": 6, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {
            "collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-primary-19c"}}},
    ]
    try:
        out = probe_gateway(root, msgs)
    except ReadinessError:
        return _check("C03_MCP_SURFACE", FAIL, "the gateway could not be started")
    if out["timed_out"] or out["returncode"] != 0:
        return _check("C03_MCP_SURFACE", FAIL if not out["timed_out"] else INCONCLUSIVE, "the gateway did not exit cleanly on EOF")
    replies = {}
    for line in out["stdout_lines"]:
        try:
            m = json.loads(line)
        except ValueError:
            return _check("C03_MCP_SURFACE", FAIL, "stdout carries something that is not a JSON-RPC message")
        if not isinstance(m, dict) or m.get("jsonrpc") != "2.0" or "id" not in m:
            return _check("C03_MCP_SURFACE", FAIL, "stdout carries a non-protocol message")
        replies[m["id"]] = m
    if set(replies) != {1, 2, 3, 4, 5, 6}:
        return _check("C03_MCP_SURFACE", FAIL, "the gateway did not answer every request exactly once")
    tools = replies[2].get("result", {}).get("tools", [])
    names = sorted(t.get("name", "") for t in tools)
    if names != sorted(registered_tools):
        return _check("C03_MCP_SURFACE", FAIL, "the tools/list surface differs from the registry")
    open_or_forbidden = [(t["name"], _closed_objects(t.get("inputSchema"))) for t in tools if _closed_objects(t.get("inputSchema"))]
    if open_or_forbidden:
        return _check("C03_MCP_SURFACE", FAIL, "a tool schema is open or accepts a forbidden free-form parameter", {"tools": [n for n, _ in open_or_forbidden]})

    def denied(reply):
        r = reply.get("result", {})
        return r.get("isError") is True
    if not (denied(replies[3]) and denied(replies[4]) and denied(replies[5])):
        return _check("C03_MCP_SURFACE", FAIL, "an unknown tool, an extra argument or a disabled target was not denied")
    ok = replies[6].get("result", {})
    env = ok.get("structuredContent", {}) if isinstance(ok, dict) else {}
    if ok.get("isError") or env.get("sanitization_status") != "SANITIZED" or env.get("provenance", {}).get("real_observation") is not False:
        return _check("C03_MCP_SURFACE", FAIL, "the fixture collection did not return sanitized fixture evidence")
    if out["stderr_text"].strip():
        return _check("C03_MCP_SURFACE", FAIL, "the gateway wrote to stderr although audit output was disabled")
    return _check("C03_MCP_SURFACE", PASS, f"{len(names)} tools; unknown tool, extra argument and disabled target denied; stdout is protocol-only; EOF exits 0")


def check_adapters(root: str, facts) -> dict:
    from mcp_gateway import catalog
    problems = []
    for name, status in facts["adapters"].items():
        if name != "fixture" and status in ("VERIFIED_FIXTURE", "VERIFIED_LAB"):
            problems.append(f"{name}:{status}")
    targets = catalog.load_targets(catalog.DEFAULT_TARGETS_FILE, facts["collectors"])
    for t in targets.values():
        if t.enabled and t.adapter != "fixture":
            problems.append(f"target:{t.alias}:enabled-on-{t.adapter}")
    return _check("C04_REAL_ADAPTERS_NOT_ENABLED", FAIL if problems else PASS,
                  ("real adapter path enabled: " + ", ".join(problems)) if problems else "no real adapter is verified/enabled and no shipped target uses one")


def _scan_file(path: str, rel: str, policy: dict) -> list:
    try:
        tree = ast.parse(open(path, "rb").read())
    except (OSError, SyntaxError, ValueError):
        return [f"{rel}:0:unparseable"]
    base = os.path.basename(path)
    out = []
    for node in ast.walk(tree):
        line = getattr(node, "lineno", 0)
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
            for m in mods:
                top = m.split(".")[0]
                if top in FORBIDDEN_IMPORTS and not (top == "subprocess" and policy.get("subprocess_only_in") == base):
                    out.append(f"{rel}:{line}:import {top}")
        elif isinstance(node, ast.Call):
            fn = node.func
            if isinstance(fn, ast.Name) and fn.id in FORBIDDEN_CALLS:
                out.append(f"{rel}:{line}:call {fn.id}")
            dotted = _dotted(fn)
            if dotted in FORBIDDEN_ATTR_CALLS:
                out.append(f"{rel}:{line}:call {dotted}")
            if dotted in WRITE_ATTR_CALLS and not policy["writes"]:
                out.append(f"{rel}:{line}:write {dotted}")
            if isinstance(fn, ast.Name) and fn.id == "open" and not policy["writes"] and len(node.args) >= 2 and isinstance(node.args[1], ast.Constant) \
                    and isinstance(node.args[1].value, str) and set(node.args[1].value) & set("wax+"):
                out.append(f"{rel}:{line}:open-for-write")
        elif isinstance(node, ast.Attribute):
            dotted = _dotted(node)
            if dotted in ENV_ATTRS and not policy["env"] and policy.get("env_only_in") != base:
                out.append(f"{rel}:{line}:environment {dotted}")
    return out


def _dotted(node) -> str:
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
        return ".".join(reversed(parts))
    return ""


def check_static_security(root: str) -> dict:
    violations, scanned = [], 0
    for pkg, policy in SCAN_PACKAGES.items():
        base = os.path.join(root, pkg)
        if not os.path.isdir(base):
            violations.append(f"{pkg}:missing-package")
            continue
        for dp, dn, fn in os.walk(base):
            dn[:] = [d for d in dn if d != "__pycache__"]
            for f in sorted(fn):
                if f.endswith(".py"):
                    full = os.path.join(dp, f)
                    violations += _scan_file(full, os.path.relpath(full, root).replace(os.sep, "/"), policy)
                    scanned += 1
    return _check("C05_STATIC_SECURITY_SCAN", FAIL if violations else PASS,
                  f"{len(violations)} violation(s)" if violations else f"{scanned} source files: no network, subprocess (outside runner.py), dynamic import, eval/exec, environment reads or writes where forbidden",
                  {"violations": violations[:30]} if violations else None)


def check_compatibility() -> dict:
    """Execute the version resolver and the capability evaluation over synthetic collectors/targets."""
    from mcp_gateway import catalog
    from mcp_gateway.versions import compare_versions, family_of
    bad = []
    fam = [("19.0.0.0.0", "19c"), ("19c", "19c"), ("11.2.0.4", "11g"), ("12.1.0.2", "12c"), ("12.2.0.1", "12c"), ("23ai", "23ai"),
           ("23.4.0.24.05", "23ai"), ("10.2.0.5", "10g"), ("9.2.0.8", None), ("latest", None), ("", None), ("19g", None), ("99", None),
           (None, None), ("19.0; drop table x", None), ("21", "21c"), ("18.0.0.0.0", "18c")]
    for raw, want in fam:
        if family_of(raw) != want:
            bad.append(f"family_of({raw!r})")
    for a, b, want in (("9.2", "10.1", -1), ("11.2.0.10", "11.2.0.4", 1), ("19", "19.0.0", 0), ("x", "1", None), ("19.1", "19.0", 1)):
        if compare_versions(a, b) != want:
            bad.append(f"compare({a},{b})")

    def col(license_="none", role="ANY", versions=("19c",), meta=True):
        spec = {"collector_id": "Q-GATE-TEST-001", "kind": "sql_query", "domain": "oracle", "title": "t", "row_limit": 5, "params": {},
                "output_fields": {"a": {"type": "integer", "policy": "KEEP"}}, "adapters": {}}
        m = {"license_requirements": license_, "database_role_scope": role}
        if meta:
            m["supported_oracle_versions"] = list(versions)
        return catalog.Collector(spec, m)

    def tgt(version="19c", role="PRIMARY", lic=None):
        return catalog.Target({"alias": "gate-test", "adapter": "fixture", "enabled": True, "oracle_version": version, "role": role,
                               "license_status": lic or {}, "allowed_collectors": ["Q-GATE-TEST-001"]})
    S = "VERIFIED_FIXTURE"
    cases = [
        (tgt(None), col(), S, "ENVIRONMENT_UNKNOWN"), (tgt("11g"), col(), S, "UNSUPPORTED"), (tgt(), col(meta=False), S, "UNSUPPORTED"),
        (tgt(), col("Diagnostics Pack"), S, "LICENSE_RESTRICTED"), (tgt(lic={"diagnostics_pack": "CONFIRMED"}), col("Diagnostics Pack"), S, "SUPPORTED"),
        (tgt(), col("Active Data Guard"), S, "LICENSE_RESTRICTED"), (tgt(), col(), "DISABLED", "DISABLED"), (tgt(), col(), "CONTRACT_ONLY", "DISABLED"),
        (tgt(role="PRIMARY"), col(role="STANDBY"), S, "NOT_APPLICABLE"), (tgt(role="UNKNOWN"), col(role="STANDBY"), S, "ENVIRONMENT_UNKNOWN"),
        (tgt(), col(), S, "SUPPORTED"),
    ]
    for i, (t, c, adapter_status, want) in enumerate(cases):
        if catalog.evaluate_capability(t, c, adapter_status) != want:
            bad.append(f"capability_case_{i}")
    return _check("C06_COMPATIBILITY_AND_LICENSE_GATES", FAIL if bad else PASS,
                  ("failed: " + ", ".join(bad)) if bad else f"{len(fam)} version cases, 5 comparison cases and {len(cases)} capability cases behave as required")


def _headings(text: str) -> list:
    in_fence, out = False, []
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence and line.startswith("#"):
            out.append(line)
    return out


def _fenced_commands(text: str) -> list:
    cmds, in_bash = [], False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("```"):
            in_bash = (not in_bash) and s[3:].strip() in ("bash", "sh", "shell")
        elif in_bash and (s.startswith("python -m release_readiness") or s.startswith("python -m mcp_gateway")):
            cmds.append(re.sub(r'\\$', '', s).strip())
    return cmds


def validate_documented_commands(text: str) -> list:
    """Every `python -m release_readiness ...` / `python -m mcp_gateway ...` line in a bash block must parse with the REAL parser."""
    from mcp_gateway import cli as gw_cli
    from . import cli as rr_cli
    problems = []
    for cmd in _fenced_commands(text):
        argv = shlex.split(re.sub(r'<[^>]+>', 'x', cmd), posix=True)
        parser = rr_cli.build_parser() if argv[2] == "release_readiness" else gw_cli.build_parser()
        try:
            import contextlib
            import io
            with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
                parser.parse_args(argv[3:])
        except SystemExit as e:
            if e.code not in (0, None):
                problems.append(cmd)
    return problems


def check_documentation(root: str) -> dict:
    problems = []
    for rel, headings in DOC_REQUIREMENTS.items():
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            problems.append(f"{rel}:missing")
            continue
        text = open(path, encoding="utf-8").read()
        heads = " || ".join(_headings(text))
        for h in headings:
            if h not in heads:
                problems.append(f"{rel}:heading '{h}'")
        for m in re.finditer(r'\]\(([^)\s#]+)(?:#[^)\s]*)?\)', text):
            target = m.group(1)
            if re.match(r'^[a-z][a-z0-9+.-]*:', target) or target.startswith("/"):
                continue
            if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), target))):
                problems.append(f"{rel}:broken-link {target}")
        for cmd in validate_documented_commands(text):
            problems.append(f"{rel}:invalid-command {cmd[:60]}")
        for ref in set(re.findall(r'`(tests/test_[A-Za-z0-9_.+-]+\.sh)`', text)):
            if not os.path.isfile(os.path.join(root, ref)):
                problems.append(f"{rel}:missing-test {ref}")
    return _check("C07_DOCUMENTATION", FAIL if problems else PASS,
                  f"{len(problems)} problem(s)" if problems else f"{len(DOC_REQUIREMENTS)} documents: required sections present, links resolve, documented commands parse with the real CLIs, referenced tests exist",
                  {"problems": problems[:20]} if problems else None)


def check_governance(root: str, now: str = None) -> dict:
    findings = []
    try:
        risk = registry.load_json_strict(os.path.join(root, GOVERNANCE_FILES[0]))
        recs = registry.load_json_strict(os.path.join(root, GOVERNANCE_FILES[1]))
    except ReadinessError:
        return _check("C08_GOVERNANCE_RECORDS", FAIL, "governance records are missing or malformed")
    findings += governance.validate_risk_register(risk, now) + governance.validate_records_document(recs, now)
    return _check("C08_GOVERNANCE_RECORDS", FAIL if findings else PASS,
                  ("findings: " + ", ".join(sorted({f['code'] for f in findings}))) if findings else "risk register and lifecycle records are valid",
                  {"findings": findings[:20]} if findings else None)


def _untracked_text_files(root: str) -> list:
    raw = git(root, "ls-files", "-z", "--others", "--exclude-standard").stdout
    return [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p and p.decode("utf-8", "replace").lower().endswith(TEXT_EXTENSIONS)]


def check_whitespace(root: str) -> dict:
    """`git diff --check` for tracked changes plus an equivalent check for untracked text files (git ignores those)."""
    tracked = git(root, "diff", "--check", check=False)
    problems = [] if tracked.returncode == 0 else ["tracked:git-diff-check"]
    for rel in _untracked_text_files(root):
        data = open(os.path.join(root, rel), "rb").read()
        if b"\r" in data:
            problems.append(f"{rel}:CR")
        elif re.search(rb'[ \t]+\n', data):
            problems.append(f"{rel}:trailing-whitespace")
        elif data.endswith(b"\n\n"):
            problems.append(f"{rel}:blank-line-at-eof")
    return _check("C09_WHITESPACE_AND_DIFF_CHECK", FAIL if problems else PASS,
                  ("problems: " + ", ".join(problems[:10])) if problems else "git diff --check clean; untracked text files have no CR, trailing whitespace or blank EOF",
                  {"problems": problems[:20]} if problems else None)


def check_evidence(root: str, evidence_dir) -> tuple:
    if not evidence_dir:
        return _check("C10_EVIDENCE_PACKAGE", INCONCLUSIVE, "no evidence package was supplied: a release cannot be judged without a verified full-regression package"), None
    res = evidence.verify_package(evidence_dir, root)
    failed = [c["id"] for c in res["checks"] if c["status"] == FAIL]
    inconc = [c["id"] for c in res["checks"] if c["status"] == INCONCLUSIVE]
    detail = f"package {res.get('run_id', '?')}: {res['result']}, tree identity {res['tree_identity']}"
    if failed:
        detail += "; failed: " + ",".join(failed)
    if inconc:
        detail += "; inconclusive: " + ",".join(inconc)
    return _check("C10_EVIDENCE_PACKAGE", res["result"], detail, {"checks": [{"id": c["id"], "status": c["status"]} for c in res["checks"]],
                                                              "verified": res.get("verified")}), res


# --- readiness -------------------------------------------------------------------------------------------
def compute_readiness(release_gate: str, tree_identity: str, reg_doc: dict, facts: dict, checks: dict, targets: dict) -> dict:
    comps = reg_doc["components"]
    by = lambda k: [c for c in comps if c.get("kind") == k]
    chain = by("mcp_tool") + by("collector") + [c for c in by("adapter") if c.get("adapter_name") == "fixture"] + \
        [c for c in by("engine") if c.get("package") in ("rca_engine", "change_documentation_knowledge", "mcp_gateway")]
    chain_ok = bool(chain) and all(c["maturity"] == "TESTED_WITH_SYNTHETIC_FIXTURES" for c in chain)
    release_ok = release_gate == PASS and tree_identity == TREE_VERIFIED
    supporting = all(checks.get(k, {}).get("status") == PASS for k in ("C03_MCP_SURFACE", "C07_DOCUMENTATION", "C08_GOVERNANCE_RECORDS"))
    local_blockers = []
    if not release_ok:
        local_blockers.append("RELEASE_GATE_NOT_PASSED")
    if not chain_ok:
        local_blockers.append("FIXTURE_CHAIN_NOT_FIXTURE_TESTED")
    if not supporting:
        local_blockers.append("SUPPORTING_CHECKS_NOT_PASSED")
    real_blockers = []
    if not release_ok:
        real_blockers.append("RELEASE_GATE_NOT_PASSED")
    qualifying = []
    for c in by("adapter"):
        name = c.get("adapter_name")
        if name == "fixture":
            continue
        code_status = facts["adapters"].get(name)
        if c["maturity"] in REAL_ENVIRONMENT_STATES and code_status == "VERIFIED_LAB" and any(t.enabled and t.adapter == name for t in targets.values()):
            qualifying.append(name)
        else:
            real_blockers.append(f"ADAPTER_{name}_IS_{c['maturity']}")
    if not qualifying:
        real_blockers += ["NO_ADAPTER_AT_PILOT_VALIDATED_OR_CERTIFIED", "NO_APPROVED_TARGET_ENVIRONMENT_ENABLED", "NO_REAL_ENVIRONMENT_INTEGRATION_EVIDENCE"]
    return {"READY_FOR_RELEASE": release_ok, "READY_FOR_LOCAL_FIXTURE_PILOT": release_ok and chain_ok and supporting,
            "READY_FOR_REAL_ENVIRONMENT_PILOT": release_ok and bool(qualifying) and not [b for b in real_blockers if b.startswith("ADAPTER_") and not any(b.startswith(f"ADAPTER_{q}_") for q in qualifying)],
            "local_fixture_pilot_blockers": local_blockers, "real_environment_pilot_blockers": sorted(set(real_blockers)),
            "real_environment_plan": "docs/PILOT_ACCEPTANCE_CHECKLIST.md"}


# --- orchestration -----------------------------------------------------------------------------------------
def run_gate(root: str, *, evidence_dir: str = None, require_clean: bool = False, now: str = None, _evidence_check=None) -> dict:
    """Run every check and return the (unsanitized-for-paths) report dict. Never raises for a failing check.
    `_evidence_check` is a TEST HOOK (Python API only, not reachable from the CLI): a callable (root, evidence_dir) ->
    (check, verify_result) used to exercise the verdict/readiness derivation without a 2.5 h regression."""
    if not isinstance(root, str) or not os.path.isdir(root):
        raise ReadinessError("E_ROOT")
    root = os.path.realpath(root)
    checks, by_id = [], {}

    def add(c):
        checks.append(c)
        by_id[c["id"]] = c
    try:
        c, state = check_git_state(root, require_clean)
    except ReadinessError:
        c, state = _check("C01_GIT_STATE", FAIL, "git information could not be obtained"), {}
    add(c)
    reg_doc, facts, targets = None, None, {}
    try:
        reg_doc = registry.load_registry(root)
        facts = registry.actual_facts(root)
        from mcp_gateway import catalog
        targets = catalog.load_targets(catalog.DEFAULT_TARGETS_FILE, facts["collectors"])
    except Exception:
        pass
    if reg_doc is None or facts is None:
        add(_check("C02_REGISTRY_CONSISTENCY", FAIL, "the capability registry or the code facts could not be loaded"))
        add(_check("C03_MCP_SURFACE", INCONCLUSIVE, "skipped: registry unavailable"))
        add(_check("C04_REAL_ADAPTERS_NOT_ENABLED", INCONCLUSIVE, "skipped: registry unavailable"))
    else:
        add(check_registry(root, facts))
        add(check_mcp_surface(root, [c["tool_name"] for c in reg_doc["components"] if c.get("kind") == "mcp_tool"]))
        add(check_adapters(root, facts))
    for fn in (lambda: check_static_security(root), check_compatibility, lambda: check_documentation(root), lambda: check_governance(root, now), lambda: check_whitespace(root)):
        try:
            add(fn())
        except Exception as e:                                # a crashing check is a failed check, never a pass
            add(_check("C99_CHECK_CRASHED", FAIL, f"a check raised {type(e).__name__}"))
    ev_check, ev_res = (_evidence_check or check_evidence)(root, evidence_dir)
    add(ev_check)
    static_result = worst([c["status"] for c in checks if c["id"] != "C10_EVIDENCE_PACKAGE"])
    release_gate = worst([c["status"] for c in checks])
    tree_identity = ev_res["tree_identity"] if ev_res else "UNVERIFIED"
    if release_gate == PASS and tree_identity != TREE_VERIFIED:
        release_gate = INCONCLUSIVE
    readiness = compute_readiness(release_gate, tree_identity, reg_doc, facts, by_id, targets) if reg_doc and facts else \
        {"READY_FOR_RELEASE": False, "READY_FOR_LOCAL_FIXTURE_PILOT": False, "READY_FOR_REAL_ENVIRONMENT_PILOT": False,
         "local_fixture_pilot_blockers": ["REGISTRY_UNAVAILABLE"], "real_environment_pilot_blockers": ["REGISTRY_UNAVAILABLE"], "real_environment_plan": "docs/PILOT_ACCEPTANCE_CHECKLIST.md"}
    return {"schema_version": SCHEMA_VERSION, "tool_version": TOOL_VERSION, "generated_utc": now or now_utc(), "root": "<REPO_ROOT>",
            "mode": "full" if evidence_dir else "static", "git": {k: state.get(k) for k in ("branch", "head", "status_entries", "untracked_count", "modified_count", "deleted_count")} if state else {},
            "checks": checks, "static_result": static_result, "release_gate": release_gate, "tree_identity": tree_identity,
            "readiness": readiness,
            "limitations": ["Tests and this gate use synthetic fixtures; no real Oracle environment was contacted.",
                            "READY_FOR_REAL_ENVIRONMENT_PILOT requires a real adapter, a pilot record, an approved non-production target and administrator acceptance.",
                            "Approvals recorded in this repository are structural declarations; no authentication or signature exists.",
                            "A PASS is a statement about evidence for this tree; a human still reviews and decides on the release."]}


def exit_code_for(report: dict) -> int:
    return {PASS: 0, FAIL: 1, INCONCLUSIVE: 2}[report["release_gate"]]


_GIT_OID = re.compile(r'^[0-9a-f]{40}\Z')


def _mask_git_object_ids(obj):
    if isinstance(obj, dict):
        return {k: _mask_git_object_ids(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_mask_git_object_ids(v) for v in obj]
    return "GIT-OBJECT-ID" if isinstance(obj, str) and _GIT_OID.match(obj) else obj


def sanitize_report(report: dict, root: str) -> dict:
    """Redact personal paths and refuse to emit anything that looks like a secret. On failure return a minimal withheld report."""
    from change_documentation_knowledge.common import AdvisoryError
    from change_documentation_knowledge.safety import audit_strings
    text = redact_text(json.dumps(report, ensure_ascii=True), root)
    clean = json.loads(text)
    try:
        audit_strings(_mask_git_object_ids(clean))            # a Git commit id is an identifier, not a secret
        assert residual_personal_paths(text.encode("utf-8")) == 0
    except (AdvisoryError, AssertionError):
        return {"schema_version": SCHEMA_VERSION, "tool_version": TOOL_VERSION, "release_gate": INCONCLUSIVE, "tree_identity": "UNVERIFIED",
                "checks": [], "note": "REPORT_WITHHELD_BY_SANITIZATION"}
    return clean


def render_markdown(report: dict) -> str:
    md = evidence._md
    r = report.get("readiness", {})
    L = ["# Release readiness report", "", "> Synthetic-fixture evidence only. Not a certification of any real environment.", "",
         "| Field | Value |", "|---|---|", f"| Release gate | **{md(report['release_gate'])}** |", f"| Static checks | {md(report.get('static_result', '?'))} |",
         f"| Tree identity | {md(report.get('tree_identity'))} |", f"| Mode | {md(report.get('mode', '?'))} |", f"| Generated (UTC) | {md(report.get('generated_utc', '?'))} |",
         f"| READY_FOR_RELEASE | {'YES' if r.get('READY_FOR_RELEASE') else 'NO'} |",
         f"| READY_FOR_LOCAL_FIXTURE_PILOT | {'YES' if r.get('READY_FOR_LOCAL_FIXTURE_PILOT') else 'NO'} |",
         f"| READY_FOR_REAL_ENVIRONMENT_PILOT | {'YES' if r.get('READY_FOR_REAL_ENVIRONMENT_PILOT') else 'NO'} |", "",
         "## Checks", "", "| Check | Status | Detail |", "|---|---|---|"]
    L += [f"| {md(c['id'])} | {md(c['status'])} | {md(c['detail'])} |" for c in report["checks"]]
    L += ["", "## Real-environment pilot blockers", ""] + [f"- {md(b)}" for b in r.get("real_environment_pilot_blockers", [])] or ["- none"]
    L += ["", "## Limitations"] + [f"- {md(x)}" for x in report.get("limitations", [])] + [""]
    return "\n".join(L)


def write_report(report: dict, out_dir: str, root: str) -> None:
    """Write gate-report.json / gate-report.md into a NEW directory outside the repository (never inside it)."""
    out_dir = os.path.abspath(out_dir)
    if evidence._inside(out_dir, root) or os.path.lexists(out_dir):
        raise ReadinessError("E_OUTPUT_DIR")
    os.makedirs(out_dir)
    evidence._write_new(os.path.join(out_dir, "gate-report.json"), dumps_pretty(report).encode("utf-8"))
    evidence._write_new(os.path.join(out_dir, "gate-report.md"), render_markdown(report).encode("utf-8"))
