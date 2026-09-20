"""Phase 13 — tools, authorization and the fixture end-to-end path, driven through the real stdio server."""
import hashlib
import json
import os
import re

from tests.p13.harness import (
    MARKER, PRIMARY, ROOT, ProcClient, all_output, default_targets, leaks, make_fixture_dir, make_targets_file, run_all, test, tmpdir,
)

REF = re.compile(r"^EVR-[0-9a-f]{24}$")


def ready(**kw):
    c = ProcClient(**kw)
    c.initialize()
    return c


@test
def list_capabilities_is_honest_about_adapters_targets_and_statuses():
    c = ready()
    env, res = c.call("diagnostics.list_capabilities")
    assert not res["isError"] and env["status"] == "OK" and env["tool_id"] == "diagnostics.list_capabilities"
    assert env["adapters"]["fixture"] == "VERIFIED_FIXTURE" and env["adapters"]["oracle_sql"] == "DISABLED"
    assert env["adapters"]["os_readonly"] == "CONTRACT_ONLY" and env["adapters"]["oracle_diag_file"] == "CONTRACT_ONLY"
    t = {x["target_alias"]: x for x in env["targets"]}
    assert t["lab-oracle-disabled"]["enabled"] is False and t["lab-oracle-disabled"]["adapter_status"] == "DISABLED"
    assert t["lab-oracle-disabled"]["capabilities"]["Q-DISC-IDENTITY-001"] == "DISABLED"
    assert t["fixture-unknown-version"]["capabilities"]["Q-DISC-IDENTITY-001"] == "ENVIRONMENT_UNKNOWN"
    assert t[PRIMARY]["capabilities"]["Q-DISC-IDENTITY-001"] == "SUPPORTED" and t[PRIMARY]["capabilities"]["Q-DG-STATS-001"] == "UNSUPPORTED"
    assert t["fixture-standby-19c"]["capabilities"]["Q-DG-STATS-001"] == "SUPPORTED"
    assert "connection" not in json.dumps(env).lower() and env["provenance"]["real_observation"] is False
    c.close()


@test
def describe_collector_exposes_metadata_and_provenance_hash_but_never_sql_text():
    c = ready()
    env, _ = c.call("diagnostics.describe_collector", {"collector_id": "Q-ORA-RESOURCE-LIMITS-001"})
    col = env["collector"]
    assert col["risk_class"] == "R0" and col["row_limit"] == 50 and "10g" in col["supported_oracle_versions"]
    assert col["license_requirements"] == "none" and col["output_fields"]["resource_name"]["sanitization"] == "KEEP"
    text = json.dumps(env).lower()
    with open(os.path.join(ROOT, "queries", "oracle", "resources", "Q-ORA-RESOURCE-LIMITS-001.md"), encoding="utf-8") as f:
        block = "\n".join(b.strip() for b in re.findall(r"```sql\n(.*?)```", f.read(), re.S))
    for line in block.split("\n"):                       # no line of the certified SQL text may appear in the response
        norm = re.sub(r"\s+", " ", line.strip().lower())
        assert len(norm) < 12 or norm not in re.sub(r"\s+", " ", text), "SQL text leaked into describe_collector"
    assert [x.lower() for x in col["minimum_privileges"]] == ["select on v$resource_limit"], "privileges are metadata, not SQL"
    assert col["query_sha256"] == hashlib.sha256(block.encode("utf-8")).hexdigest(), "provenance hash must match the repository query text"
    e2, r2 = c.call("diagnostics.describe_collector", {"collector_id": "Q-NOT-CERTIFIED-999"})
    assert r2["isError"] and e2["error"]["code"] == "E_COLLECTOR_UNKNOWN"
    c.close()


@test
def collect_returns_sanitized_minimized_evidence_with_the_required_envelope_fields():
    c = ready()
    env = c.collect("Q-ORA-RESOURCE-LIMITS-001")
    for k in ("status", "tool_id", "request_id", "schema_version", "collector_id", "target_token", "collected_at_utc", "capability_status",
              "sanitization_status", "evidence_refs", "limitations", "provenance"):
        assert k in env, k
    assert env["status"] == "OK" and env["capability_status"] == "SUPPORTED" and env["sanitization_status"] == "SANITIZED"
    assert env["collected_at_utc"] is None and env["provenance"] == {"kind": "FIXTURE", "real_observation": False}
    assert re.match(r"^TGT-[0-9a-f]{16}$", env["target_token"]) and re.match(r"^REQ-[0-9a-f]{12}$", env["request_id"])
    assert len(env["evidence_refs"]) == 1 and REF.match(env["evidence_refs"][0])
    rows = env["evidence"]["rows"]
    assert rows[0] == {"resource_name": "processes", "current_utilization": 180, "max_utilization": 195, "limit_value": 200}
    assert rows[2]["limit_value"] == "UNLIMITED" and env["evidence"]["row_count"] == 3
    assert PRIMARY not in json.dumps(env), "the alias must not be echoed in evidence; only the opaque target_token"
    c.close()


@test
def identifiers_are_masked_and_correlation_is_stable_inside_a_session_but_not_across_sessions():
    a = ready()
    r1 = a.collect("Q-DISC-IDENTITY-001")["evidence"]["rows"][0]
    r2 = a.collect("Q-DISC-IDENTITY-001")["evidence"]["rows"][0]
    assert r1["instance_name"] == "inst-A1" and r1["db_name"] == "db-A1" and r1 == r2
    assert "SYNTHDB" not in json.dumps(r1) and r1["version"] == "19.0.0.0.0" and r1["database_role"] == "PRIMARY"
    tok_a = a.collect("Q-DISC-IDENTITY-001")["target_token"]
    b = ready()
    assert b.collect("Q-DISC-IDENTITY-001")["target_token"] != tok_a, "target tokens are session-scoped"
    a.close(); b.close()


@test
def get_evidence_returns_the_same_sanitized_payload_and_never_raw():
    c = ready()
    coll = c.collect("Q-ORA-PROCESSES-SUMMARY-001")
    ref = coll["evidence_refs"][0]
    got, res = c.call("diagnostics.get_evidence", {"evidence_ref": ref, "target_alias": PRIMARY})
    assert not res["isError"] and got["evidence"] == coll["evidence"] and got["evidence_refs"] == [ref]
    assert got["provenance"]["kind"] == "FIXTURE" and got["sanitization_status"] == "SANITIZED"
    c.close()


@test
def evidence_refs_are_unguessable_and_scoped_to_session_and_target():
    a = ready()
    ref = a.collect("Q-DISC-IDENTITY-001")["evidence_refs"][0]
    # wrong target, unknown ref, malformed ref, and a ref from ANOTHER session all give the same answer
    b = ready()
    b.collect("Q-DISC-IDENTITY-001")
    for client, alias, r in ((a, "fixture-standby-19c", ref), (a, PRIMARY, "EVR-" + "0" * 24), (b, PRIMARY, ref)):
        env, res = client.call("diagnostics.get_evidence", {"evidence_ref": r, "target_alias": alias})
        assert res["isError"] and env["error"]["code"] == "E_EVIDENCE_NOT_FOUND"
    for bad in ("../../etc/passwd", "EVR-" + "G" * 24, "EVR-1", "evr-" + "0" * 24, ref + "0", ""):
        env, res = a.call("diagnostics.get_evidence", {"evidence_ref": bad, "target_alias": PRIMARY})
        assert res["isError"] and env["error"]["code"] == "E_ARGS_INVALID"
    refs = {a.collect("Q-DISC-IDENTITY-001")["evidence_refs"][0] for _ in range(20)}
    assert len(refs) == 20, "references must not repeat or be predictable from the data"
    a.close(); b.close()


@test
def unknown_disabled_and_not_allowed_targets_and_collectors_fail_closed_with_explicit_status():
    c = ready()
    cases = [("Q-DISC-IDENTITY-001", "no-such-target", "E_TARGET_UNKNOWN", None),
             ("Q-DISC-IDENTITY-001", "lab-oracle-disabled", "E_TARGET_DISABLED", "DISABLED"),
             ("Q-DG-STATS-001", PRIMARY, "E_COLLECTOR_NOT_ALLOWED", "UNSUPPORTED"),
             ("Q-ORA-PROCESSES-SUMMARY-001", "fixture-legacy-11g", "E_COLLECTOR_NOT_ALLOWED", "UNSUPPORTED"),
             ("Q-DISC-IDENTITY-001", "fixture-unknown-version", "E_CAPABILITY", "ENVIRONMENT_UNKNOWN"),
             ("Q-UNCERTIFIED-001", PRIMARY, "E_COLLECTOR_UNKNOWN", None)]
    for cid, alias, code, cap in cases:
        env, res = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": alias})
        assert res["isError"] and env["status"] == "ERROR" and env["error"]["code"] == code and env["capability_status"] == cap, (cid, alias, env)
        assert env["evidence_refs"] == [] and "evidence" not in env
    c.close()


@test
def role_scope_version_and_license_gates_are_evaluated_from_declared_facts_never_assumed():
    with tmpdir() as d:
        base = default_targets()["targets"]
        t = [x for x in base if x["alias"] in (PRIMARY, "fixture-standby-19c")]
        prim = dict(t[0], alias="role-mismatch-primary", allowed_collectors=["Q-DG-STATS-001"])            # DG stats on a PRIMARY
        old = dict(t[0], alias="version-mismatch-target", oracle_version="10g", allowed_collectors=["Q-DG-STATS-001", "Q-DISC-IDENTITY-001"], role="STANDBY")
        norole = dict(t[1], alias="unknown-role-target", role="UNKNOWN")
        tf = make_targets_file(d, t + [prim, old, norole])
        fx = make_fixture_dir(d, {("role-mismatch-primary", "Q-DG-STATS-001"): [], ("unknown-role-target", "Q-DG-STATS-001"): [],
                                  ("version-mismatch-target", "Q-DG-STATS-001"): []})
        c = ProcClient(targets=tf, fixtures=fx)
        c.initialize()
        e1 = c.call("diagnostics.collect", {"collector_id": "Q-DG-STATS-001", "target_alias": "role-mismatch-primary"})[0]
        assert e1["error"]["code"] == "E_CAPABILITY" and e1["capability_status"] == "NOT_APPLICABLE"
        e2 = c.call("diagnostics.collect", {"collector_id": "Q-DG-STATS-001", "target_alias": "unknown-role-target"})[0]
        assert e2["capability_status"] == "ENVIRONMENT_UNKNOWN"
        e3 = c.call("diagnostics.collect", {"collector_id": "Q-DG-STATS-001", "target_alias": "version-mismatch-target"})[0]
        assert e3["status"] == "OK", "10g standby with a query certified for 10g..23ai is supported by the declared facts"
        c.close()


@test
def budgets_limit_calls_and_rows_per_target_and_truncation_is_reported():
    c = ready()
    a = c.collect("Q-ORA-RESOURCE-LIMITS-001", "fixture-tight-budget")           # 4 fixture rows, target row budget = 6
    assert a["evidence"]["row_count"] == 4
    b = c.collect("Q-ORA-RESOURCE-LIMITS-001", "fixture-tight-budget")           # only 2 rows of budget left -> truncated
    assert b["status"] == "DEGRADED" and b["evidence"]["row_count"] == 2 and "ROWS_TRUNCATED_TO_LIMIT" in b["limitations"]
    env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-tight-budget"})
    assert res["isError"] and env["error"]["code"] == "E_BUDGET_EXCEEDED", "max_calls=2 and rows exhausted"
    other = c.collect("Q-DISC-IDENTITY-001", PRIMARY)
    assert other["status"] == "OK", "budgets are per target"
    m = c.collect("Q-ORA-RESOURCE-LIMITS-001", PRIMARY, max_rows=1)
    assert m["evidence"]["row_count"] == 1 and "ROWS_TRUNCATED_TO_LIMIT" in m["limitations"]
    c.close()


@test
def no_tool_argument_can_carry_sql_shell_paths_urls_or_connection_data():
    c = ready()
    payloads = [{"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "sql": "select * from dual"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "where": "1=1"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "command": "id"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "path": "../../etc/passwd"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "url": "http://127.0.0.1/"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "dsn": "user/pw@host/svc"},
                {"collector_id": "select 1 from dual", "target_alias": PRIMARY},
                {"collector_id": "Q-DISC-IDENTITY-001; drop table t", "target_alias": PRIMARY},
                {"collector_id": "../Q-DISC-IDENTITY-001", "target_alias": PRIMARY},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "../fixture-primary-19c"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-primary-19c/../../x"},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "max_rows": 0},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "max_rows": 10 ** 12},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "max_rows": 2.5},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "max_rows": True},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "max_rows": "5"},
                {"collector_id": ["Q-DISC-IDENTITY-001"], "target_alias": PRIMARY},
                {"collector_id": {"$ne": ""}, "target_alias": PRIMARY},
                {"collector_id": None, "target_alias": PRIMARY},
                {"target_alias": PRIMARY},
                {"collector_id": "A" * 5000, "target_alias": PRIMARY},
                {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": {"alias": PRIMARY}}]
    for args in payloads:
        env, res = c.call("diagnostics.collect", args)
        assert res["isError"] and env["error"]["code"] == "E_ARGS_INVALID", args
        assert "evidence" not in env and env["evidence_refs"] == []
    env, res = c.call("diagnostics.list_capabilities", {"anything": 1})
    assert res["isError"] and env["error"]["code"] == "E_ARGS_INVALID"
    c.close()


@test
def error_envelopes_never_echo_client_input_and_reveal_no_paths_or_stack_traces():
    c = ready()
    hostile = MARKER + "_' OR 1=1 --"
    outs = []
    for args in ({"collector_id": hostile, "target_alias": PRIMARY}, {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": hostile},
                 {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "x" + MARKER: 1}):
        env, res = c.call("diagnostics.collect", args)
        outs.append(json.dumps(env))
        assert env["error"]["message"] in ("arguments do not satisfy the tool schema",)
    text = "\n".join(outs) + all_output(c)
    assert not leaks(text) and "Traceback" not in text and "\\Users\\" not in text and "/c/Users" not in text
    c.close()


@test
def the_shipped_fixture_data_cannot_carry_hidden_sensitive_text_into_responses():
    c = ready()
    text = ""
    for cid in ("Q-DISC-IDENTITY-001", "Q-ORA-RESOURCE-LIMITS-001", "Q-ORA-PROCESSES-SUMMARY-001", "Q-ORA-DIAGNOSTICS-ALERTLOG-001",
                "os.get_process_limits", "os.get_oracle_process_summary"):
        text += json.dumps(c.collect(cid))
    assert "fork failed" not in text and "OS failure message" not in text, "alert log message text is DROP-only"
    assert "ORA-27300" in text, "certified signatures survive"
    c.close()


if __name__ == "__main__":
    raise SystemExit(run_all())
