"""Phase 13 — MCP protocol conformance against a REAL stdio subprocess (framing, lifecycle, negotiation,
method rejection, malformed input, limits, clean stdout, clean shutdown)."""
import json

from tests.p13.harness import MARKER, ProcClient, leaks, run_all, test, all_output


def ready(**kw):
    c = ProcClient(**kw)
    c.initialize()
    return c


@test
def handshake_negotiates_the_protocol_version_and_advertises_only_tools():
    c = ProcClient()
    r = c.initialize()
    res = r["result"]
    assert r["jsonrpc"] == "2.0" and res["protocolVersion"] == "2025-06-18"
    assert set(res["capabilities"]) == {"tools"} and res["serverInfo"]["name"].endswith("mcp-gateway")
    assert c.close() == 0


@test
def older_supported_versions_are_echoed_and_unknown_versions_get_the_newest_supported_one():
    for v, expected in (("2025-03-26", "2025-03-26"), ("2024-11-05", "2024-11-05"), ("1999-01-01", "2025-06-18")):
        c = ProcClient()
        assert c.initialize(v)["result"]["protocolVersion"] == expected, v
        c.close()


@test
def requests_before_initialize_and_before_the_initialized_notification_are_rejected():
    c = ProcClient()
    r = c.request("tools/list")
    assert r["error"]["code"] == -32600 and r["error"]["message"] == "server is not initialized"
    c.initialize(complete=False)
    assert c.request("tools/list")["error"]["code"] == -32600, "initialize alone is not enough"
    c.initialized()
    assert "tools" in c.request("tools/list")["result"]
    assert c.request("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {}})["error"]["code"] == -32600
    c.close()


@test
def ping_works_before_and_after_initialization():
    c = ProcClient()
    assert c.request("ping")["result"] == {}
    c.initialize()
    assert c.request("ping")["result"] == {}
    c.close()


@test
def tools_list_publishes_only_the_static_semantic_tools_with_strict_schemas():
    c = ready()
    tools = c.request("tools/list")["result"]["tools"]
    names = [t["name"] for t in tools]
    assert names == ["diagnostics.list_capabilities", "diagnostics.describe_collector", "diagnostics.collect",
                     "diagnostics.get_evidence", "diagnostics.analyze_incident"]
    forbidden = {"sql", "query", "command", "cmd", "shell", "script", "path", "file", "url", "dsn", "host", "password", "user", "wallet",
                 "where", "connection", "connect_string", "code", "eval"}
    for t in tools:
        s = t["inputSchema"]
        assert s["type"] == "object" and s["additionalProperties"] is False, t["name"]
        assert not (set(s["properties"]) & forbidden), f"{t['name']} exposes a free-form input"
        assert t["description"] and "synthetic" in json.dumps(tools).lower()
    text = json.dumps(tools)
    for secret_like in ("fixture-primary-19c", "SYNTHDB", "password"):
        assert secret_like not in text, "tools/list must not expose target names or data"
    c.close()


@test
def unknown_methods_and_unsupported_capabilities_are_rejected_without_echoing_the_method():
    c = ready()
    for method in ("resources/list", "prompts/list", "completion/complete", "logging/setLevel", "sampling/createMessage",
                   "tools/" + MARKER, "shutdown", "exec"):
        r = c.request(method, {})
        assert r["error"]["code"] == -32601 and MARKER not in json.dumps(r), method
    c.close()


@test
def notifications_never_receive_a_response_and_unknown_ones_are_ignored():
    c = ready()
    out = c.raw(json.dumps({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": 7}}).encode())
    out += c.raw(json.dumps({"jsonrpc": "2.0", "method": "notifications/" + MARKER}).encode())
    assert out == [], "a notification must not produce output"
    c.close()


@test
def malformed_messages_fail_closed_with_fixed_text_and_the_server_keeps_running():
    c = ready()
    cases = [b"{ not json " + MARKER.encode(), b"[1,2,3]", b'"just a string"', b"42", b"null",
             b'{"jsonrpc":"1.0","id":1,"method":"ping"}', b'{"jsonrpc":"2.0","id":1}', b'{"jsonrpc":"2.0","id":1,"method":5}',
             b'{"jsonrpc":"2.0","id":{"a":1},"method":"ping"}', b'{"jsonrpc":"2.0","id":true,"method":"ping"}',
             b'{"jsonrpc":"2.0","id":1,"method":"ping","extra":' + MARKER.encode() + b'}',
             b'{"jsonrpc":"2.0","id":1,"method":"ping","params":[1]}',
             b'{"jsonrpc":"2.0","id":1,"method":"ping","id":2}',            # duplicate key
             b'{"jsonrpc":"2.0","id":1,"method":"ping","params":{"x":NaN}}',
             b"\xff\xfe\x00garbage", b'[{"jsonrpc":"2.0","id":1,"method":"ping"}]']
    for raw in cases:
        out = c.raw(raw)
        assert len(out) == 1 and "error" in out[0], raw[:30]
        assert out[0]["error"]["code"] in (-32700, -32600, -32602), raw[:30]
        assert MARKER not in json.dumps(out), "malformed input must never be echoed"
    assert c.request("ping")["result"] == {}, "server must still be alive"
    c.close()


@test
def oversize_deep_and_wide_payloads_are_rejected_without_being_processed():
    c = ready()
    big = b'{"jsonrpc":"2.0","id":1,"method":"ping","params":{"pad":"' + b"A" * 1_200_000 + b'"}}'
    out = c.raw(big)
    assert len(out) == 1 and out[0]["error"]["message"] == "message exceeds the size limit"
    deep = b'{"jsonrpc":"2.0","id":1,"method":"ping","params":' + b'{"a":' * 60 + b"1" + b"}" * 60 + b"}"
    out = c.raw(deep)
    assert len(out) == 1 and out[0]["error"]["code"] == -32700
    wide = b'{"jsonrpc":"2.0","id":1,"method":"ping","params":{"a":[' + b",".join([b"1"] * 3000) + b"]}}"
    out = c.raw(wide)
    assert len(out) == 1 and out[0]["error"]["code"] == -32700
    assert c.request("ping")["result"] == {}
    c.close()


@test
def tool_calls_with_bad_params_shapes_are_protocol_errors_and_unknown_tools_are_tool_errors():
    c = ready()
    for params in ({}, {"name": 5}, {"name": "diagnostics.collect", "arguments": [1]}, {"name": "diagnostics.collect", "extra": 1}):
        assert c.request("tools/call", params)["error"]["code"] == -32602, params
    env, res = c.call("diagnostics.execute_sql", {"sql": "select 1 from dual"})
    assert res["isError"] is True and env["error"]["code"] == "E_TOOL_UNKNOWN" and "select" not in json.dumps(env)
    c.close()


@test
def stdout_carries_only_json_rpc_lines_and_stderr_only_sanitized_audit_lines():
    c = ready()
    c.call("diagnostics.list_capabilities")
    c.collect("Q-DISC-IDENTITY-001")
    c.call("diagnostics.collect", {"collector_id": "x' OR '1'='1", "target_alias": MARKER})
    c.raw(b"{ broken")
    c.close()
    for line in c.stdout_lines:
        assert line.endswith(b"\n") and b"\r" not in line
        m = json.loads(line.decode("utf-8"))
        assert m["jsonrpc"] == "2.0" and ("result" in m) != ("error" in m)
    audit = [l for l in c.stderr_text.split("\n") if l.strip()]
    assert audit and all(l.startswith("AUDIT ") for l in audit), c.stderr_text[:200]
    allowed = {"ts_utc", "tool_id", "collector_id", "target_token", "status", "error_code", "duration_ms", "request_id", "session"}
    for l in audit:
        rec = json.loads(l[6:])
        assert set(rec) == allowed
    assert not leaks(all_output(c)), "no secret marker or argument may reach stdout/stderr"
    assert "Q-DISC" in c.stderr_text and "select" not in c.stderr_text.lower()


@test
def non_ascii_and_control_characters_in_arguments_are_rejected_and_output_stays_ascii_safe():
    c = ready()
    env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-primary-19c‮"})
    assert res["isError"] and env["error"]["code"] == "E_ARGS_INVALID"
    env, res = c.call("diagnostics.describe_collector", {"collector_id": "Q-DISC-IDENTITY-001\n; drop table x"})
    assert res["isError"] and env["error"]["code"] == "E_ARGS_INVALID"
    for line in c.stdout_lines:
        line.decode("ascii")             # responses are ASCII-escaped JSON (no encoding surprises on any platform)
    c.close()


@test
def clean_shutdown_at_eof_exits_zero_and_emits_nothing_after_eof():
    c = ready()
    c.call("diagnostics.list_capabilities")
    n = len(c.stdout_lines)
    assert c.close() == 0
    assert len(c.stdout_lines) == n


@test
def a_client_that_disconnects_mid_session_does_not_crash_or_hang_the_server():
    c = ready()
    c.send_bytes(b'{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"diagnostics.list_capabilities"')  # truncated, no newline
    assert c.close() == 0, "EOF with a partial line must terminate cleanly"


@test
def many_sequential_requests_stay_consistent_under_burst_load():
    c = ready()
    for i in range(150):
        env, res = c.call("diagnostics.describe_collector", {"collector_id": "Q-ORA-RESOURCE-LIMITS-001"})
        assert env["status"] == "OK", i
    assert c.request("ping")["result"] == {}
    c.close()


if __name__ == "__main__":
    raise SystemExit(run_all())
