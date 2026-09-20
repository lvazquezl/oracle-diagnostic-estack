"""Phase 13 — Phase 11 / Phase 12 integration through the REAL gateway: tools/call -> dispatcher -> fixture
collectors -> sanitizer -> evidence refs -> diagnostics.analyze_incident (rca_engine + change advisory +
knowledge candidate state). Nothing is executed, approved or published."""
import json
import re

from tests.p13.harness import (
    MARKER, PRIMARY, ProcClient, all_output, leaks, make_fixture_dir, run_all, test, tmpdir,
)


def ready(**kw):
    c = ProcClient(**kw)
    c.initialize()
    return c


def gather(c, collectors, alias=PRIMARY):
    return [c.collect(x, alias)["evidence_refs"][0] for x in collectors]


FULL = ["Q-ORA-DIAGNOSTICS-ALERTLOG-001", "os.get_process_limits", "os.get_oracle_process_summary"]


@test
def end_to_end_collect_then_analyze_yields_a_confirmed_rca_with_manual_only_change_and_unpublished_candidate():
    c = ready()
    refs = gather(c, FULL)
    env, res = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": refs})
    assert not res["isError"] and env["status"] == "OK", env.get("error")
    a = env["analysis"]
    assert a["rca"]["completeness"] == "CONFIRMED" and a["rca"]["authority"].startswith("rca_engine")
    assert len(a["rca"]["confirmed_hypothesis_ids"]) == 1 and a["incident_id"].startswith("INC-20260311-")
    hyp = next(h for h in a["hypotheses"] if h["status"] == "CONFIRMED")
    assert hyp["supporting_evidence_ids"] and not hyp["contradicting_evidence_ids"]
    # lineage: every EVD id cited by the RCA resolves to an opaque gateway evidence reference of THIS session
    lin = {x["evidence_id"]: x for x in a["evidence_lineage"]}
    assert set(hyp["supporting_evidence_ids"]) <= set(lin) and {x["evidence_ref"] for x in lin.values()} <= set(refs)
    assert all(r["execution_status"] == "NOT_EXECUTED" for r in a["recommendations"]) and a["recommendations"]
    adv = a["change_advisory"]
    assert adv["execution_status"] == "NOT_EXECUTED_BY_ESTACK" and adv["review_status"] == "REVIEW_REQUIRED" and adv["change_ids"]
    assert adv["readiness"] in ("REVIEW_REQUIRED", "READY_FOR_HUMAN_REVIEW"), "gates stay UNKNOWN: never approved by the gateway"
    kb = a["knowledge_candidate"]
    assert kb["lifecycle_state"] == "CANDIDATE" and "not knowledge" in kb["note"]
    assert env["evidence_refs"] == refs and "APPROVED_BY_HUMAN" not in json.dumps(env)
    c.close()


@test
def one_source_only_stays_below_confirmed_and_the_candidate_is_rejected_not_published():
    c = ready()
    refs = gather(c, ["Q-ORA-DIAGNOSTICS-ALERTLOG-001"])
    a = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": refs})[0]["analysis"]
    assert a["rca"]["completeness"] != "CONFIRMED", "a single signature is a symptom, not a cause"
    assert a["change_advisory"]["change_ids"] == [] and a["knowledge_candidate"]["lifecycle_state"] in ("REJECTED", "NOT_APPLICABLE")
    c.close()


@test
def contradicting_evidence_blocks_confirmation_and_is_preserved_in_the_analysis():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {
            (PRIMARY, "Q-ORA-DIAGNOSTICS-ALERTLOG-001"): [{"event_time": "2026-03-11T15:02:31Z", "signature": "ORA-27300", "message": "x"}],
            (PRIMARY, "os.get_process_limits"): [{"observed_at_utc": "2026-03-11T15:02:00Z", "nproc_utilization_percent": 40.0, "limit_source": "rlimit_nproc"}],
            (PRIMARY, "os.get_oracle_process_summary"): [{"observed_at_utc": "2026-03-11T15:02:10Z", "fork_failures_observed": True, "oracle_process_count": 50}]})
        c = ready(fixtures=fx)
        refs = gather(c, FULL)
        a = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": refs})[0]["analysis"]
        assert a["rca"]["completeness"] != "CONFIRMED"
        contested = [h for h in a["hypotheses"] if h["contradicting_evidence_ids"]]
        assert contested, "the contradicting process-limit evidence must survive into the analysis"
        assert a["change_advisory"]["change_ids"] == [] and a["knowledge_candidate"]["lifecycle_state"] != "CANDIDATE"
        c.close()


@test
def temporal_proximity_alone_is_not_causality_through_the_gateway():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {
            (PRIMARY, "Q-ORA-DIAGNOSTICS-ALERTLOG-001"): [{"event_time": "2026-03-11T15:02:31Z", "signature": "ORA-27300", "message": "x"}],
            (PRIMARY, "os.get_process_limits"): [{"observed_at_utc": "2026-03-11T15:02:32Z", "nproc_utilization_percent": 12.0, "limit_source": "rlimit_nproc"}],
            (PRIMARY, "os.get_oracle_process_summary"): [{"observed_at_utc": "2026-03-11T15:02:33Z", "fork_failures_observed": False, "oracle_process_count": 50}]})
        c = ready(fixtures=fx)
        a = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": gather(c, FULL)})[0]["analysis"]
        assert a["rca"]["completeness"] in ("INSUFFICIENT_EVIDENCE", "INCONCLUSIVE") and not a["rca"]["confirmed_hypothesis_ids"]
        c.close()


@test
def unrecognized_signature_markers_flow_as_tokens_and_never_reach_the_analysis_or_any_stream():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {
            (PRIMARY, "Q-ORA-DIAGNOSTICS-ALERTLOG-001"): [{"event_time": "2026-03-11T15:02:31Z", "signature": MARKER + "_SIG", "message": MARKER},
                                                          {"event_time": "2026-03-11T15:02:32Z", "signature": "ORA-27300", "message": MARKER}],
            (PRIMARY, "os.get_process_limits"): [{"observed_at_utc": "2026-03-11T15:02:00Z", "nproc_utilization_percent": 99.5, "limit_source": "rlimit_nproc"}],
            (PRIMARY, "os.get_oracle_process_summary"): [{"observed_at_utc": "2026-03-11T15:02:10Z", "fork_failures_observed": True, "oracle_process_count": 5}]})
        c = ready(fixtures=fx)
        env = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": gather(c, FULL)})[0]
        assert env["analysis"]["rca"]["completeness"] == "CONFIRMED", "a foreign signature must not break a legitimately confirmed RCA"
        c.close()
        assert not leaks(all_output(c)) and "TGT-" in json.dumps(env)


@test
def analysis_scope_rules_foreign_targets_foreign_sessions_and_empty_input_are_denied():
    a = ready()
    refs = gather(a, FULL)
    b = ready()
    gather(b, FULL)
    for client, alias, r, code in ((a, "fixture-standby-19c", refs, "E_EVIDENCE_NOT_FOUND"), (b, PRIMARY, refs, "E_EVIDENCE_NOT_FOUND"),
                                   (a, PRIMARY, [], "E_INSUFFICIENT_EVIDENCE"), (a, "lab-oracle-disabled", refs, "E_TARGET_DISABLED"),
                                   (a, "nope-target", refs, "E_TARGET_UNKNOWN")):
        env, res = client.call("diagnostics.analyze_incident", {"target_alias": alias, "evidence_refs": r})
        assert res["isError"] and env["error"]["code"] == code and "analysis" not in env, (alias, code)
    # evidence that has no RCA mapping (identity) cannot carry an analysis by itself
    only_identity = [a.collect("Q-DISC-IDENTITY-001")["evidence_refs"][0]]
    env, res = a.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": only_identity})
    assert res["isError"] and env["error"]["code"] == "E_INSUFFICIENT_EVIDENCE"
    a.close(); b.close()


@test
def the_analysis_carries_no_executable_content_no_approval_and_no_publication_state():
    c = ready()
    env = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": gather(c, FULL)})[0]
    text = json.dumps(env)
    for banned in ("PUBLISHED", "APPROVED_BY_HUMAN", "sudo ", "srvctl", "crsctl", "ALTER SYSTEM"):
        assert banned not in text, banned
    assert not re.search(r"(?<!NOT_)EXECUTED(?!_BY)", text.replace("NOT_EXECUTED_BY_ESTACK", "")), "no execution state other than NOT_EXECUTED*"
    assert env["analysis"]["change_advisory"]["execution_status"] == "NOT_EXECUTED_BY_ESTACK"
    c.close()


@test
def evidence_lineage_ids_are_stable_ordered_and_reproducible_for_identical_evidence():
    c = ready()
    refs = gather(c, FULL)
    a1 = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": refs})[0]["analysis"]
    a2 = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": list(refs)})[0]["analysis"]
    strip = lambda a: {k: v for k, v in a.items() if k not in ("change_advisory",)}
    assert strip(a1) == strip(a2) and [x["evidence_id"] for x in a1["evidence_lineage"]] == sorted(x["evidence_id"] for x in a1["evidence_lineage"])
    c.close()


if __name__ == "__main__":
    raise SystemExit(run_all())
