"""Phase 14 — operability: bounded (lower-only) limits, cancellation, sequencing, shutdown, recovery of the local
process and safe degradation for every capability status."""
import json
import os
import subprocess
import sys
import time

from tests.p14.harness import (MARKER, PRIMARY, ROOT, InProcClient, ProcClient, default_targets, make_fixture_dir, make_targets_file, run_all, test, tmpdir,
                               write)


def run_cli(*args, timeout=60):
    p = subprocess.run([sys.executable, "-m", "mcp_gateway", *args], capture_output=True, cwd=ROOT, timeout=timeout, stdin=subprocess.DEVNULL,
                       env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
    return p.returncode, p.stdout, p.stderr.decode("utf-8", "replace")


class Counting:
    """Adapter stand-in that counts calls, to prove a denied capability never reaches an adapter."""
    name, status = "fixture", "VERIFIED_FIXTURE"

    DEFAULT = object()

    def __init__(self, rows=DEFAULT, exc=None):
        self.calls, self.rows, self.exc = 0, rows, exc

    def fetch(self, target, collector, params):
        self.calls += 1
        if self.exc:
            raise self.exc
        return self.rows if self.rows is not Counting.DEFAULT else [{"process_count": 5, "processes_limit": 10}]


@test
def lowered_limits_are_enforced_through_the_real_process():
    c = ProcClient(extra_args=["--max-rows", "2"])
    try:
        c.initialize()
        env = c.collect("Q-ORA-RESOURCE-LIMITS-001")
        assert env["evidence"]["row_count"] <= 2 and "ROWS_TRUNCATED_TO_LIMIT" in env["limitations"]
    finally:
        c.close()
    c = ProcClient(extra_args=["--max-session-calls", "2"])
    try:
        c.initialize()
        assert c.collect("Q-DISC-IDENTITY-001")["status"] in ("OK", "DEGRADED") and c.collect("Q-DISC-IDENTITY-001")["status"] in ("OK", "DEGRADED")
        env, raw = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY})
        assert raw["isError"] and env["error"]["code"] == "E_BUDGET_EXCEEDED"
    finally:
        c.close()
    c = ProcClient(extra_args=["--max-message-bytes", "2048"])
    try:
        c.initialize()
        assert c.request("ping")["result"] == {}
        out = c.raw(b'{"jsonrpc":"2.0","id":5,"method":"ping","params":{"pad":"' + b"A" * 4096 + b'"}}')
        assert out and out[0]["error"]["message"] == "message exceeds the size limit"
        assert c.request("ping")["result"] == {}, "the oversize message must not poison the session"
    finally:
        c.close()


@test
def limits_outside_the_bounds_refuse_startup_and_boundary_values_are_accepted():
    bad = [("--max-rows", "0"), ("--max-rows", "-1"), ("--max-rows", "201"), ("--max-rows", "abc"), ("--max-session-calls", "0"), ("--max-session-calls", "201"),
           ("--operation-timeout", "0.05"), ("--operation-timeout", "15.01"), ("--operation-timeout", "nan"), ("--operation-timeout", "inf"), ("--operation-timeout", "-3"),
           ("--max-message-bytes", "1023"), ("--max-message-bytes", "1048577"), ("--max-message-bytes", "0"), ("--max-rows", "1e3")]
    for flag, value in bad:
        rc, out, err = run_cli(flag, value)
        assert rc == 2 and out == b"" and "Traceback" not in err and value not in err, (flag, value, rc)
    for flag, value in (("--max-rows", "1"), ("--max-rows", "200"), ("--max-session-calls", "1"), ("--max-session-calls", "200"), ("--operation-timeout", "0.1"),
                        ("--operation-timeout", "15"), ("--max-message-bytes", "1024"), ("--max-message-bytes", "1048576")):
        rc, out, err = run_cli(flag, value)
        assert rc == 0 and err == "", (flag, value, err[:100])
    from mcp_gateway.common import LIMIT_BOUNDS, bounded_limit
    assert set(LIMIT_BOUNDS) == {"operation_timeout", "max_session_calls", "max_rows", "max_message_bytes"}
    for value in (True, "5", None, float("nan"), float("inf"), [1], 0):
        try:
            bounded_limit("max_rows", value)
        except ValueError:
            continue
        raise AssertionError(f"accepted {value!r}")


@test
def a_slow_adapter_hits_the_configured_deadline_and_the_server_keeps_answering():
    class Slow(Counting):
        def fetch(self, target, collector, params):
            self.calls += 1
            time.sleep(3)
            return [{"process_count": 1, "processes_limit": 2}]
    c = InProcClient()
    c.initialize()
    g = c.server.gateway
    g.adapters._adapters["fixture"] = slow = Slow()
    g.operation_timeout = 0.25
    t0 = time.time()
    env, raw = c.call("diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})
    assert raw["isError"] and env["error"]["code"] == "E_TIMEOUT" and time.time() - t0 < 2.0 and slow.calls == 1, "no retry after a timeout"
    assert c.call("diagnostics.list_capabilities", {})[0]["status"] == "OK"


@test
def cancellation_notifications_are_idempotent_and_never_break_the_session():
    c = ProcClient()
    try:
        c.send({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": 1, "reason": "before initialize"}})
        c.initialize()
        c.send({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": 999}})
        env = c.collect("Q-DISC-IDENTITY-001")
        c.send({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": 2, "reason": "already completed"}})
        for junk in ({"requestId": {"nested": 1}}, {"requestId": "x" * 10000}, "not-an-object", None, {"reason": MARKER}):
            c.send({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": junk})
        assert env["status"] in ("OK", "DEGRADED")
        assert c.request("ping")["result"] == {} and MARKER not in c.stderr_text
        before = len(c.stdout_lines)
        c.send({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": 3}})
        c.request("ping")
        replies_to_notifications = [l for l in c.stdout_lines[before:] if b'"cancel' in l]
        assert not replies_to_notifications, "a notification never gets a response"
    finally:
        c.close()


@test
def a_burst_of_requests_is_answered_in_order_one_at_a_time():
    c = ProcClient()
    try:
        c.initialize()
        ids = list(range(500, 560))
        payload = b"".join(json.dumps({"jsonrpc": "2.0", "id": i, "method": "ping" if i % 2 else "tools/list"}).encode() + b"\n" for i in ids)
        c.send_bytes(payload)
        got = []
        while len(got) < len(ids):
            m = c.recv(30)
            if m.get("id") in ids:
                got.append(m["id"])
        assert got == ids, "requests must be served strictly in arrival order (concurrency = 1)"
    finally:
        c.close()


@test
def shutdown_on_eof_is_clean_even_with_a_partial_last_line_or_no_session():
    c = ProcClient()
    c.send_bytes(b'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{}}}\n{"jsonrpc":"2.0","id":2,"method":"ping"}')
    c.p.stdin.close()                                          # the last line is only complete at EOF
    m1, m2 = c.recv(), c.recv()
    assert m1["id"] == 1 and m2["id"] == 2, "a final line without a newline is still processed"
    t0 = time.time()
    assert c.close(wait=10) == 0 and time.time() - t0 < 8
    c2 = ProcClient()
    assert c2.close(wait=10) == 0, "EOF before any message exits cleanly"
    c3 = ProcClient()
    c3.initialize()
    c3.collect("Q-DISC-IDENTITY-001")
    assert c3.close(wait=10) == 0 and c3.stderr_text.count("Traceback") == 0


@test
def a_killed_gateway_restarts_clean_and_old_evidence_references_do_not_survive():
    c = ProcClient()
    c.initialize()
    ref = c.collect("Q-DISC-IDENTITY-001")["evidence_refs"][0]
    c.p.terminate()
    c.p.wait(timeout=15)
    c2 = ProcClient()
    try:
        c2.initialize()
        env, raw = c2.call("diagnostics.get_evidence", {"evidence_ref": ref, "target_alias": PRIMARY})
        assert raw["isError"] and env["error"]["code"] == "E_EVIDENCE_NOT_FOUND", "in-memory evidence is gone with the process, by design"
        assert c2.collect("Q-DISC-IDENTITY-001")["status"] in ("OK", "DEGRADED"), "the restarted process serves a fresh session"
    finally:
        c2.close()


@test
def a_corrupted_configuration_fails_closed_with_a_fixed_message_and_recovers_when_fixed():
    with tmpdir() as d:
        good = make_targets_file(d, default_targets()["targets"])
        bad = os.path.join(d, "bad_targets.json")
        for raw in (b"{not json", b'{"schema_version": "1.0.0", "targets": [{"alias": "x"}]}', b"", b'{"targets": "nope"}'):
            open(bad, "wb").write(raw)
            rc, out, err = run_cli("--targets", bad)
            assert rc == 2 and out == b"" and err.strip() == "mcp_gateway: startup refused (catalog, target or fixture configuration is invalid)", raw
        rc, out, err = run_cli("--targets", os.path.join(d, "missing.json"))
        assert rc == 2 and out == b""
        c = ProcClient(targets=good)
        try:
            c.initialize()
            assert c.collect("Q-DISC-IDENTITY-001")["status"] in ("OK", "DEGRADED")
        finally:
            assert c.close() == 0


@test
def every_capability_denial_is_explicit_and_never_reaches_an_adapter():
    from mcp_gateway import catalog
    lic_spec = {"collector_id": "Q-LIC-TEST-001", "kind": "sql_query", "domain": "oracle", "title": "t", "row_limit": 5, "params": {},
                "output_fields": {"process_count": {"type": "integer", "policy": "KEEP"}}, "adapters": {}}
    with tmpdir() as d:
        base = default_targets()["targets"][0]
        targets = default_targets()["targets"] + [dict(base, alias="no-privilege-target", missing_privileges=["Q-ORA-PROCESSES-SUMMARY-001"]),
                   dict(base, alias="old-10g-target", oracle_version="10g", allowed_collectors=["Q-ORA-DIAGNOSTICS-ALERTLOG-001", "Q-ORA-PROCESSES-SUMMARY-001"]),
                   dict(base, alias="licensed-target", allowed_collectors=["Q-ORA-PROCESSES-SUMMARY-001"], license_status={"diagnostics_pack": "UNKNOWN"}),
                   dict(base, alias="primary-for-standby-only", allowed_collectors=["Q-DG-STATS-001"], role="PRIMARY"),
                   dict(base, alias="unknown-role-target", allowed_collectors=["Q-DG-STATS-001"], role="UNKNOWN"),
                   dict(base, alias="offline-target", enabled=False),
                   dict(base, alias="unknown-version-target", oracle_version=None, allowed_collectors=["Q-ORA-PROCESSES-SUMMARY-001"])]
        tf = make_targets_file(d, targets)
        c = InProcClient(targets=tf)
        g = c.server.gateway
        g.collectors["Q-LIC-TEST-001"] = catalog.Collector(lic_spec, {"license_requirements": "Diagnostics Pack", "supported_oracle_versions": ["19c"]})
        g.targets["licensed-target"].allowed_collectors = frozenset({"Q-LIC-TEST-001"})
        counter = Counting()
        g.adapters._adapters["fixture"] = counter
        c.initialize()
        expect = [("no-privilege-target", "Q-ORA-PROCESSES-SUMMARY-001", "INSUFFICIENT_PRIVILEGES"), ("old-10g-target", "Q-ORA-DIAGNOSTICS-ALERTLOG-001", "UNSUPPORTED"),
                  ("licensed-target", "Q-LIC-TEST-001", "LICENSE_RESTRICTED"), ("primary-for-standby-only", "Q-DG-STATS-001", "NOT_APPLICABLE"),
                  ("unknown-role-target", "Q-DG-STATS-001", "ENVIRONMENT_UNKNOWN"), ("offline-target", "Q-ORA-PROCESSES-SUMMARY-001", "DISABLED"),
                  ("unknown-version-target", "Q-ORA-PROCESSES-SUMMARY-001", "ENVIRONMENT_UNKNOWN"), ("lab-oracle-disabled", "Q-DISC-IDENTITY-001", "DISABLED")]
        for alias, cid, want in expect:
            env, raw = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": alias})
            assert raw["isError"] and env["capability_status"] == want and env["evidence_refs"] == [] and "evidence" not in env, (alias, want, env.get("capability_status"))
            assert "Traceback" not in json.dumps(env)
        assert counter.calls == 0, "a denied capability must never reach an adapter"
        ok = c.call("diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})[0]
        assert ok["status"] in ("OK", "DEGRADED") and counter.calls == 1


@test
def malformed_adapter_payloads_and_failures_give_fixed_errors_without_retries():
    cases = [([{"process_count": 1}, "not a row"], "E_RESULT_INVALID"), ("rows is a string", "E_RESULT_INVALID"), ({"a": 1}, "E_RESULT_INVALID"), (None, "E_RESULT_INVALID"),
             ([[1, 2, 3]], "E_RESULT_INVALID")]
    for rows, code in cases:
        c = InProcClient()
        c.initialize()
        c.server.gateway.adapters._adapters["fixture"] = counter = Counting(rows=rows)
        env, raw = c.call("diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})
        assert raw["isError"] and env["error"]["code"] == code and counter.calls == 1, (ascii(rows), env["error"])
    c = InProcClient()
    c.initialize()
    c.server.gateway.adapters._adapters["fixture"] = counter = Counting(exc=RuntimeError("connect failed user=" + MARKER + " host=db01.prod.example"))
    env, raw = c.call("diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})
    # CHG-ESTACK-CI-MATRIX-001: explicit diagnostics (fixed codes/booleans only, never the marker) — this failed on the
    # Windows CI runner with a bare AssertionError and nothing to diagnose it from.
    code, leaked = (env.get("error") or {}).get("code"), [MARKER in json.dumps(env), "db01" in json.dumps(env)]
    assert code == "E_ADAPTER_FAILED" and counter.calls == 1 and not any(leaked), ("code", code, "calls", counter.calls, "leaked", leaked)
    assert MARKER not in json.dumps(c.server.gateway.audit.records), "marker reached the audit records"


@test
def audit_records_under_failure_keep_only_fixed_keys_and_never_the_arguments():
    c = InProcClient()
    c.initialize()
    for args in ({"collector_id": MARKER, "target_alias": PRIMARY}, {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": MARKER}, {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "lab-oracle-disabled", "sql": MARKER}):
        c.call("diagnostics.collect", args)
    c.call("diagnostics.no_such_tool", {"x": MARKER})
    recs = c.server.gateway.audit.records
    assert len(recs) == 4
    for r in recs:
        assert set(r) == {"ts_utc", "tool_id", "collector_id", "target_token", "status", "error_code", "duration_ms", "request_id", "session"}
    assert MARKER not in json.dumps(recs) and MARKER not in c.stderr_text


@test
def process_exit_codes_are_stable_and_documented_flags_exist():
    assert run_cli("--version")[0] == 0 and run_cli("--print-claude-config")[0] == 0
    for argv in (["--unknown-flag"], ["--audit", "verbose"], ["--targets"], ["--max-rows"]):
        rc, out, err = run_cli(*argv)
        assert rc == 2 and out == b"" and "invalid command line usage" in err, argv
    help_rc, help_out, _ = run_cli("--help")
    assert help_rc == 0
    for flag in ("--operation-timeout", "--max-session-calls", "--max-rows", "--max-message-bytes", "--audit", "--targets", "--fixtures-dir"):
        assert flag.encode() in help_out, flag


if __name__ == "__main__":
    raise SystemExit(run_all())
