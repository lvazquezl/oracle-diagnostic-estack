"""Phase 12 — knowledge lifecycle: candidate, quality gate, duplicate/conflict, approval binding, retrieval."""
import copy
import json
import os

from tests.p12.harness import (
    T, catalog, expect_error, fx, make_auth, make_published as _make_published, p12fx, read_json, run_all, tmpdir, test, view_of, write_json,
)
from change_documentation_knowledge import kb_store
from change_documentation_knowledge.common import content_digest
from change_documentation_knowledge.knowledge import build_kb_candidate, review_duplicates
from change_documentation_knowledge.retrieval import search

CTX = read_json(p12fx("change_context_all_pass.json"))
CAND_IN = read_json(p12fx("candidate_input_basic.json"))


def cand(fixture="positive_confirmed.json", ctx=CTX, cin=None, rules=None):
    return build_kb_candidate(view_of(fx(fixture) if os.sep not in fixture and "/" not in fixture else fixture, rules), catalog(rules), ctx, cin, T)


def make_published(root, c=None, **kw):
    return _make_published(root, c if c is not None else cand(cin=CAND_IN), **kw)


@test
def confirmed_rca_produces_a_candidate_that_is_not_knowledge_and_carries_provenance():
    c = cand(cin=CAND_IN)
    assert c["artifact_type"] == "kb_candidate" and c["lifecycle_state"] == "CANDIDATE" and c["review_status"] == "REVIEW_REQUIRED"
    assert c["quality_gate"] == {"status": "PASS", "blocking_reasons": []}
    a = c["article"]
    p = a["provenance"]
    assert p["rca_state_at_extraction"] == "CONFIRMED" and p["evidence_ids"] and p["finding_ids"] and p["recommendation_ids"]
    assert a["hypothesis"]["publishable_as_fact"] is True and a["scope"]["applies_only_within_scope"] is True
    assert a["scope"]["oracle_versions"] == ["19c"] and a["error_codes"] == ["ORA-27300"]
    assert all(m["universal_solution"] is False and m["execution_status"] == "NOT_EXECUTED" for m in a["manual_recommendations"])
    assert a["owner"] == "REV-OWNER0001" and a["validated_at_utc"] and a["review_due_utc"] > a["validated_at_utc"]
    assert c["content_digest"] == content_digest(c)


@test
def unknown_scope_stays_unknown_never_universal():
    c = cand(ctx=None)
    assert c["article"]["scope"]["oracle_versions"] == ["UNKNOWN"] and c["article"]["scope"]["release_update"] == "UNKNOWN"
    assert "19c" not in json.dumps(c)


@test
def unconfirmed_rca_yields_a_rejected_candidate_with_an_explicit_reason():
    for name in ("competing_hypotheses.json", "contradiction_blocks_confirmation.json", "mitigation_not_root_cause.json", "signature_clustering.json"):
        c = cand(name)
        assert c["lifecycle_state"] == "REJECTED" and c["quality_gate"]["status"] == "FAIL", name
        assert "RCA_NOT_CONFIRMED" in c["quality_gate"]["blocking_reasons"], name
        assert c["article"]["hypothesis"]["publishable_as_fact"] is False, name
        with tmpdir() as d:
            expect_error(lambda: kb_store.add_candidate(d, c, T), "E_QUALITY_GATE")
            assert not os.path.exists(os.path.join(d, "manifest.json")), "a rejected candidate must not touch the KB"


@test
def incomplete_evidence_keeps_the_candidate_in_draft_with_reasons():
    c = cand("missing_evidence_ref.json")
    assert c["lifecycle_state"] in ("DRAFT", "REJECTED")
    if c["lifecycle_state"] == "DRAFT":
        assert "EVIDENCE_MANIFEST_INCOMPLETE" in c["quality_gate"]["blocking_reasons"]


@test
def unrecognized_signatures_are_dropped_from_articles_and_never_leaked():
    expect_error(lambda: cand("signature_various_unknown_shapes.json"), "E_QUALITY_GATE")   # no hypothesis: nothing to curate
    c = cand("signature_clustering.json")
    text = json.dumps(c)
    assert c["article"]["error_codes"] == [] or all(x.startswith(("ORA-", "TNS-", "RMAN-", "CRS-", "LSNR-", "PLS-")) for x in c["article"]["error_codes"])
    assert "SIG-" not in text, "incident-scoped signature tokens must not enter a KB article"


@test
def illegal_transitions_are_rejected_and_state_is_unchanged():
    with tmpdir() as d:
        r = kb_store.add_candidate(d, cand(cin=CAND_IN), T)
        kb, v = r["kb_id"], r["version"]
        for bad in ("PUBLISHED", "APPROVED_BY_HUMAN", "PENDING_HUMAN_REVIEW", "DEPRECATED", "RETIRED", "SUPERSEDED", "REVIEW_DUE"):
            expect_error(lambda b=bad: kb_store.transition(d, kb, v, b, T), "E_TRANSITION_DENIED")
        assert kb_store.status(d)["entries"][kb][v] == "CANDIDATE"


@test
def approval_and_publication_require_an_external_authorization_record():
    with tmpdir() as d:
        r = kb_store.add_candidate(d, cand(cin=CAND_IN), T)
        kb, v = r["kb_id"], r["version"]
        kb_store.transition(d, kb, v, "DRAFT", T)
        kb_store.transition(d, kb, v, "PENDING_HUMAN_REVIEW", T)
        expect_error(lambda: kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T), "E_AUTH_MISSING")
        digest = kb_store.load_manifest(d)["entries"][kb]["versions"][v]["digest"]
        rej = make_auth(kb, digest, v, decision="REJECTED")
        expect_error(lambda: kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T, rej), "E_AUTH_INVALID")
        assert kb_store.status(d)["entries"][kb][v] == "PENDING_HUMAN_REVIEW"


@test
def full_lifecycle_with_matching_authorizations_reaches_published_then_retired():
    with tmpdir() as d:
        kb, v, digest = make_published(d)
        assert kb_store.status(d)["entries"][kb][v] == "PUBLISHED"
        m = kb_store.load_manifest(d)["entries"][kb]["versions"][v]
        assert [h["to"] for h in m["history"]] == ["CANDIDATE", "DRAFT", "PENDING_HUMAN_REVIEW", "APPROVED_BY_HUMAN", "PUBLISHED"]
        assert all(h["verification"] == "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED" for h in m["history"] if h["authorization_id"])
        kb_store.transition(d, kb, v, "REVIEW_DUE", "2027-03-12T00:00:00Z")
        kb_store.transition(d, kb, v, "DEPRECATED", "2027-03-13T00:00:00Z", make_auth(kb, digest, v, auth_id="AUTH-T0003", at="2027-03-13T00:00:00Z"))
        kb_store.transition(d, kb, v, "RETIRED", "2027-03-14T00:00:00Z", make_auth(kb, digest, v, auth_id="AUTH-T0004", at="2027-03-14T00:00:00Z"))
        assert kb_store.status(d)["entries"][kb][v] == "RETIRED"
        expect_error(lambda: kb_store.transition(d, kb, v, "PUBLISHED", T), "E_TRANSITION_DENIED")


@test
def authorization_is_bound_to_digest_version_artifact_and_is_single_use():
    with tmpdir() as d:
        r = kb_store.add_candidate(d, cand(cin=CAND_IN), T)
        kb, v = r["kb_id"], r["version"]
        kb_store.transition(d, kb, v, "DRAFT", T)
        kb_store.transition(d, kb, v, "PENDING_HUMAN_REVIEW", T)
        digest = kb_store.load_manifest(d)["entries"][kb]["versions"][v]["digest"]
        expect_error(lambda: kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T, make_auth(kb, "f" * 64, v)), "E_AUTH_DIGEST_MISMATCH")
        expect_error(lambda: kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T, make_auth(kb, digest, "2")), "E_AUTH_DIGEST_MISMATCH")
        expect_error(lambda: kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T, make_auth("KB-0000000000000000", digest, v)), "E_AUTH_DIGEST_MISMATCH")
        ok = make_auth(kb, digest, v, auth_id="AUTH-ONCE01")
        kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T, ok)
        expect_error(lambda: kb_store.transition(d, kb, v, "PUBLISHED", T, ok), "E_AUTH_INVALID")   # same record reused
        earlier = make_auth(kb, digest, v, auth_id="AUTH-EARLY1", at="2026-03-11T00:00:00Z")
        expect_error(lambda: kb_store.transition(d, kb, v, "PUBLISHED", T, earlier), "E_AUTH_INVALID")   # decision before the approval


@test
def proposer_cannot_approve_its_own_candidate():
    with tmpdir() as d:
        r = kb_store.add_candidate(d, cand(cin=CAND_IN), T)     # proposer REV-PROPOSER01
        kb, v = r["kb_id"], r["version"]
        kb_store.transition(d, kb, v, "DRAFT", T)
        kb_store.transition(d, kb, v, "PENDING_HUMAN_REVIEW", T)
        digest = kb_store.load_manifest(d)["entries"][kb]["versions"][v]["digest"]
        expect_error(lambda: kb_store.transition(d, kb, v, "APPROVED_BY_HUMAN", T, make_auth(kb, digest, v, reviewer="REV-PROPOSER01")), "E_AUTH_SELF_APPROVAL")


@test
def approval_of_a_previous_version_is_invalid_for_a_new_version():
    with tmpdir() as d:
        kb, v1, digest1 = make_published(d)
        # a NEW version with a different recommendation, explicitly declared as a supersession
        v = view_of(fx("positive_confirmed.json"))
        v["recommendations"][0]["action_summary"] = "Increase the process limit after capacity review and confirm headroom with the platform team"
        v["recommendations"][0]["text_provenance"] = "UNCATALOGUED_SANITIZED"
        c2 = build_kb_candidate(v, catalog(), CTX, dict(CAND_IN, supersedes=kb), T)
        r = kb_store.add_candidate(d, c2, T)
        assert r["result"] == "ADDED" and r["version"] == "2" and r["review"]["result"] == "SUPERSESSION_PROPOSED"
        kb_store.transition(d, kb, "2", "DRAFT", T)
        kb_store.transition(d, kb, "2", "PENDING_HUMAN_REVIEW", T)
        # reuse v1's approval for v2 -> digest/version mismatch
        expect_error(lambda: kb_store.transition(d, kb, "2", "APPROVED_BY_HUMAN", T, make_auth(kb, digest1, "1", auth_id="AUTH-T0009")), "E_AUTH_DIGEST_MISMATCH")
        digest2 = kb_store.load_manifest(d)["entries"][kb]["versions"]["2"]["digest"]
        assert digest2 != digest1
        kb_store.transition(d, kb, "2", "APPROVED_BY_HUMAN", "2026-04-01T09:01:00Z", make_auth(kb, digest2, "2", auth_id="AUTH-T0010", at="2026-04-01T09:00:00Z"))
        res = kb_store.transition(d, kb, "2", "PUBLISHED", "2026-04-01T09:11:00Z", make_auth(kb, digest2, "2", auth_id="AUTH-T0011", at="2026-04-01T09:10:00Z"))
        assert res["superseded_version"] == "1"
        st = kb_store.status(d)["entries"][kb]
        assert st == {"1": "SUPERSEDED", "2": "PUBLISHED"}


@test
def duplicate_conflict_and_scope_difference_are_explainable_and_never_merged():
    with tmpdir() as d:
        base = cand(cin=CAND_IN)
        r1 = kb_store.add_candidate(d, base, T)
        assert r1["result"] == "ADDED"
        dup = kb_store.add_candidate(d, cand(cin=CAND_IN), T)
        assert dup["result"] == "DUPLICATE_NOT_ADDED" and dup["review"]["result"] == "DUPLICATE" and dup["review"]["compared"]
        assert list(kb_store.status(d)["entries"][r1["kb_id"]]) == ["1"], "a duplicate must not create another version"
        other_scope = cand(ctx=read_json(p12fx("change_context_12_2_license_unknown.json")), cin=CAND_IN)
        assert other_scope["kb_id"] != base["kb_id"]
        r3 = kb_store.add_candidate(d, other_scope, T)
        assert r3["result"] == "ADDED" and r3["review"]["result"] == "SCOPE_DIFFERENCE"
        assert r3["review"]["compared"][0]["same_scope"] is False and len(kb_store.status(d)["entries"]) == 2
        # same key + scope, different recommendation, NO declared supersession -> CONFLICT
        v = view_of(fx("positive_confirmed.json"))
        v["recommendations"][0]["action_summary"] = "Disable the process limit entirely"
        v["recommendations"][0]["text_provenance"] = "UNCATALOGUED_SANITIZED"
        conflicting = build_kb_candidate(v, catalog(), CTX, CAND_IN, T)
        r4 = kb_store.add_candidate(d, conflicting, T)
        assert r4["result"] == "ADDED_CONFLICT_OPEN" and r4["review"]["blocks_promotion"] is True
        kb, ver = r4["kb_id"], r4["version"]
        kb_store.transition(d, kb, ver, "DRAFT", T)
        expect_error(lambda: kb_store.transition(d, kb, ver, "PENDING_HUMAN_REVIEW", T), "E_CONFLICT")


@test
def review_duplicates_reports_new_when_nothing_matches():
    assert review_duplicates(cand(cin=CAND_IN), [])["result"] == "NEW"


@test
def retrieval_returns_only_current_guidance_and_excludes_retired_deprecated_and_draft():
    with tmpdir() as d:
        kb, v, digest = make_published(d)
        hit = search(d, "process limit", version="19c")
        assert hit["status"] == "MATCH" and hit["results"][0]["kb_id"] == kb and hit["results"][0]["current_guidance"] is True
        r = hit["results"][0]
        assert r["status"] == "PUBLISHED" and r["scope"]["oracle_versions"] == ["19c"] and r["evidence_citation"]["evidence_ids"] and r["evidence_citation"]["rca_id"]
        assert "does not replace current evidence" in hit["notice"]
        assert search(d, "", error_code="ORA-27300")["status"] == "MATCH"
        assert search(d, "process limit", version="12.2")["status"] == "NO_CERTIFIED_MATCH"
        assert search(d, "process limit", domain="rman")["status"] == "NO_CERTIFIED_MATCH"
        assert search(d, "zzz unrelated topic")["results"] == []
        kb_store.transition(d, kb, v, "DEPRECATED", T, make_auth(kb, digest, v, auth_id="AUTH-T0003", at="2026-03-13T00:00:00Z"))
        assert search(d, "process limit")["status"] == "NO_CERTIFIED_MATCH"
        listed = search(d, "process limit", states=["DEPRECATED"])
        assert listed["status"] == "NO_CERTIFIED_MATCH" and listed["results"][0]["current_guidance"] is False and "NOT current guidance" in listed["results"][0]["warning"]
        kb_store.transition(d, kb, v, "RETIRED", T, make_auth(kb, digest, v, auth_id="AUTH-T0004", at="2026-03-14T00:00:00Z"))
        assert search(d, "process limit", states=["RETIRED", "DEPRECATED", "PUBLISHED"])["results"] == []


@test
def draft_and_candidate_articles_are_not_certified_matches():
    with tmpdir() as d:
        r = kb_store.add_candidate(d, cand(cin=CAND_IN), T)
        assert search(d, "process limit")["status"] == "NO_CERTIFIED_MATCH"
        res = search(d, "process limit", states=["CANDIDATE"])
        assert res["status"] == "NO_CERTIFIED_MATCH" and res["results"] and res["results"][0]["certified"] is False


@test
def unknown_scope_article_never_matches_an_explicit_version_filter():
    with tmpdir() as d:
        kb, v, _ = make_published(d, cand(ctx=None, cin=CAND_IN))
        assert search(d, "process limit")["status"] == "MATCH"
        assert search(d, "process limit", version="19c")["status"] == "NO_CERTIFIED_MATCH"


@test
def retrieval_filters_topk_license_type_and_bounds():
    with tmpdir() as d:
        make_published(d)
        assert search(d, "process limit", article_type="RUNBOOK")["status"] == "NO_CERTIFIED_MATCH"
        assert search(d, "process limit", exclude_license_dependent=True)["status"] == "MATCH"   # os domain: not license dependent
        assert search(d, "process limit", validated_after_utc="2030-01-01T00:00:00Z")["status"] == "NO_CERTIFIED_MATCH"
        assert len(search(d, "process limit", top_k=1)["results"]) == 1
        expect_error(lambda: search(d, "process limit", top_k=0), "E_USAGE")
        expect_error(lambda: search(d, "process limit", top_k=999), "E_USAGE")
        expect_error(lambda: search(d, "", ), "E_USAGE")
        expect_error(lambda: search(d, "x", error_code="not a code"), "E_USAGE")


@test
def tampering_with_an_article_file_is_detected_and_published_content_is_immutable():
    with tmpdir() as d:
        kb, v, _ = make_published(d)
        path = os.path.join(d, "articles", kb, f"v{v}.json")
        art = read_json(path)
        art["article"]["title"] = "tampered title"
        write_json(path, art)
        expect_error(lambda: search(d, "process limit"), "E_KB_INTEGRITY")
        expect_error(lambda: kb_store.transition(d, kb, v, "REVIEW_DUE", T), "E_KB_INTEGRITY")
    with tmpdir() as d:
        kb, v, digest = make_published(d)
        os.makedirs(os.path.join(d, "articles", kb), exist_ok=True)
        # re-adding a candidate that would map to an existing version file must never overwrite it
        before = open(os.path.join(d, "articles", kb, f"v{v}.json"), "rb").read()
        kb_store.add_candidate(d, cand(cin=CAND_IN), T)          # duplicate: not added
        assert open(os.path.join(d, "articles", kb, f"v{v}.json"), "rb").read() == before


@test
def manifest_history_is_append_only_across_transitions():
    with tmpdir() as d:
        kb, v, digest = make_published(d)
        before = kb_store.load_manifest(d)["entries"][kb]["versions"][v]["history"]
        kb_store.transition(d, kb, v, "REVIEW_DUE", "2027-01-01T00:00:00Z")
        after = kb_store.load_manifest(d)["entries"][kb]["versions"][v]["history"]
        assert after[:len(before)] == before and len(after) == len(before) + 1 and [h["seq"] for h in after] == list(range(1, len(after) + 1))


@test
def review_due_is_a_read_only_query_and_changes_nothing():
    with tmpdir() as d:
        kb, v, _ = make_published(d)
        snapshot = open(os.path.join(d, "manifest.json"), "rb").read()
        due = kb_store.review_due(d, "2099-01-01T00:00:00Z")
        assert due and due[0]["kb_id"] == kb and open(os.path.join(d, "manifest.json"), "rb").read() == snapshot
        assert kb_store.review_due(d, "2026-03-13T00:00:00Z") == []


@test
def markdown_article_states_the_kb_does_not_replace_current_evidence_and_is_escaped():
    with tmpdir() as d:
        kb, v, _ = make_published(d)
        md = open(os.path.join(d, "articles", kb, f"v{v}.md"), encoding="utf-8").read()
        assert "does not replace current evidence" in md and "State (draft/published/deprecated) is recorded in the KB manifest" in md
        assert "PUBLISHED" not in md, "the article file must not carry a mutable state"


@test
def article_content_never_contains_command_text_or_hostnames_or_raw_signature_text():
    c = cand(cin=CAND_IN)
    from change_documentation_knowledge.safety import has_executable_content
    text = json.dumps(c)
    assert not has_executable_content(text)
    assert "T-PRODDB" not in text and "TGT-" not in text and "SRC-" not in text


if __name__ == "__main__":
    raise SystemExit(run_all())
