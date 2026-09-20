"""
mcp_gateway.evidence — the ONLY path from untrusted adapter output to the model.

  untrusted rows -> shape/size validation -> per-field typed validation -> per-field policy
  (KEEP / MASK / HASH / TOKENIZE / DROP / SIGNATURE, default DENY) -> minimization (row limit) ->
  envelope + digest -> opaque evidence reference -> final structured-secret audit.

Properties enforced here (asserted by tests/test_p13_sanitization.sh):
  * A field that is not declared in the collector catalog is dropped (default deny), and only a COUNT of
    dropped/invalid fields is ever reported — never a name or a value.
  * Free text has no path to the model: `text` fields are DROP-only (checked at catalog load).
  * Numbers/booleans/timestamps keep their type and value, but only inside declared ranges; NaN/Infinity,
    booleans-as-integers, nested objects/arrays and non-ASCII identifiers are dropped.
  * MASK/HASH/TOKENIZE outputs are derived from a per-session random salt: not reversible from the output,
    stable inside one session and target (so correlation inside the authorized scope still works), and
    different across sessions and targets.
  * SIGNATURE: a certified error code (typed grammar or catalog membership, Phase 11 allowlist) is kept;
    anything else becomes an opaque SIG- token derived with the Phase 11 tokenizer — never the raw text.
  * Raw rows are never stored: only the sanitized payload and its SHA-256 digest are kept, addressed by an
    unguessable reference bound to (session, target).
"""
from __future__ import annotations

import hashlib
import hmac
import json
import math
import re
import secrets
import time
from datetime import datetime, timezone

from change_documentation_knowledge.safety import audit_strings
from rca_engine.engine import DEFAULT_RULES_PATH
from rca_engine.rules import collect_certified_signatures, load_rules
from rca_engine.sanitize import classify_signature, contains_secret_pattern
from rca_engine.tokenization import derive_signature_token, derive_target_token

from .common import (
    EVIDENCE_TTL_SECONDS, MAX_EVIDENCE_ENTRIES, MAX_ROWS_HARD, SCHEMA_VERSION, GatewayError,
)

_IDENT = re.compile(r'^[A-Za-z][A-Za-z0-9_$#.-]{0,63}$')
_VERSION = re.compile(r'^\d{1,2}(\.\d{1,3}){1,5}$')
_TS = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$')
_INTERVAL = re.compile(r'^[+-]\d{2} \d{2}:\d{2}:\d{2}(\.\d{1,6})?$')
_SIG_RAW_MAX = 96
_NUM_LIMIT = 1e15

_CERTIFIED = collect_certified_signatures(load_rules(DEFAULT_RULES_PATH))


class SessionScope:
    """Per-session secret material and alias tables. Nothing here is ever serialized."""

    def __init__(self):
        self.session_id = "S" + secrets.token_hex(6)
        self._salt = secrets.token_bytes(32)
        self._aliases = {}

    def _mac(self, domain: str, target: str, value: str, n: int) -> str:
        return hmac.new(self._salt, f"{domain}|{target}|{value}".encode("utf-8"), hashlib.sha256).hexdigest()[:n]

    def hash_value(self, target: str, value: str) -> str:
        return "H-" + self._mac("hash", target, value, 12)

    def token_value(self, target: str, value: str) -> str:
        return "TOK-" + self._mac("token", target, value, 16)

    def alias(self, target: str, prefix: str, value: str) -> str:
        key = (target, prefix)
        table = self._aliases.setdefault(key, {})
        if value not in table:
            table[value] = f"{prefix}-A{len(table) + 1}"
        return table[value]

    def target_token(self, alias: str) -> str:
        return derive_target_token(self.session_id, alias)

    def evidence_scope_id(self) -> str:
        # scope id for Phase 11 signature tokens: INC-shaped, never leaves the process
        return "INC-" + self.session_id


def _clean_number(v, spec):
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return None
    if isinstance(v, float) and not math.isfinite(v):
        return None
    if abs(v) > _NUM_LIMIT:
        return None
    lo, hi = spec.get("min", -_NUM_LIMIT), spec.get("max", _NUM_LIMIT)
    return v if lo <= v <= hi else None


def _sanitize_value(spec: dict, raw, scope: SessionScope, target_alias: str):
    """Return (kept, value). kept=False means the value is dropped (counted, never echoed)."""
    t, policy = spec["type"], spec["policy"]
    if policy == "DROP":
        return False, None
    if t == "boolean":
        return (True, raw) if isinstance(raw, bool) else (False, None)
    if t == "integer":
        if isinstance(raw, bool) or not isinstance(raw, int):
            return False, None
        v = _clean_number(raw, spec)
        return (v is not None), v
    if t == "integer_or_unlimited":
        if raw == "UNLIMITED":
            return True, "UNLIMITED"
        if isinstance(raw, bool) or not isinstance(raw, int):
            return False, None
        v = _clean_number(raw, spec)
        return (v is not None), v
    if t == "number":
        v = _clean_number(raw, spec)
        return (v is not None), v
    if t == "enum":
        return (isinstance(raw, str) and raw in spec["values"]), raw
    if t == "version_string":
        return (isinstance(raw, str) and bool(_VERSION.match(raw))), raw
    if t == "interval_string":
        return (isinstance(raw, str) and bool(_INTERVAL.match(raw))), raw
    if t == "timestamp_utc":
        if not isinstance(raw, str) or not _TS.match(raw):
            return False, None
        try:
            dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return False, None
        if dt.tzinfo is None:
            return False, None
        return True, dt.astimezone(timezone.utc).replace(microsecond=0).isoformat()
    if t == "identifier":
        if not isinstance(raw, str) or not _IDENT.match(raw) or contains_secret_pattern(raw.replace(".", " ").replace("$", " ")):
            return False, None
        if policy == "MASK":
            return True, scope.alias(target_alias, spec.get("alias_prefix", "obj"), raw)
        if policy == "HASH":
            return True, scope.hash_value(target_alias, raw)
        if policy == "TOKENIZE":
            return True, scope.token_value(target_alias, raw)
        return False, None
    if t == "signature":
        if not isinstance(raw, str) or not raw or len(raw) > _SIG_RAW_MAX:
            return False, None
        status, canonical, _tok = classify_signature(raw, scope.evidence_scope_id(), _CERTIFIED)
        if status == "CERTIFIED":
            return True, canonical
        return True, derive_signature_token(scope.evidence_scope_id() + "|" + target_alias, raw)
    return False, None                                   # unknown type: deny


def sanitize_rows(collector, raw_rows, scope: SessionScope, target_alias: str, row_cap: int) -> dict:
    """Validate + sanitize adapter output. Raises GatewayError('E_RESULT_INVALID') when the SHAPE is wrong
    (not a list of objects) — fail closed, no partial evidence."""
    if not isinstance(raw_rows, list) or any(not isinstance(r, dict) for r in raw_rows):
        raise GatewayError("E_RESULT_INVALID")
    limitations = []
    cap = max(0, min(row_cap, collector.row_limit, MAX_ROWS_HARD))
    if len(raw_rows) > cap:
        limitations.append("ROWS_TRUNCATED_TO_LIMIT")
    dropped_fields = invalid_values = 0
    rows = []
    for raw in raw_rows[:cap]:
        clean = {}
        for k, v in raw.items():
            if not isinstance(k, str) or k not in collector.output_fields:
                dropped_fields += 1
                continue
            kept, value = _sanitize_value(collector.output_fields[k], v, scope, target_alias)
            if kept:
                clean[k] = value
            elif collector.output_fields[k]["policy"] != "DROP":
                invalid_values += 1
            else:
                dropped_fields += 1
        if clean:
            rows.append(clean)
    if dropped_fields:
        limitations.append(f"FIELDS_DROPPED_BY_POLICY:{dropped_fields}")
    if invalid_values:
        limitations.append(f"INVALID_VALUES_DROPPED:{invalid_values}")
    columns = [c for c in collector.output_fields if collector.output_fields[c]["policy"] != "DROP"]
    return {"columns": columns, "rows": rows, "row_count": len(rows), "limitations": limitations}


def canonical_digest(obj) -> str:
    return hashlib.sha256(json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")).hexdigest()


def final_audit(envelope: dict) -> None:
    """Last gate before serialization: no structured secret pattern may survive anywhere in the envelope."""
    try:
        audit_strings(envelope)
    except Exception:
        raise GatewayError("E_SANITIZATION")


class EvidenceStore:
    """Sanitized evidence only, addressed by unguessable refs bound to (session, target)."""

    def __init__(self, ttl_seconds: float = EVIDENCE_TTL_SECONDS, max_entries: int = MAX_EVIDENCE_ENTRIES, clock=time.monotonic):
        self._items = {}
        self._ttl = ttl_seconds
        self._max = max_entries
        self._clock = clock

    def _purge(self):
        now = self._clock()
        for ref in [r for r, e in self._items.items() if now - e["t"] > self._ttl]:
            del self._items[ref]

    def put(self, session_id: str, target_alias: str, collector_id: str, payload: dict) -> str:
        self._purge()
        if len(self._items) >= self._max:                 # bounded: evict the oldest
            oldest = min(self._items, key=lambda r: self._items[r]["t"])
            del self._items[oldest]
        ref = "EVR-" + secrets.token_hex(12)              # random, not derived from any data
        self._items[ref] = {"session": session_id, "target": target_alias, "collector": collector_id,
                            "payload": payload, "digest": canonical_digest(payload), "t": self._clock()}
        return ref

    def get(self, ref: str, session_id: str, target_alias: str):
        self._purge()
        e = self._items.get(ref)
        # same answer for "missing", "other session", "other target" and "expired": no existence oracle
        if e is None or e["session"] != session_id or e["target"] != target_alias:
            raise GatewayError("E_EVIDENCE_NOT_FOUND")
        if canonical_digest(e["payload"]) != e["digest"]:
            raise GatewayError("E_EVIDENCE_NOT_FOUND")
        return e

    def clear_session(self, session_id: str) -> int:
        gone = [r for r, e in self._items.items() if e["session"] == session_id]
        for r in gone:
            del self._items[r]
        return len(gone)

    def __len__(self):
        return len(self._items)
