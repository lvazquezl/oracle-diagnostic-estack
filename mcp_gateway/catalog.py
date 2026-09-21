"""
mcp_gateway.catalog — the certified collector catalog and target catalog.

A collector is exposed only when BOTH hold:
  1. it is listed in mcp_gateway/catalog/collectors.json (explicit allowlist with per-field sanitization
     policy — fields that are not listed are dropped: default deny), and
  2. for kind `sql_query`, the repository's certified query file (queries/**/Q-*.md) exists, is `status: active`,
     `risk_class: R0`, `execution_mode: READ_ONLY`, and its SQL blocks pass the read-only guard below.
The SQL text is NEVER taken from a client: it stays inside the repository file, its SHA-256 is recorded as
provenance, and this gateway does not execute it in fixture mode (real execution adapters are DISABLED).

Targets come from a local JSON file (default: the shipped synthetic fixture targets). A target that is unknown,
disabled, has an unknown version/role, or an unconfirmed license never silently degrades into "allowed".
"""
from __future__ import annotations

import hashlib
import json
import os
import re

from .common import AdapterStatus, CapabilityStatus, GatewayError
from .versions import family_of

PKG_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(PKG_DIR)
DEFAULT_COLLECTORS_FILE = os.path.join(PKG_DIR, "catalog", "collectors.json")
DEFAULT_TARGETS_FILE = os.path.join(PKG_DIR, "config", "targets.fixture.json")
DEFAULT_FIXTURES_DIR = os.path.join(PKG_DIR, "fixtures")

ALIAS_RE = re.compile(r'^[a-z][a-z0-9-]{2,40}$')
COLLECTOR_ID_RE = re.compile(r'^[A-Za-z][A-Za-z0-9_.-]{2,64}$')
ORACLE_VERSIONS = ("10g", "11g", "12c", "18c", "19c", "21c", "23ai")
ROLES = ("PRIMARY", "STANDBY")
FIELD_TYPES = {"identifier", "version_string", "enum", "integer", "integer_or_unlimited", "number", "boolean",
               "timestamp_utc", "signature", "text", "interval_string"}
POLICIES = {"KEEP", "MASK", "HASH", "TOKENIZE", "DROP", "SIGNATURE"}
KINDS = {"sql_query", "alert_log_excerpt", "semantic_os"}
# Any of these tokens inside a certified SQL block means the file is NOT read-only material for this gateway.
_FORBIDDEN_SQL = re.compile(
    r'(?i)\b(insert|update|delete|merge|drop|create|alter|truncate|grant|revoke|execute|exec|call|begin|declare|commit|'
    r'rollback|lock|flashback|purge|rename|comment|audit|noaudit|shutdown|startup|into)\b|dbms_|utl_|sys\.|;\s*\S')


def _load_json(path: str, max_bytes: int = 1_000_000):
    try:
        if os.path.getsize(path) > max_bytes:
            raise ValueError("too large")
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        raise RuntimeError("configuration file could not be loaded")


# --- certified query metadata ----------------------------------------------------------------------

def _find_query_file(query_id: str):
    if not re.fullmatch(r'Q-[A-Z0-9-]{3,60}', query_id):
        return None
    base = os.path.join(REPO_ROOT, "queries")
    for dp, _dn, fn in os.walk(base):
        if f"{query_id}.md" in fn:
            return os.path.join(dp, f"{query_id}.md")
    return None


def _parse_front_matter(text: str) -> dict:
    m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    meta = {}
    if not m:
        return meta
    for line in m.group(1).split("\n"):
        mm = re.match(r'^([a-z_]+):\s*(.*)$', line)
        if not mm:
            continue
        key, val = mm.group(1), mm.group(2).strip()
        if val.startswith("[") and val.endswith("]"):
            meta[key] = [x.strip() for x in val[1:-1].split(",") if x.strip()]
        else:
            meta[key] = val.strip('"')
    return meta


def sql_blocks(text: str) -> list:
    return [b.strip() for b in re.findall(r'```sql\n(.*?)```', text, re.S)]


def assert_read_only_sql(block: str) -> None:
    """Defense in depth on certified SQL: a single SELECT/WITH statement, no DML/DDL/PLSQL/package calls."""
    stripped = re.sub(r'--[^\n]*', '', block)
    stripped = re.sub(r'/\*.*?\*/', '', stripped, flags=re.S).strip()
    if not re.match(r'(?i)^(select|with)\b', stripped) or _FORBIDDEN_SQL.search(stripped.rstrip().rstrip(';')):
        raise RuntimeError("certified query is not a read-only single statement")


def _families(values, what: str) -> list:
    if not isinstance(values, list) or not values:
        raise RuntimeError("invalid version metadata")
    out = []
    for v in values:
        fam = family_of(v)
        if fam is None or fam not in ORACLE_VERSIONS:
            raise RuntimeError("invalid version metadata")
        if fam not in out:
            out.append(fam)
    return out


def _effective_versions(spec: dict, query_meta) -> list:
    """Fail closed: missing or unusable version metadata means NO supported version, never 'all of them'.
    A query-backed collector inherits the versions of its certified query; a semantic (OS) collector must
    declare oracle_version_scope == "ANY" explicitly. A collector may only NARROW that set."""
    if query_meta is not None:
        raw = query_meta.get("supported_oracle_versions")
        base = _families(raw, "query") if isinstance(raw, list) and raw else []
    else:
        base = list(ORACLE_VERSIONS) if spec.get("oracle_version_scope") == "ANY" else []
    declared = spec.get("supported_oracle_versions")
    if declared is not None:
        base = [v for v in base if v in _families(declared, "collector")]
    return base


class Collector:
    def __init__(self, spec: dict, query_meta: dict = None):
        self.spec = spec
        self.collector_id = spec["collector_id"]
        self.kind = spec["kind"]
        self.domain = spec["domain"]
        self.title = spec["title"]
        self.row_limit = int(spec["row_limit"])
        self.params = spec.get("params", {})
        self.output_fields = spec["output_fields"]
        self.rca = spec.get("rca")
        self.adapters = spec.get("adapters", {})
        self.reference = spec.get("reference")
        q = query_meta or {}
        self.query_id = q.get("query_id")
        self.query_sha256 = q.get("sql_sha256")
        self.supported_oracle_versions = _effective_versions(spec, query_meta)
        self.database_role_scope = q.get("database_role_scope", "ANY")
        self.container_scope = q.get("container_scope", "NOT_APPLICABLE")
        self.license_requirements = q.get("license_requirements", "none")
        self.privileges_required = q.get("privileges_required", [])
        self.timeout_seconds = int(q.get("timeout_seconds", 15))
        self.cost_class = q.get("cost_class", "LOW")
        self.risk_class = q.get("risk_class", "R0")

    def public_view(self) -> dict:
        """Metadata safe to show to the model (no SQL text, no paths, no connection details)."""
        return {
            "collector_id": self.collector_id, "kind": self.kind, "domain": self.domain, "title": self.title,
            "risk_class": self.risk_class, "cost_class": self.cost_class, "row_limit": self.row_limit,
            "timeout_seconds": self.timeout_seconds,
            "supported_oracle_versions": self.supported_oracle_versions,
            "database_role_scope": self.database_role_scope, "container_scope": self.container_scope,
            "license_requirements": self.license_requirements, "minimum_privileges": self.privileges_required,
            "parameters": {"max_rows": {"type": "integer", "minimum": 1, "maximum": self.row_limit}},
            "output_fields": {k: {"type": v["type"], "sanitization": v["policy"]} for k, v in self.output_fields.items()},
            "adapter_status": dict(self.adapters), "query_sha256": self.query_sha256,
            "provenance_note": "SQL text is immutable in the repository and is never sent to or accepted from a client",
        }


def load_collectors(path: str = DEFAULT_COLLECTORS_FILE) -> dict:
    data = _load_json(path)
    out = {}
    for spec in data["collectors"]:
        cid = spec["collector_id"]
        if not COLLECTOR_ID_RE.match(cid) or spec["kind"] not in KINDS or cid in out:
            raise RuntimeError("invalid collector catalog")
        for fname, f in spec["output_fields"].items():
            if f["type"] not in FIELD_TYPES or f["policy"] not in POLICIES or not re.fullmatch(r'[a-z_][a-z0-9_]{0,40}', fname):
                raise RuntimeError("invalid field policy in collector catalog")
            # structural rules: identifiers never leave as KEEP, free text is DROP-only, signatures use SIGNATURE only
            violates = ((f['type'] == 'identifier' and f['policy'] not in ('MASK', 'HASH', 'TOKENIZE', 'DROP'))
                        or (f['type'] == 'text' and f['policy'] != 'DROP')
                        or (f['type'] == 'signature' and f['policy'] not in ('SIGNATURE', 'DROP'))
                        or (f['policy'] == 'SIGNATURE' and f['type'] != 'signature'))
            if violates:
                raise RuntimeError("field policy violates the default-deny rules")
        meta = None
        if spec["kind"] in ("sql_query", "alert_log_excerpt"):
            qfile = _find_query_file(cid)
            if qfile is None:
                raise RuntimeError("collector references a query that is not in the certified registry")
            with open(qfile, encoding="utf-8") as f:
                text = f.read()
            fm = _parse_front_matter(text)
            if fm.get("status") != "active" or fm.get("risk_class") != "R0" or fm.get("execution_mode") != "READ_ONLY":
                raise RuntimeError("query is not certified R0 read-only")
            if int(fm.get("max_rows", 0)) < int(spec["row_limit"]) and spec["kind"] == "sql_query":
                raise RuntimeError("collector row_limit exceeds the certified query max_rows")
            blocks = sql_blocks(text)
            for b in blocks:
                assert_read_only_sql(b)
            meta = dict(fm)
            meta["sql_sha256"] = hashlib.sha256("\n".join(blocks).encode("utf-8")).hexdigest() if blocks else None
        out[cid] = Collector(spec, meta)
    return out


# --- targets --------------------------------------------------------------------------------------

class Target:
    def __init__(self, spec: dict):
        self.alias = spec["alias"]
        self.adapter = spec["adapter"]
        self.enabled = bool(spec.get("enabled", False))
        self.oracle_version = family_of(spec["oracle_version"]) if spec.get("oracle_version") is not None else None
        self.role = spec.get("role", "UNKNOWN")
        self.container = spec.get("container", "UNKNOWN")
        self.architecture = spec.get("architecture", {})
        self.license_status = spec.get("license_status", {})
        self.allowed_collectors = frozenset(spec.get("allowed_collectors", []))
        # Declared by an administrator: collectors whose minimum privileges the diagnostic account is known NOT to hold.
        self.missing_privileges = frozenset(spec.get("missing_privileges", []))
        self.budget = {"max_calls": int(spec.get("budget", {}).get("max_calls", 50)),
                       "max_rows": int(spec.get("budget", {}).get("max_rows", 1000))}

    def public_view(self) -> dict:
        return {"target_alias": self.alias, "enabled": self.enabled, "adapter": self.adapter,
                "oracle_version": self.oracle_version or "UNKNOWN", "role": self.role,
                "allowed_collector_count": len(self.allowed_collectors)}


def load_targets(path: str = DEFAULT_TARGETS_FILE, collectors: dict = None) -> dict:
    data = _load_json(path)
    out = {}
    for spec in data["targets"]:
        alias = spec["alias"]
        if not ALIAS_RE.match(alias) or alias in out:
            raise RuntimeError("invalid target catalog")
        if spec.get("oracle_version") is not None and family_of(spec["oracle_version"]) not in ORACLE_VERSIONS:
            raise RuntimeError("invalid target version")      # 'latest', unknown or unsupported majors are refused
        if spec.get("role", "UNKNOWN") not in ROLES + ("UNKNOWN",):
            raise RuntimeError("invalid target role")
        # Connection material must never live in this file.
        if set(spec) & {"password", "dsn", "host", "user", "username", "wallet", "connection_string", "token", "secret"}:
            raise RuntimeError("target catalog must not contain connection material")
        if collectors is not None and not set(spec.get("allowed_collectors", [])) <= set(collectors):
            raise RuntimeError("target allows an uncertified collector")
        if not isinstance(spec.get("missing_privileges", []), list) or (collectors is not None and not set(spec.get("missing_privileges", [])) <= set(collectors)):
            raise RuntimeError("invalid missing_privileges declaration")
        out[alias] = Target(spec)
    return out


# --- capability evaluation (per target, per collector) --------------------------------------------

def evaluate_capability(target: Target, col: Collector, adapter_status: str) -> str:
    """Never assume: unknown version/role, unconfirmed license or a disabled adapter each produce an explicit
    status instead of an attempt."""
    if not target.enabled or adapter_status not in (AdapterStatus.VERIFIED_FIXTURE, AdapterStatus.VERIFIED_LAB):   # anything else never runs
        return CapabilityStatus.DISABLED
    if col.collector_id not in target.allowed_collectors:
        return CapabilityStatus.UNSUPPORTED
    if target.oracle_version is None:
        return CapabilityStatus.ENVIRONMENT_UNKNOWN
    if target.oracle_version not in col.supported_oracle_versions:
        return CapabilityStatus.UNSUPPORTED
    if col.database_role_scope not in ("ANY", None):
        if target.role == "UNKNOWN":
            return CapabilityStatus.ENVIRONMENT_UNKNOWN
        if target.role != col.database_role_scope:
            return CapabilityStatus.NOT_APPLICABLE
    if col.collector_id in target.missing_privileges:
        return CapabilityStatus.INSUFFICIENT_PRIVILEGES
    lic = (col.license_requirements or "none").lower()
    if lic not in ("none", "n/a", ""):
        key = ("diagnostics_pack" if "diagnostic" in lic or "awr" in lic or "ash" in lic
               else "active_data_guard" if "active data guard" in lic else "other_option")
        if target.license_status.get(key) != "CONFIRMED":
            return CapabilityStatus.LICENSE_RESTRICTED
    return CapabilityStatus.SUPPORTED
