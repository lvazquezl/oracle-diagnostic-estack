"""Phase 12 — REAL Phase 11 integration through the command line only:
    python -m rca_engine.cli  (real engine, real output file)
        -> python -m change_documentation_knowledge.cli advise / document / kb-candidate  (consuming that real output)
        -> kb-add / kb-transition / kb-search
No expected RCA result is copied by hand: every assertion compares Phase 12 output against the JSON that
rca_engine actually wrote in this run."""
import json
import os

from tests.p12.harness import (
    T, cli, fx, make_auth, p12fx, rca_cli, read_json, run_all, tmpdir, test, write_json,
)


def real_rca(d, fixture, name="rca.json", extra=()):
    rc, out, err = rca_cli("--fixture", fixture, "--out", os.path.join(d, name), *extra)
    assert rc == 0, f"rca_engine failed: {err[:200]}"
    return read_json(os.path.join(d, name))


def p12(d, *args):
    rc, out, err = cli(*args)
    assert rc == 0, f"cli {args[0]} failed rc={rc}: {err[:200]}"
    return json.loads(out) if out.strip().startswith("{") else out


@test
def positive_chain_real_rca_to_advisory_documents_kb_candidate_and_lifecycle():
    with tmpdir() as d:
        rca = real_rca(d, fx("positive_confirmed.json"))
        assert rca["root_cause"]["completeness"] == "CONFIRMED"
        rca_path = os.path.join(d, "rca.json")
        base = ["--rca-result", rca_path, "--generated-at", T]
        adv_out = p12(d, "advise", *base, "--context", p12fx("change_context_all_pass.json"), "--output-dir", os.path.join(d, "adv"))
        adv = read_json(os.path.join(d, "adv", "change_advisory.json"))
        assert adv["rca_state"]["completeness"] == rca["root_cause"]["completeness"]
        assert adv["source_refs"]["rca_id"] == rca["root_cause"]["rca_id"]
        assert set(adv["source_refs"]["recommendation_ids"]) == {r["rec_id"] for r in rca["recommendations"]}
        assert set(adv["changes"][0]["evidence_refs"]) <= set(rca["evidence_manifest"]["present_refs"])
        assert adv["readiness"] == "READY_FOR_HUMAN_REVIEW" and adv["review_status"] == "REVIEW_REQUIRED"
        for kind in ("rca", "executive", "post-incident"):
            p12(d, "document", "--kind", kind, *base, "--context", p12fx("change_context_all_pass.json"), "--output-dir", os.path.join(d, kind))
            doc = read_json(os.path.join(d, kind, f"document_{kind.replace('-', '_')}.json"))
            assert doc["root_cause_state"] == rca["root_cause"]["completeness"]
            assert set(doc["source_refs"]["hypothesis_ids"]) == {h["hypothesis_id"] for h in rca["hypotheses"]}
        p12(d, "document", "--kind", "change", "--advisory", os.path.join(d, "adv", "change_advisory.json"), "--generated-at", T,
            "--output-dir", os.path.join(d, "chg"))
        p12(d, "kb-candidate", *base, "--context", p12fx("change_context_all_pass.json"), "--candidate-input", p12fx("candidate_input_basic.json"),
            "--output-dir", os.path.join(d, "kbc"))
        cand = read_json(os.path.join(d, "kbc", "kb_candidate.json"))
        assert cand["lifecycle_state"] == "CANDIDATE" and cand["source_refs"]["rca_id"] == rca["root_cause"]["rca_id"]
        kb = os.path.join(d, "kb")
        added = p12(d, "kb-add", "--kb-root", kb, "--candidate", os.path.join(d, "kbc", "kb_candidate.json"), "--generated-at", T)
        kid, ver = added["kb_id"], added["version"]
        for state in ("DRAFT", "PENDING_HUMAN_REVIEW"):
            p12(d, "kb-transition", "--kb-root", kb, "--kb-id", kid, "--version", ver, "--to", state, "--generated-at", T)
        # nothing is published without an external record
        rc, _o, err = cli("kb-transition", "--kb-root", kb, "--kb-id", kid, "--version", ver, "--to", "APPROVED_BY_HUMAN", "--generated-at", T)
        assert rc == 5 and err.startswith("E_AUTH_MISSING")
        digest = read_json(os.path.join(kb, "manifest.json"))["entries"][kid]["versions"][ver]["digest"]
        for i, state in enumerate(("APPROVED_BY_HUMAN", "PUBLISHED")):
            rec = make_auth(kid, digest, ver, auth_id=f"AUTH-P11C{i}", at=f"2026-03-12T09:0{i}:00Z")
            write_json(os.path.join(d, f"auth{i}.json"), rec)
            p12(d, "kb-transition", "--kb-root", kb, "--kb-id", kid, "--version", ver, "--to", state, "--generated-at", T,
                "--authorization", os.path.join(d, f"auth{i}.json"))
        found = p12(d, "kb-search", "--kb-root", kb, "--query", "process limit", "--error-code", "ORA-27300")
        assert found["status"] == "MATCH" and found["results"][0]["evidence_citation"]["rca_id"] == rca["root_cause"]["rca_id"]
        assert set(found["results"][0]["evidence_citation"]["evidence_ids"]) <= set(rca["evidence_manifest"]["present_refs"])


@test
def negative_chain_inconclusive_incident_is_blocked_all_the_way_to_the_kb():
    with tmpdir() as d:
        rca = real_rca(d, fx("competing_hypotheses.json"))
        assert rca["root_cause"]["completeness"] == "INCONCLUSIVE"
        base = ["--rca-result", os.path.join(d, "rca.json"), "--generated-at", T]
        p12(d, "advise", *base, "--output-dir", os.path.join(d, "adv"))
        adv = read_json(os.path.join(d, "adv", "change_advisory.json"))
        assert adv["changes"] == [] and adv["rca_state"]["completeness"] == "INCONCLUSIVE" and adv["readiness"] == "INSUFFICIENT_EVIDENCE"
        p12(d, "document", "--kind", "executive", *base, "--output-dir", os.path.join(d, "ex"))
        assert "no cause is asserted" in json.dumps(read_json(os.path.join(d, "ex", "document_executive.json")))
        p12(d, "kb-candidate", *base, "--output-dir", os.path.join(d, "kbc"))
        cand = read_json(os.path.join(d, "kbc", "kb_candidate.json"))
        assert cand["lifecycle_state"] == "REJECTED" and "RCA_NOT_CONFIRMED" in cand["quality_gate"]["blocking_reasons"]
        kb = os.path.join(d, "kb")
        rc, _o, err = cli("kb-add", "--kb-root", kb, "--candidate", os.path.join(d, "kbc", "kb_candidate.json"), "--generated-at", T)
        assert rc == 5 and err.startswith("E_QUALITY_GATE")
        assert not os.path.exists(os.path.join(kb, "manifest.json")), "the blocked candidate must not create any KB state"
        rc, out, _e = cli("kb-search", "--kb-root", os.path.join(d, "kb2"), "--query", "anything")
        assert rc == 6, "no KB exists, so nothing can be retrieved"


@test
def contradicting_evidence_survives_the_whole_chain_and_blocks_confirmation():
    with tmpdir() as d:
        rca = real_rca(d, fx("contradiction_blocks_confirmation.json"))
        contradicted = [h for h in rca["hypotheses"] if h["contradicting_evidence_ids"]]
        assert contradicted and rca["root_cause"]["completeness"] != "CONFIRMED"
        base = ["--rca-result", os.path.join(d, "rca.json"), "--generated-at", T]
        p12(d, "document", "--kind", "rca", *base, "--output-dir", os.path.join(d, "doc"))
        text = open(os.path.join(d, "doc", "document_rca.md"), encoding="utf-8").read()
        for h in contradicted:
            for e in h["contradicting_evidence_ids"]:
                assert e in text
        assert "unresolved critical contradiction: YES" in text
        p12(d, "kb-candidate", *base, "--output-dir", os.path.join(d, "kbc"))
        assert read_json(os.path.join(d, "kbc", "kb_candidate.json"))["lifecycle_state"] == "REJECTED"


@test
def probable_and_mitigation_and_temporal_proximity_states_survive_unchanged():
    for name, allowed in (("signature_clustering.json", {"PROBABLE"}), ("mitigation_not_root_cause.json", {"INSUFFICIENT_EVIDENCE", "INCONCLUSIVE"}),
                          ("negative_temporal_proximity.json", {"INSUFFICIENT_EVIDENCE", "INCONCLUSIVE"})):
        with tmpdir() as d:
            rca = real_rca(d, fx(name))
            state = rca["root_cause"]["completeness"]
            assert state in allowed, (name, state)
            p12(d, "advise", "--rca-result", os.path.join(d, "rca.json"), "--generated-at", T, "--output-dir", os.path.join(d, "a"))
            adv = read_json(os.path.join(d, "a", "change_advisory.json"))
            assert adv["rca_state"]["completeness"] == state, f"{name}: RCA state must be authoritative and unchanged"
            assert state != "CONFIRMED" and not any(c["readiness"] == "READY_FOR_HUMAN_REVIEW" for c in adv["changes"])


@test
def rca_result_and_in_process_fixture_paths_produce_identical_artifacts():
    with tmpdir() as d:
        real_rca(d, fx("positive_confirmed.json"))
        p12(d, "advise", "--rca-result", os.path.join(d, "rca.json"), "--generated-at", T, "--output-dir", os.path.join(d, "a"))
        p12(d, "advise", "--fixture", fx("positive_confirmed.json"), "--generated-at", T, "--output-dir", os.path.join(d, "b"))
        for f in ("change_advisory.json", "change_advisory.md"):
            assert open(os.path.join(d, "a", f), "rb").read() == open(os.path.join(d, "b", f), "rb").read(), f


@test
def tampered_rca_result_file_is_rejected_by_the_contract_check():
    with tmpdir() as d:
        rca = real_rca(d, fx("positive_confirmed.json"))
        rca["root_cause"]["completeness"] = "CONFIRMED"
        rca["hypotheses"][0]["status"] = "SUPPORTED"      # forged: a CONFIRMED root cause whose hypothesis is not confirmed
        write_json(os.path.join(d, "forged.json"), rca)
        rc, _o, err = cli("advise", "--rca-result", os.path.join(d, "forged.json"), "--generated-at", T, "--output-dir", os.path.join(d, "a"))
        assert rc == 3 and err.startswith("E_RCA_CONTRACT")
        assert not os.path.exists(os.path.join(d, "a"))


@test
def estack_governance_report_through_the_cli():
    with tmpdir() as d:
        out = p12(d, "advise", "--mode", "estack", "--estack-request", p12fx("estack_request_pending_review.json"), "--generated-at", T,
                  "--output-dir", os.path.join(d, "g"))
        g = read_json(os.path.join(d, "g", "estack_change_governance.json"))
        assert g["change"]["governance_state"] == "PENDING_HUMAN_REVIEW" and g["change"]["promote_status"] == "HUMAN_ACTION_REQUIRED"
        rc, _o, err = cli("advise", "--mode", "estack", "--generated-at", T, "--output-dir", os.path.join(d, "g2"))
        assert rc == 2 and err.startswith("E_USAGE")


@test
def output_is_reproducible_with_a_fixed_clock_and_only_generated_at_differs_otherwise():
    with tmpdir() as d:
        for n in ("r1", "r2"):
            p12(d, "document", "--kind", "rca", "--fixture", fx("positive_confirmed.json"), "--generated-at", T, "--output-dir", os.path.join(d, n))
        for f in os.listdir(os.path.join(d, "r1")):
            assert open(os.path.join(d, "r1", f), "rb").read() == open(os.path.join(d, "r2", f), "rb").read(), f
        p12(d, "document", "--kind", "rca", "--fixture", fx("positive_confirmed.json"), "--generated-at", "2027-01-01T00:00:00Z", "--output-dir", os.path.join(d, "r3"))
        a = read_json(os.path.join(d, "r1", "document_rca.json"))
        b = read_json(os.path.join(d, "r3", "document_rca.json"))
        assert a.pop("generated_at_utc") != b.pop("generated_at_utc")
        assert a["content_digest"] == b["content_digest"], "the digest is over content, independent of the clock"
        assert a == b


if __name__ == "__main__":
    raise SystemExit(run_all())
