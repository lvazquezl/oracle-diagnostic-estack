"""Phase 14 — integration: Phase 13 diagnostics -> Phase 11 RCA -> Phase 12 advisory/knowledge, with evidence
references and uncertainty preserved, the whole chain provably read-only for the repository, and the
registry/readiness view consistent with what the runtime actually reports."""
import copy
import json
import os
import re

from tests.p14.harness import MARKER, PRIMARY, ROOT, ProcClient, default_targets, make_fixture_dir, run_all, test, tmpdir

FULL = ["Q-ORA-DIAGNOSTICS-ALERTLOG-001", "os.get_process_limits", "os.get_oracle_process_summary"]


def ready(**kw):
    c = ProcClient(**kw)
    c.initialize()
    return c


def gather(c, collectors=FULL):
    return [c.collect(x)["evidence_refs"][0] for x in collectors]


def analyze(c, refs, alias=PRIMARY):
    return c.call("diagnostics.analyze_incident", {"target_alias": alias, "evidence_refs": refs})[0]


@test
def evidence_references_flow_unchanged_from_collection_to_rca_advisory_and_lineage():
    c = ready()
    try:
        refs = gather(c)
        env = analyze(c, refs)
        a = env["analysis"]
        assert env["evidence_refs"] == refs and env["status"] == "OK"
        lineage = {x["evidence_id"]: x for x in a["evidence_lineage"]}
        assert {x["evidence_ref"] for x in lineage.values()} <= set(refs) and {x["collector_id"] for x in lineage.values()} == set(FULL)
        hyp = next(h for h in a["hypotheses"] if h["status"] == "CONFIRMED")
        assert set(hyp["supporting_evidence_ids"]) <= set(lineage), "every EVD cited by the RCA resolves to a gateway evidence reference"
        assert a["rca"]["confirmed_hypothesis_ids"] == [hyp["hypothesis_id"]] and a["incident_id"].startswith("INC-")
        assert a["rca"]["rca_id"].startswith("RCA-" + a["incident_id"])
        adv = a["change_advisory"]
        assert adv["execution_status"] == "NOT_EXECUTED_BY_ESTACK" and adv["review_status"] != "APPROVED_BY_HUMAN" and adv["change_ids"]
        assert all(r["execution_status"] == "NOT_EXECUTED" for r in a["recommendations"])
        assert a["knowledge_candidate"]["lifecycle_state"] == "CANDIDATE" and "not knowledge" in a["knowledge_candidate"]["note"]
        assert MARKER not in json.dumps(env)
    finally:
        c.close()


@test
def contradicting_or_missing_evidence_is_never_promoted_to_a_fact_along_the_chain():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {
            (PRIMARY, "Q-ORA-DIAGNOSTICS-ALERTLOG-001"): [{"event_time": "2026-03-11T15:02:31Z", "signature": "ORA-27300", "message": "x"}],
            (PRIMARY, "os.get_process_limits"): [{"observed_at_utc": "2026-03-11T15:02:00Z", "nproc_utilization_percent": 35.0, "limit_source": "rlimit_nproc"}],
            (PRIMARY, "os.get_oracle_process_summary"): [{"observed_at_utc": "2026-03-11T15:02:10Z", "fork_failures_observed": True, "oracle_process_count": 50}]})
        c = ready(fixtures=fx)
        try:
            a = analyze(c, gather(c))["analysis"]
            assert a["rca"]["completeness"] != "CONFIRMED" and not a["rca"]["confirmed_hypothesis_ids"]
            assert any(h["contradicting_evidence_ids"] for h in a["hypotheses"]), "the contradiction must survive into the analysis"
            assert not [h for h in a["hypotheses"] if h["status"] == "CONFIRMED"]
            assert a["change_advisory"]["change_ids"] == [] and a["knowledge_candidate"]["lifecycle_state"] != "CANDIDATE"
            assert all(r["execution_status"] == "NOT_EXECUTED" for r in a["recommendations"])
            text = json.dumps(a)
            assert text.count('"CONFIRMED"') == 0 or "CONFIRMED_" not in text.replace('"CONFIRMED"', "")
        finally:
            c.close()
    c = ready()
    try:
        one = analyze(c, gather(c, ["Q-ORA-DIAGNOSTICS-ALERTLOG-001"]))["analysis"]
        assert one["rca"]["completeness"] != "CONFIRMED", "a single signature is a symptom, not a cause"
        assert one["change_advisory"]["change_ids"] == []
        env, raw = c.call("diagnostics.analyze_incident", {"target_alias": PRIMARY, "evidence_refs": [c.collect("Q-DISC-IDENTITY-001")["evidence_refs"][0]]})
        assert raw["isError"] and env["error"]["code"] == "E_INSUFFICIENT_EVIDENCE", "identity evidence alone cannot carry an analysis"
    finally:
        c.close()


@test
def the_whole_chain_is_read_only_for_the_repository():
    from release_readiness import fingerprint
    before = fingerprint.take(ROOT)
    c = ready()
    try:
        refs = gather(c)
        analyze(c, refs)
        c.call("diagnostics.get_evidence", {"evidence_ref": refs[0], "target_alias": PRIMARY})
        c.call("diagnostics.list_capabilities", {})
        c.call("diagnostics.describe_collector", {"collector_id": "Q-ORA-DIAGNOSTICS-ALERTLOG-001"})
    finally:
        assert c.close() == 0
    after = fingerprint.take(ROOT)
    assert before["aggregate_sha256"] == after["aggregate_sha256"], fingerprint.diff(before, after)
    assert all(l.startswith("AUDIT ") for l in c.stderr_text.splitlines() if l.strip())
    assert not os.path.exists(os.path.join(ROOT, ".audit")) and not os.path.exists(os.path.join(ROOT, "analysis", "ANA-20260311-001"))


@test
def runtime_provenance_and_the_registry_maturity_tell_the_same_story():
    from release_readiness import registry
    reg = registry.load_registry(ROOT)
    by_collector = {c["collector_id"]: c for c in reg["components"] if c["kind"] == "collector"}
    c = ready()
    try:
        for cid, comp in by_collector.items():
            if cid == "Q-DG-STATS-001":
                continue                                             # standby-only: not applicable to the primary fixture target
            env = c.collect(cid)
            assert env["provenance"] == {"kind": "FIXTURE", "real_observation": False} and env["collected_at_utc"] is None, cid
            assert comp["maturity"] == "TESTED_WITH_SYNTHETIC_FIXTURES", "a collector whose evidence is fixture data must not be registered above that"
        caps = c.call("diagnostics.list_capabilities", {})[0]
        adapters = {t["adapter"]: t["adapter_status"] for t in caps["targets"]}
        registry_adapters = {a["adapter_name"]: a["maturity"] for a in reg["components"] if a["kind"] == "adapter"}
        assert adapters["fixture"] == "VERIFIED_FIXTURE" and registry_adapters["fixture"] == "TESTED_WITH_SYNTHETIC_FIXTURES"
        assert adapters["oracle_sql"] == "DISABLED" and registry_adapters["oracle_sql"] == "DISABLED"
        assert not [t for t in caps["targets"] if t["enabled"] and t["adapter"] != "fixture"]
    finally:
        c.close()


@test
def the_readiness_view_of_the_chain_matches_the_runtime_and_the_real_pilot_stays_blocked():
    from release_readiness import gate
    rep = gate.run_gate(ROOT, _evidence_check=lambda root, ev: ({"id": "C10_EVIDENCE_PACKAGE", "status": "PASS", "detail": "stub"}, {"result": "PASS", "tree_identity": "VERIFIED", "checks": []}))
    r = rep["readiness"]
    assert r["READY_FOR_LOCAL_FIXTURE_PILOT"] is True, r["local_fixture_pilot_blockers"]
    assert r["READY_FOR_REAL_ENVIRONMENT_PILOT"] is False and len(r["real_environment_pilot_blockers"]) >= 6
    assert r["real_environment_plan"] == "docs/PILOT_ACCEPTANCE_CHECKLIST.md" and os.path.isfile(os.path.join(ROOT, r["real_environment_plan"]))
    text = open(os.path.join(ROOT, "docs", "PILOT_ACCEPTANCE_CHECKLIST.md"), encoding="utf-8").read()
    for blocker in r["real_environment_pilot_blockers"]:
        assert blocker in text, f"blocker {blocker} is not explained in the pilot checklist"


@test
def a_knowledge_candidate_from_the_chain_cannot_be_approved_by_the_governance_tooling_on_its_own():
    from release_readiness import governance
    c = ready()
    try:
        cand = analyze(c, gather(c))["analysis"]["knowledge_candidate"]
    finally:
        c.close()
    assert cand["lifecycle_state"] == "CANDIDATE"
    record = {"record_id": "GOV-KB-TEST-01", "artifact_type": "knowledge", "artifact_id": "KB-CANDIDATE-001", "semver": "0.1.0", "state": "REVIEWED", "change_class": "NORMAL",
              "owner_role": "dba-lead", "proposer_id": "REV-CURATOR01", "sources": ["docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md"], "evidence_refs": ["EVD-1", "EVD-3"],
              "compatibility": {"oracle_versions": ["19c"], "platforms": ["Linux"], "breaking": False},
              "history": [{"state": "PROPOSED", "at_utc": "2026-09-20T10:00:00Z", "actor_id": "REV-CURATOR01"}, {"state": "REVIEWED", "at_utc": "2026-09-20T11:00:00Z", "actor_id": "REV-DBALEAD01"}],
              "revalidate_by_utc": "2027-03-01T00:00:00Z"}
    assert governance.validate_record(record, "2026-09-20T12:00:00Z") == []
    _, findings = governance.apply_transition(record, "APPROVED", "REV-DBALEAD01", "2026-09-20T13:00:00Z")
    assert "GOV_REVIEW_MISSING" in {f["code"] for f in findings}, "nothing in the tooling can approve on a human's behalf"
    _, findings = governance.apply_transition(record, "APPROVED", "REV-CURATOR01", "2026-09-20T13:00:00Z",
                                              review={"reviewer_id": "REV-CURATOR01", "decision": "APPROVED", "decision_at_utc": "2026-09-20T13:00:00Z",
                                                      "verification": "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"})
    assert "GOV_SELF_APPROVAL" in {f["code"] for f in findings}


if __name__ == "__main__":
    raise SystemExit(run_all())
