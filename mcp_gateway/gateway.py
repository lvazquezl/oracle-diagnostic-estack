"""
mcp_gateway.gateway — tool registry, request validation, authorization and the diagnostic dispatcher.

Tools are STATIC and semantic. None accepts SQL, a shell command, a path, a URL or connection parameters:
arguments are certified collector ids, registered target aliases, opaque evidence references and bounded
integers, validated by strict schemas (`additionalProperties: false`).

Authorization is evaluated per (tool, target, collector, version, role, license, adapter, budget) and fails
closed with an explicit capability status. Every response is a sanitized envelope; every failure is a fixed
error code (no client data is echoed).
"""
from __future__ import annotations

import json
import re
import secrets
import time
from datetime import datetime, timezone

from . import bridge
from .adapters import AdapterRegistry, run_with_timeout
from .catalog import COLLECTOR_ID_RE, Target, evaluate_capability
from .common import (
    DEFAULT_OPERATION_TIMEOUT_SECONDS, GATEWAY_NAME, GATEWAY_VERSION, MAX_RESPONSE_BYTES, MAX_SESSION_CALLS,
    SCHEMA_VERSION, CapabilityStatus, GatewayError,
)
from .evidence import EvidenceStore, SessionScope, canonical_digest, final_audit, sanitize_rows
from .schemas import check_schema, validate

_ALIAS_PATTERN = r'[a-z][a-z0-9-]{2,40}'
_COLLECTOR_PATTERN = r'[A-Za-z][A-Za-z0-9_.-]{2,64}'
_REF_PATTERN = r'EVR-[0-9a-f]{24}'

TOOLS = {
    "diagnostics.list_capabilities": {
        "description": ("List which targets, collectors and adapters this LOCAL gateway really supports, with an explicit "
                        "capability status per target. Read-only; fixture mode is the only enabled adapter."),
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    "diagnostics.describe_collector": {
        "description": ("Describe one certified collector: domain, supported versions, role/container scope, license, minimum "
                        "privileges, limits and output fields with their sanitization policy. Never returns SQL text."),
        "inputSchema": {"type": "object", "properties": {"collector_id": {"type": "string", "maxLength": 64, "pattern": _COLLECTOR_PATTERN}},
                        "required": ["collector_id"], "additionalProperties": False},
    },
    "diagnostics.collect": {
        "description": ("Run ONE certified read-only collector against ONE registered target alias and return sanitized, minimized "
                        "evidence plus an opaque evidence reference. No SQL, shell, path or connection input exists. In this "
                        "release the data is SYNTHETIC fixture data (provenance: FIXTURE)."),
        "inputSchema": {"type": "object", "properties": {
            "collector_id": {"type": "string", "maxLength": 64, "pattern": _COLLECTOR_PATTERN},
            "target_alias": {"type": "string", "maxLength": 41, "pattern": _ALIAS_PATTERN},
            "max_rows": {"type": "integer", "minimum": 1, "maximum": 200}},
            "required": ["collector_id", "target_alias"], "additionalProperties": False},
    },
    "diagnostics.get_evidence": {
        "description": ("Retrieve previously collected SANITIZED evidence by opaque reference within the same session and target. "
                        "Raw data is never stored or returned."),
        "inputSchema": {"type": "object", "properties": {
            "evidence_ref": {"type": "string", "maxLength": 28, "pattern": _REF_PATTERN},
            "target_alias": {"type": "string", "maxLength": 41, "pattern": _ALIAS_PATTERN}},
            "required": ["evidence_ref", "target_alias"], "additionalProperties": False},
    },
    "diagnostics.analyze_incident": {
        "description": ("Run the local Phase 11 RCA engine over sanitized evidence collected in this session and hand the RCA state "
                        "to the Phase 12 change advisory (text only, execution_status NOT_EXECUTED_BY_ESTACK) and knowledge-candidate "
                        "state. Nothing is executed, approved or published; a non-confirmed RCA stays non-confirmed."),
        "inputSchema": {"type": "object", "properties": {
            "target_alias": {"type": "string", "maxLength": 41, "pattern": _ALIAS_PATTERN},
            "evidence_refs": {"type": "array", "maxItems": 10, "items": {"type": "string", "maxLength": 28, "pattern": _REF_PATTERN}}},
            "required": ["target_alias", "evidence_refs"], "additionalProperties": False},
    },
}
for _name, _t in TOOLS.items():
    check_schema(_t["inputSchema"])                       # registration-time sanity: a permissive schema is a bug


def tool_list() -> list:
    return [{"name": n, "description": t["description"], "inputSchema": t["inputSchema"]} for n, t in TOOLS.items()]


class Audit:
    """Local audit: one JSON line per tool call with ONLY these keys — never arguments, evidence or errors' text."""
    KEYS = ("ts_utc", "tool_id", "collector_id", "target_token", "status", "error_code", "duration_ms", "request_id", "session")

    def __init__(self, sink=None):
        self._sink = sink
        self.records = []

    def record(self, **fields):
        rec = {k: fields.get(k) for k in self.KEYS}
        rec["ts_utc"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
        self.records.append(rec)
        self.records[:] = self.records[-500:]
        if self._sink is not None:
            try:
                self._sink(json.dumps(rec, sort_keys=True))
            except Exception:
                pass


class Session:
    def __init__(self):
        self.scope = SessionScope()
        self.calls = 0
        self.target_calls = {}
        self.target_rows = {}


class Gateway:
    def __init__(self, collectors: dict, targets: dict, adapters: AdapterRegistry, audit: Audit = None,
                 store: EvidenceStore = None, operation_timeout: float = DEFAULT_OPERATION_TIMEOUT_SECONDS):
        self.collectors = collectors
        self.targets = targets
        self.adapters = adapters
        self.audit = audit or Audit()
        self.store = store or EvidenceStore()
        self.operation_timeout = operation_timeout

    # -- envelope helpers ------------------------------------------------------------------------
    def _base(self, tool_id, session, request_id, target: Target = None, collector_id: str = None) -> dict:
        return {"tool_id": tool_id, "request_id": request_id, "schema_version": SCHEMA_VERSION,
                "gateway": {"name": GATEWAY_NAME, "version": GATEWAY_VERSION},
                "collector_id": collector_id, "target_token": session.scope.target_token(target.alias) if target else None}

    def error_envelope(self, tool_id, request_id, err: GatewayError, session=None, target=None, collector_id=None) -> dict:
        env = {"status": "ERROR", "tool_id": tool_id, "request_id": request_id, "schema_version": SCHEMA_VERSION,
               "collector_id": collector_id, "target_token": session.scope.target_token(target.alias) if (session and target) else None,
               "capability_status": err.capability_status, "sanitization_status": "NOT_APPLICABLE_NO_DATA",
               "evidence_refs": [], "limitations": [], "error": {"code": err.code, "message": err.message}}
        return env

    # -- entry point -----------------------------------------------------------------------------
    def call(self, session: Session, name: str, arguments) -> tuple:
        """Returns (envelope, is_error). Never raises."""
        request_id = "REQ-" + secrets.token_hex(6)
        t0 = time.monotonic()
        tool = TOOLS.get(name) if isinstance(name, str) else None
        target = collector = None
        try:
            if tool is None:
                raise GatewayError("E_TOOL_UNKNOWN")
            args = validate(arguments if arguments is not None else {}, tool["inputSchema"])
            handler = getattr(self, "_tool_" + name.split(".", 1)[1])
            envelope = handler(session, request_id, args)
            envelope.setdefault("status", "OK")
            target = self.targets.get(args.get("target_alias")) if isinstance(args, dict) else None
            final_audit(envelope)
            if len(json.dumps(envelope, ensure_ascii=True).encode("utf-8")) > MAX_RESPONSE_BYTES:
                raise GatewayError("E_OUTPUT_TOO_LARGE")
            err_code = None
            is_error = envelope.get("status") == "ERROR"
        except GatewayError as e:
            target = self.targets.get(arguments.get("target_alias")) if isinstance(arguments, dict) and isinstance(arguments.get("target_alias"), str) else None
            envelope = self.error_envelope(name if tool else "unknown", request_id, e, session, target)
            err_code, is_error = e.code, True
        except Exception:
            envelope = self.error_envelope(name if tool else "unknown", request_id, GatewayError("E_INTERNAL"), session)
            err_code, is_error = "E_INTERNAL", True
        self.audit.record(tool_id=envelope["tool_id"], collector_id=envelope.get("collector_id"), target_token=envelope.get("target_token"),
                          status=envelope["status"], error_code=err_code or (envelope.get("error") or {}).get("code"),
                          duration_ms=int((time.monotonic() - t0) * 1000), request_id=request_id, session=session.scope.session_id)
        return envelope, is_error

    # -- helpers ----------------------------------------------------------------------------------
    def _target(self, alias: str) -> Target:
        t = self.targets.get(alias)
        if t is None:
            raise GatewayError("E_TARGET_UNKNOWN")
        return t

    def _authorize(self, session: Session, target: Target, collector, count_call: bool = True):
        if not target.enabled:
            raise GatewayError("E_TARGET_DISABLED", CapabilityStatus.DISABLED)
        adapter_status = self.adapters.status_of(target.adapter)
        if collector.collector_id not in target.allowed_collectors:
            raise GatewayError("E_COLLECTOR_NOT_ALLOWED", CapabilityStatus.UNSUPPORTED)
        cap = evaluate_capability(target, collector, adapter_status)
        if cap != CapabilityStatus.SUPPORTED:
            raise GatewayError("E_CAPABILITY", cap)
        if count_call:
            if session.calls >= MAX_SESSION_CALLS or session.target_calls.get(target.alias, 0) >= target.budget["max_calls"] \
                    or session.target_rows.get(target.alias, 0) >= target.budget["max_rows"]:
                raise GatewayError("E_BUDGET_EXCEEDED")
        return cap

    # -- tools ------------------------------------------------------------------------------------
    def _tool_list_capabilities(self, session, request_id, args):
        env = self._base("diagnostics.list_capabilities", session, request_id)
        targets = []
        for alias in sorted(self.targets):
            t = self.targets[alias]
            adapter_status = self.adapters.status_of(t.adapter)
            caps = {cid: (evaluate_capability(t, c, adapter_status) if cid in t.allowed_collectors else CapabilityStatus.UNSUPPORTED)
                    for cid, c in sorted(self.collectors.items())}
            v = t.public_view()
            v["adapter_status"] = adapter_status
            v["capabilities"] = caps
            targets.append(v)
        env.update({"status": "OK", "capability_status": CapabilityStatus.SUPPORTED, "sanitization_status": "SANITIZED",
                    "evidence_refs": [], "provenance": {"kind": "CATALOG", "real_observation": False},
                    "adapters": self.adapters.describe(), "targets": targets,
                    "collectors": [{"collector_id": cid, "domain": c.domain, "kind": c.kind, "title": c.title} for cid, c in sorted(self.collectors.items())],
                    "limitations": ["only the fixture adapter can run; real adapters are DISABLED or CONTRACT_ONLY",
                                    "a registered alias does not grant authorization; every call is evaluated per target and collector"]})
        return env

    def _tool_describe_collector(self, session, request_id, args):
        col = self.collectors.get(args["collector_id"])
        if col is None:
            raise GatewayError("E_COLLECTOR_UNKNOWN")
        env = self._base("diagnostics.describe_collector", session, request_id, collector_id=col.collector_id)
        per_target = {a: (evaluate_capability(t, col, self.adapters.status_of(t.adapter)) if col.collector_id in t.allowed_collectors
                          else CapabilityStatus.UNSUPPORTED) for a, t in sorted(self.targets.items())}
        env.update({"status": "OK", "capability_status": CapabilityStatus.SUPPORTED, "sanitization_status": "SANITIZED",
                    "evidence_refs": [], "collector": col.public_view(), "capability_by_target": per_target,
                    "limitations": []})
        return env

    def _tool_collect(self, session, request_id, args):
        target = self._target(args["target_alias"])
        col = self.collectors.get(args["collector_id"])
        if col is None:
            raise GatewayError("E_COLLECTOR_UNKNOWN")
        cap = self._authorize(session, target, col)
        adapter = self.adapters.get(target.adapter)
        session.calls += 1
        session.target_calls[target.alias] = session.target_calls.get(target.alias, 0) + 1
        rows_left = target.budget["max_rows"] - session.target_rows.get(target.alias, 0)
        cap_rows = min(args.get("max_rows", col.row_limit), col.row_limit, rows_left)
        timeout = min(col.timeout_seconds, self.operation_timeout)
        raw = run_with_timeout(lambda: adapter.fetch(target, col, {}), timeout)
        payload = sanitize_rows(col, raw, session.scope, target.alias, cap_rows)
        payload["digest_algorithm"] = "sha256"
        payload["digest"] = canonical_digest({"columns": payload["columns"], "rows": payload["rows"]})
        session.target_rows[target.alias] = session.target_rows.get(target.alias, 0) + payload["row_count"]
        ref = self.store.put(session.scope.session_id, target.alias, col.collector_id, payload)
        env = self._base("diagnostics.collect", session, request_id, target, col.collector_id)
        env.update({"status": "OK" if not payload["limitations"] else "DEGRADED", "capability_status": cap,
                    "collected_at_utc": None,
                    "provenance": {"kind": "FIXTURE" if adapter.name == "fixture" else "REAL", "real_observation": adapter.name != "fixture"},
                    "sanitization_status": "SANITIZED", "evidence_refs": [ref],
                    "evidence": {"columns": payload["columns"], "rows": payload["rows"], "row_count": payload["row_count"], "digest": payload["digest"]},
                    "query_sha256": col.query_sha256, "limitations": payload["limitations"]})
        return env

    def _tool_get_evidence(self, session, request_id, args):
        target = self._target(args["target_alias"])
        if not target.enabled:
            raise GatewayError("E_TARGET_DISABLED", CapabilityStatus.DISABLED)
        e = self.store.get(args["evidence_ref"], session.scope.session_id, target.alias)
        col = self.collectors[e["collector"]]
        env = self._base("diagnostics.get_evidence", session, request_id, target, col.collector_id)
        p = e["payload"]
        env.update({"status": "OK", "capability_status": CapabilityStatus.SUPPORTED, "collected_at_utc": None,
                    "provenance": {"kind": "FIXTURE", "real_observation": False},
                    "sanitization_status": "SANITIZED", "evidence_refs": [args["evidence_ref"]],
                    "evidence": {"columns": p["columns"], "rows": p["rows"], "row_count": p["row_count"], "digest": p["digest"]},
                    "limitations": list(p["limitations"])})
        return env

    def _tool_analyze_incident(self, session, request_id, args):
        target = self._target(args["target_alias"])
        if not target.enabled:
            raise GatewayError("E_TARGET_DISABLED", CapabilityStatus.DISABLED)
        refs = list(dict.fromkeys(args["evidence_refs"]))
        if not refs:
            raise GatewayError("E_INSUFFICIENT_EVIDENCE")
        items = []
        for ref in refs:
            e = self.store.get(ref, session.scope.session_id, target.alias)      # same scope rules as get_evidence
            items.append((self.collectors[e["collector"]], ref, e["payload"]))
        analysis = bridge.analyze(target.alias, items)
        env = self._base("diagnostics.analyze_incident", session, request_id, target)
        env.update({"status": "OK", "capability_status": CapabilityStatus.SUPPORTED, "collected_at_utc": None,
                    "provenance": {"kind": "FIXTURE", "real_observation": False},
                    "sanitization_status": "SANITIZED", "evidence_refs": refs, "analysis": analysis,
                    "limitations": ["derived from sanitized fixture evidence; correlation in time is not causation (rca_engine contract)",
                                    "advisory and candidate are proposals: nothing is executed, approved or published by the gateway"]})
        return env
