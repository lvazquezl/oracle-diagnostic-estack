"""python -m human_evidence request|ingest — see the package docstring and docs/HUMAN_EVIDENCE.md."""
import argparse
import csv
import datetime as _dt
import hashlib
import hmac
import io
import json
import os
import re
import secrets
import sys

from mcp_gateway import catalog
from mcp_gateway.versions import family_of
from mcp_gateway_lab import filesec, sqlsource

from .classify import classify_column, is_number, value_is_identifying, value_is_sensitive

ROOT = catalog.REPO_ROOT
EVIDENCE = os.environ.get("ESTACK_EVIDENCE_DIR") or os.path.join(ROOT, "evidence")   # tests point it at a temp dir
REQUESTS = os.path.join(EVIDENCE, "requests")
RAW = os.path.join(EVIDENCE, "raw")
SANITIZED = os.path.join(EVIDENCE, "sanitized")
OVERRIDES = os.path.join(ROOT, "config", "human-evidence-policies.json")
MAX_FILE_BYTES = 5_000_000
MAX_ROWS = 5000
_REQ_ID = re.compile(r"^ER-\d{8}-\d{6}-[0-9a-f]{6}$")
_ALIAS_RE = re.compile(r"^[a-z][a-z0-9-]{2,40}$")
_SCOPE_RE = re.compile(r"^(ANA|INC|SES)-[A-Za-z0-9-]{3,40}$")
_REPORTER_RE = re.compile(r"^[A-Za-z0-9._-]{2,64}$")
_FAMILY_TO_VERSION = {"10g": "10.2", "11g": "11.2", "12c": "12.2", "18c": "18.0", "19c": "19.0", "21c": "21.0", "23ai": "23.0"}


class HumanEvidenceError(RuntimeError):
    pass


class _Q:                                   # the minimal "collector" shape sqlsource.resolve needs
    def __init__(self, qid):
        self.collector_id, self.kind, self.query_sha256 = qid, "sql_query", None
        path = catalog._find_query_file(qid)
        if path:                                # same file hash the gateway catalog computes (sqlsource re-checks it)
            blocks = catalog.sql_blocks(open(path, encoding="utf-8").read())
            self.query_sha256 = hashlib.sha256("\n".join(blocks).encode("utf-8")).hexdigest() if blocks else None


def _now():
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)


def _write_private(path, text):
    """0600 on POSIX. On Windows the mode is ignored and the file inherits its folder's ACL, so the result is
    verified natively (CHG-ESTACK-LAB-PORTABLE-001): a raw CSV, token map, key or request readable by other users is
    removed and the operation refused, with the fix in the message."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    if not filesec.is_private(path, filesec.PRIVATE):
        try:
            os.remove(path)
        except OSError:
            pass
        raise HumanEvidenceError("the evidence folder is readable by other users; keep the repository under your user "
                                 "profile or restrict it (" + filesec.how_to_fix(filesec.PRIVATE) + ")")


# --- request -------------------------------------------------------------------------------------------------

def make_request(query_id: str, target_alias: str, oracle_version: str, scope: str) -> dict:
    if not _ALIAS_RE.match(target_alias or "") or not _SCOPE_RE.match(scope or ""):
        raise HumanEvidenceError("invalid target alias or scope")
    fam = family_of(oracle_version)
    if fam not in _FAMILY_TO_VERSION:
        raise HumanEvidenceError("oracle_version must be a family such as 19c")
    path = catalog._find_query_file(query_id)
    if path is None:
        raise HumanEvidenceError("unknown certified query")
    meta = catalog._parse_front_matter(open(path, encoding="utf-8").read())
    if str(meta.get("status", "")).strip() != "active" or str(meta.get("execution_mode", "")).strip() != "READ_ONLY":
        raise HumanEvidenceError("query is not an active READ_ONLY certified query")
    try:
        cert = sqlsource.resolve(_Q(query_id), _FAMILY_TO_VERSION[fam])      # same guard + variant resolution as the lab
    except sqlsource.SqlSourceError:
        raise HumanEvidenceError("no certified read-only variant for this query and version")
    now = _now()
    req_id = f"ER-{now:%Y%m%d-%H%M%S}-{secrets.token_hex(3)}"
    doc = {"schema_version": "1.0.0", "request_id": req_id, "created_at_utc": now.isoformat().replace("+00:00", "Z"),
           "scope": scope, "target_alias": target_alias, "oracle_version": fam, "query_id": query_id,
           "variant_id": cert.variant_id, "sql_sha256": cert.sql_sha256, "max_rows": min(int(cert.max_rows), MAX_ROWS),
           "csv_file": os.path.join(EVIDENCE, "inbox", req_id + ".csv")}
    _write_private(os.path.join(REQUESTS, req_id + ".json"), json.dumps(doc, indent=2) + "\n")
    _write_private(os.path.join(REQUESTS, req_id + ".sql"), sqlplus_script(doc, cert.sql))
    return doc


def sqlplus_script(doc: dict, sql: str) -> str:
    return (f"-- {doc['request_id']} — {doc['query_id']} ({doc['variant_id']}), sha256 {doc['sql_sha256']}\n"
            f"-- READ-ONLY certified SQL from queries/. Run it as the diagnostic user on target {doc['target_alias']}.\n"
            "SET MARKUP CSV ON QUOTE ON\nSET FEEDBACK OFF\nSET TERMOUT OFF\nSET PAGESIZE 50000\nSET LINESIZE 32767\n"
            f"SPOOL {doc['csv_file']}\n{sql};\nSPOOL OFF\nSET TERMOUT ON\n")


# --- ingest --------------------------------------------------------------------------------------------------

def _collector_fields(query_id: str):
    """output_fields of the gateway collector for this query (hand-written or factory-generated catalog), or None
    when the gateway has no spec for it."""
    c = catalog.load_collectors().get(query_id)
    return dict(c.output_fields) if c is not None and c.kind == "sql_query" else None


def _column_aliases(query_id: str) -> dict:
    """Driver column -> catalog field, exactly as the lab adapter renames them (e.g. name -> parameter_name)."""
    from mcp_gateway_lab.oracle_sql import SUPPORTED_COLLECTORS
    return dict(SUPPORTED_COLLECTORS.get(query_id, {}))


_SPEC_SHAPE = {"integer": lambda v: bool(re.match(r"^[+-]?\d{1,15}$", v)), "integer_or_unlimited": lambda v: bool(re.match(r"^[+-]?\d{1,15}$", v)) or v == "UNLIMITED",
               "number": is_number, "parameter_name": lambda v: bool(re.match(r"^_{0,2}[a-z][a-z0-9_]{0,79}$", v)),
               "version_string": lambda v: bool(re.match(r"^\d{1,2}(\.\d{1,3}){1,5}$", v))}


def _overrides(query_id: str) -> dict:
    if not os.path.exists(OVERRIDES):
        return {}
    return json.load(open(OVERRIDES, encoding="utf-8")).get("queries", {}).get(query_id, {})


def _scope_key(scope: str) -> bytes:
    path = os.path.join(RAW, ".human-evidence-keys", scope + ".key")
    if not os.path.exists(path):
        _write_private(path, secrets.token_hex(32))
    return bytes.fromhex(open(path, encoding="utf-8").read().strip())


def _alias(key: bytes, column: str, value: str, prefix: str) -> str:
    return prefix + "-" + hmac.new(key, (column.lower() + "\x00" + value).encode("utf-8"), hashlib.sha256).hexdigest()[:10]


def _prefix(column: str) -> str:
    c = re.sub(r"[^a-z]", "", column.lower())[:3]
    return c if len(c) == 3 else "val"


def ingest(request_id: str, csv_path: str, reporter: str) -> dict:
    if not _REQ_ID.match(request_id or "") or not _REPORTER_RE.match(reporter or ""):
        raise HumanEvidenceError("invalid request id or reporter id")
    req_path = os.path.join(REQUESTS, request_id + ".json")
    if not os.path.exists(req_path):
        raise HumanEvidenceError("unknown request")
    req = json.load(open(req_path, encoding="utf-8"))
    try:
        cert = sqlsource.resolve(_Q(req["query_id"]), _FAMILY_TO_VERSION[req["oracle_version"]])
    except sqlsource.SqlSourceError:
        raise HumanEvidenceError("the certified query can no longer be resolved")
    if cert.sql_sha256 != req["sql_sha256"]:
        raise HumanEvidenceError("certified SQL changed since the request: issue a new request")
    if not os.path.isfile(csv_path) or os.path.getsize(csv_path) > MAX_FILE_BYTES:
        raise HumanEvidenceError("CSV missing or too large")
    text = open(csv_path, encoding="utf-8", errors="replace").read()
    rows = list(csv.reader(io.StringIO(text)))
    rows = [r for r in rows if any(c.strip() for c in r)]
    if not rows:
        raise HumanEvidenceError("empty CSV (no header)")
    header = [h.strip().lower() for h in rows[0]]
    if len(set(header)) != len(header) or not all(re.match(r"^[a-z0-9_#$]{1,64}$", h) for h in header):
        raise HumanEvidenceError("unexpected CSV header")
    body = rows[1:]
    limitations = []
    if len(body) > req["max_rows"]:
        body = body[:req["max_rows"]]
        limitations.append("ROWS_TRUNCATED_TO_LIMIT")
    if any(len(r) != len(header) for r in body):
        raise HumanEvidenceError("ragged CSV rows")
    spec = _collector_fields(req["query_id"])
    overrides = {} if spec is not None else _overrides(req["query_id"])
    if spec is not None:                           # rename driver columns the way the lab adapter does
        aliases = _column_aliases(req["query_id"])
        header = [aliases.get(h, h) for h in header]
        if len(set(header)) != len(header):
            raise HumanEvidenceError("unexpected CSV header")
    key = _scope_key(req["scope"])
    cols, tokens, dropped_values = [], {}, 0
    for i, name in enumerate(header):
        values = [r[i] if r[i] != "" else None for r in body]
        if spec is not None:                       # the gateway collector spec is authoritative for its own query
            f = spec.get(name)
            if f is None:
                cols.append({"name": name, "policy": "DROP", "reason": "not_in_collector_spec"})
                continue
            policy, _ = classify_column(name, values, f["policy"])
            cols.append({"name": name, "policy": policy, "reason": "collector_spec" if policy == f["policy"] else "name:sensitive",
                         "alias_prefix": f.get("alias_prefix"), "enum": f.get("values") if f.get("type") == "enum" else None,
                         "shape": f.get("type")})
            continue
        policy, reason = classify_column(name, values, overrides.get(name))
        cols.append({"name": name, "policy": policy, "reason": reason})
    out_rows = []
    for r in body:
        o = {}
        for i, col in enumerate(cols):
            raw = r[i]
            if raw == "" or col["policy"] == "DROP":
                continue
            if value_is_sensitive(raw):
                dropped_values += 1
                continue
            pol = col["policy"]
            if col.get("enum") and raw not in col["enum"]:          # outside the collector's enum: never kept verbatim
                dropped_values += 1
                continue
            if col.get("shape") in _SPEC_SHAPE and not _SPEC_SHAPE[col["shape"]](raw):   # wrong shape for the spec type
                dropped_values += 1
                continue
            typed = col.get("enum") or col.get("shape") in _SPEC_SHAPE           # value already proven to be of the spec type
            if pol == "KEEP" and not typed and not is_number(raw) and value_is_identifying(raw):
                pol = "MASK"
            if pol == "KEEP":
                o[col["name"]] = (int(raw) if re.match(r"^[+-]?\d+$", raw) else float(raw)) if is_number(raw) else raw
            elif pol == "MASK":
                o[col["name"]] = _alias(key, col["name"], raw, col.get("alias_prefix") or _prefix(col["name"]))
            elif pol == "HASH":
                o[col["name"]] = _alias(key, col["name"], raw, "h")
            elif pol == "TOKENIZE" and is_number(raw):           # a bare number identifies nothing: keep it
                o[col["name"]] = int(raw) if re.match(r"^[+-]?\d+$", raw) else float(raw)
            elif pol == "TOKENIZE":
                t = _alias(key, col["name"], raw, "tok")
                tokens[t] = raw
                o[col["name"]] = t
        out_rows.append(o)
    for c in cols:                                                  # internal hints, not part of the evidence schema
        c.pop("alias_prefix", None)
        c.pop("enum", None)
        c.pop("shape", None)
    if dropped_values:
        limitations.append(f"SENSITIVE_VALUES_DROPPED:{dropped_values}")
    if any(c["policy"] == "DROP" for c in cols):
        limitations.append("COLUMNS_DROPPED:" + ",".join(c["name"] for c in cols if c["policy"] == "DROP"))
    evd = "EVD-HR-" + request_id[3:]
    now = _now().isoformat().replace("+00:00", "Z")
    doc = {"schema_version": "1.0.0", "evidence_id": evd,
           "provenance": {"kind": "HUMAN_REPORTED", "real_observation": True, "observed_by_estack": False,
                          "reporter_id": reporter, "reported_at_utc": now, "request_id": request_id, "scope": req["scope"],
                          "target_alias": req["target_alias"], "oracle_version": req["oracle_version"],
                          "query_id": req["query_id"], "variant_id": req["variant_id"], "sql_sha256": req["sql_sha256"]},
           "validation_level": "HUMAN_REPORTED", "confidence_ceiling": "PROBABLE_CAUSE",
           "columns": cols, "rows": out_rows, "row_count": len(out_rows), "limitations": limitations}
    blob = json.dumps(out_rows, ensure_ascii=False, sort_keys=True)   # the values that came from the database
    if value_is_sensitive(blob):                                      # last gate: nothing secret-shaped may be written
        raise HumanEvidenceError("sanitized output still contains a secret-shaped value")
    _write_private(os.path.join(SANITIZED, evd + ".json"), json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    if tokens:
        _write_private(os.path.join(RAW, request_id + ".tokens.json"), json.dumps(tokens, indent=2, ensure_ascii=False) + "\n")
    return doc


# --- CLI -----------------------------------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(prog="python -m human_evidence", description="Human-reported evidence for certified queries (read-only).")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("request", help="create an evidence request (certified SQL + SQL*Plus spool script)")
    r.add_argument("--query", required=True)
    r.add_argument("--target", required=True)
    r.add_argument("--version", required=True, help="Oracle family, e.g. 19c")
    r.add_argument("--scope", required=True, help="ANA-*/INC-*/SES-* (masking aliases are stable within a scope)")
    g = sub.add_parser("ingest", help="sanitize the DBA's CSV into evidence/sanitized")
    g.add_argument("--request", required=True)
    g.add_argument("--file", required=True)
    g.add_argument("--reporter", required=True, help="reviewer id of the person who ran the SQL, e.g. REV-DBA01")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "request":
            doc = make_request(a.query, a.target, a.version, a.scope)
            print(json.dumps({"request_id": doc["request_id"], "query_id": doc["query_id"], "variant_id": doc["variant_id"],
                              "sql_script": os.path.join(REQUESTS, doc["request_id"] + ".sql"), "csv_file": doc["csv_file"]}, indent=2))
        else:
            doc = ingest(a.request, a.file, a.reporter)
            print(json.dumps({"evidence_id": doc["evidence_id"], "row_count": doc["row_count"],
                              "columns": {c["name"]: c["policy"] for c in doc["columns"]}, "limitations": doc["limitations"],
                              "sanitized_file": os.path.join(SANITIZED, doc["evidence_id"] + ".json")}, indent=2))
        return 0
    except (HumanEvidenceError, ValueError) as e:
        print(f"human_evidence: refused ({e})", file=sys.stderr)
        return 2
