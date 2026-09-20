"""Phase 13 — unit tests: schema validator, sanitizer primitives, evidence store, adapter deadline, audit, tokens."""
import json
import time

from tests.p13.harness import MARKER, PRIMARY, InProcClient, make_fixture_dir, run_all, test, tmpdir


def rejects(fn, code="E_ARGS_INVALID"):
    from mcp_gateway.common import GatewayError
    try:
        fn()
    except GatewayError as e:
        assert e.code == code, e.code
        return
    raise AssertionError("expected a GatewayError")


@test
def schema_validator_enforces_types_bounds_patterns_enums_and_closed_objects():
    from mcp_gateway.schemas import check_schema, validate
    s = {"type": "object", "additionalProperties": False, "required": ["a"], "properties": {
        "a": {"type": "string", "maxLength": 5, "pattern": "[a-z]+"}, "n": {"type": "integer", "minimum": 1, "maximum": 3},
        "f": {"type": "number", "minimum": 0, "maximum": 1}, "b": {"type": "boolean"}, "e": {"type": "string", "enum": ["x", "y"], "maxLength": 1},
        "l": {"type": "array", "maxItems": 2, "items": {"type": "integer", "minimum": 0, "maximum": 9}}}}
    check_schema(s)
    assert validate({"a": "abc", "n": 2, "f": 0.5, "b": True, "e": "x", "l": [1, 2]}, s)["a"] == "abc"
    bad = [{}, {"a": "ABC"}, {"a": "abcdef"}, {"a": "abc", "n": 0}, {"a": "abc", "n": 4}, {"a": "abc", "n": True}, {"a": "abc", "n": 1.5},
           {"a": "abc", "f": float("inf")}, {"a": "abc", "f": float("nan")}, {"a": "abc", "f": 2}, {"a": "abc", "b": 1}, {"a": "abc", "e": "z"},
           {"a": "abc", "l": [1, 2, 3]}, {"a": "abc", "l": ["1"]}, {"a": "abc", "extra": 1}, {"a": "abc\n"}, {"a": "abc‮"}, {"a": "abc", 1: 2}, "str", [], None]
    for b in bad:
        rejects(lambda b=b: validate(b, s))


@test
def schema_registration_refuses_open_objects_unbounded_strings_and_unknown_keywords():
    from mcp_gateway.schemas import check_schema
    for bad in ({"type": "object", "properties": {}}, {"type": "object", "additionalProperties": False, "properties": {"a": {"type": "string"}}},
                {"type": "object", "additionalProperties": False, "properties": {}, "patternProperties": {}},
                {"type": "array", "items": {"type": "integer"}}, {"type": "object", "additionalProperties": False, "required": ["z"], "properties": {}},
                {"type": "weird"}):
        try:
            check_schema(bad)
        except ValueError:
            continue
        raise AssertionError(f"accepted {bad}")


@test
def sanitizer_primitives_keep_valid_values_and_drop_invalid_ones_for_every_type():
    from mcp_gateway.evidence import SessionScope, _sanitize_value
    s = SessionScope()
    f = lambda spec, v: _sanitize_value(spec, v, s, "fixture-primary-19c")
    assert f({"type": "integer", "policy": "KEEP", "min": 0, "max": 10}, 5) == (True, 5)
    assert f({"type": "integer", "policy": "KEEP", "min": 0, "max": 10}, 11)[0] is False and f({"type": "integer", "policy": "KEEP"}, 1.0)[0] is False
    assert f({"type": "integer", "policy": "KEEP"}, True)[0] is False and f({"type": "number", "policy": "KEEP"}, float("nan"))[0] is False
    assert f({"type": "number", "policy": "KEEP", "min": 0, "max": 100}, 99.5) == (True, 99.5)
    assert f({"type": "boolean", "policy": "KEEP"}, True) == (True, True) and f({"type": "boolean", "policy": "KEEP"}, "true")[0] is False
    assert f({"type": "enum", "policy": "KEEP", "values": ["A"]}, "A")[0] and not f({"type": "enum", "policy": "KEEP", "values": ["A"]}, "a")[0]
    assert f({"type": "integer_or_unlimited", "policy": "KEEP", "min": 0, "max": 5}, "UNLIMITED") == (True, "UNLIMITED")
    assert f({"type": "integer_or_unlimited", "policy": "KEEP", "min": 0, "max": 5}, "unlimited")[0] is False
    assert f({"type": "timestamp_utc", "policy": "KEEP"}, "2026-03-11T10:00:00-05:00") == (True, "2026-03-11T15:00:00+00:00")
    assert f({"type": "timestamp_utc", "policy": "KEEP"}, "2026-03-11T10:00:00")[0] is False and f({"type": "timestamp_utc", "policy": "KEEP"}, "2026-13-45T99:00:00Z")[0] is False
    assert f({"type": "version_string", "policy": "KEEP"}, "19.0.0.0.0")[0] and not f({"type": "version_string", "policy": "KEEP"}, "19.x; drop")[0]
    assert f({"type": "text", "policy": "DROP"}, "anything")[0] is False and f({"type": "integer", "policy": "DROP"}, 1)[0] is False
    assert f({"type": "mystery", "policy": "KEEP"}, 1)[0] is False, "unknown types are denied"


@test
def mask_hash_tokenize_are_session_salted_stable_within_scope_and_not_derivable_from_the_value():
    from mcp_gateway.evidence import SessionScope
    a, b = SessionScope(), SessionScope()
    assert a.hash_value("t", "V") == a.hash_value("t", "V") != a.hash_value("t2", "V") != b.hash_value("t", "V")
    assert a.token_value("t", "V") != a.hash_value("t", "V")[2:] and a.token_value("t", "V") == a.token_value("t", "V")
    assert a.alias("t", "host", "H1") == "host-A1" and a.alias("t", "host", "H2") == "host-A2" and a.alias("t", "host", "H1") == "host-A1"
    assert a.alias("t2", "host", "H2") == "host-A1", "alias tables are per target"
    for out in (a.hash_value("t", MARKER), a.token_value("t", MARKER), a.target_token("x")):
        assert MARKER not in out


@test
def evidence_store_expires_evicts_and_binds_entries_to_session_and_target():
    from mcp_gateway.common import GatewayError
    from mcp_gateway.evidence import EvidenceStore
    t = [0.0]
    st = EvidenceStore(ttl_seconds=10, max_entries=3, clock=lambda: t[0])
    r1 = st.put("S1", "tgt-a", "C", {"rows": [1]})
    assert st.get(r1, "S1", "tgt-a")["payload"] == {"rows": [1]}
    for bad in (("S2", "tgt-a"), ("S1", "tgt-b")):
        rejects(lambda bad=bad: st.get(r1, *bad), "E_EVIDENCE_NOT_FOUND")
    t[0] = 11
    rejects(lambda: st.get(r1, "S1", "tgt-a"), "E_EVIDENCE_NOT_FOUND")
    refs = [st.put("S1", "tgt-a", "C", {"rows": [i]}) for i in range(5)]
    assert len(st) == 3 and st.clear_session("S1") == 3 and len(st) == 0


@test
def evidence_store_detects_tampering_of_stored_payloads():
    from mcp_gateway.evidence import EvidenceStore
    st = EvidenceStore()
    ref = st.put("S1", "tgt-a", "C", {"rows": [1]})
    st._items[ref]["payload"]["rows"].append(2)
    rejects(lambda: st.get(ref, "S1", "tgt-a"), "E_EVIDENCE_NOT_FOUND")


@test
def slow_adapters_hit_a_hard_deadline_and_the_server_keeps_answering():
    from mcp_gateway.adapters import DisabledAdapter
    from mcp_gateway.cli import build_gateway
    from mcp_gateway.server import McpServer
    import io

    class SlowAdapter:
        name, status = "fixture", "VERIFIED_FIXTURE"

        def fetch(self, target, collector, params):
            time.sleep(3)
            return [{"process_count": 1, "processes_limit": 2}]
    g = build_gateway(None, None, None)
    g.operation_timeout = 0.3
    g.adapters._adapters["fixture"] = SlowAdapter()
    srv = McpServer(g, out=io.BytesIO(), err=io.StringIO())
    srv.handle_line(json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {}}}).encode())
    srv.handle_line(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}).encode())
    t0 = time.time()
    env, is_err = g.call(srv.session, "diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})
    assert is_err and env["error"]["code"] == "E_TIMEOUT" and time.time() - t0 < 2.0
    env2, err2 = g.call(srv.session, "diagnostics.list_capabilities", {})
    assert not err2 and env2["status"] == "OK", "the loop is not blocked by an abandoned worker"


@test
def adapter_exceptions_become_fixed_error_codes_without_details():
    from mcp_gateway.cli import build_gateway
    from mcp_gateway.gateway import Session

    class Boom:
        name, status = "fixture", "VERIFIED_FIXTURE"

        def fetch(self, target, collector, params):
            raise RuntimeError("connect failed for user=" + MARKER + " host=db01")
    g = build_gateway(None, None, None)
    g.adapters._adapters["fixture"] = Boom()
    env, is_err = g.call(Session(), "diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})
    assert is_err and env["error"]["code"] == "E_ADAPTER_FAILED" and MARKER not in json.dumps(env) and "db01" not in json.dumps(env)


@test
def audit_records_contain_only_the_allowed_keys_and_never_arguments_or_evidence():
    c = InProcClient()
    c.initialize()
    c.collect("Q-DISC-IDENTITY-001")
    c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": MARKER})
    recs = c.server.gateway.audit.records
    assert len(recs) == 2
    for r in recs:
        assert set(r) == {"ts_utc", "tool_id", "collector_id", "target_token", "status", "error_code", "duration_ms", "request_id", "session"}
    assert recs[1]["error_code"] == "E_ARGS_INVALID" and MARKER not in json.dumps(recs)


@test
def error_message_table_is_fixed_and_contains_no_format_placeholders():
    from mcp_gateway.common import ERROR_MESSAGES, GatewayError
    for code, msg in ERROR_MESSAGES.items():
        assert "{" not in msg and "%" not in msg and msg == GatewayError(code).message
    assert GatewayError("E_NOT_A_CODE").code == "E_INTERNAL"


if __name__ == "__main__":
    raise SystemExit(run_all())
