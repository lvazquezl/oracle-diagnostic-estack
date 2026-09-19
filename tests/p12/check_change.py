"""Phase 12 — change advisory engine (plane A) and e-stack governance (plane B): functional checks."""
import copy
import json
import re

from tests.p12.harness import (
    T, fx, make_auth, p12fx, read_json, expect_error, run_all, test, view_of,
)
from change_documentation_knowledge.change import (
    GATES, build_change_advisory, build_estack_change, parse_change_context, render_change_advisory_md,
)
from change_documentation_knowledge.common import content_digest

CTX_PASS = read_json(p12fx("change_context_all_pass.json"))


def adv_for(fixture, ctx=None, rules=None):
    return build_change_advisory(view_of(fx(fixture) if not fixture.startswith("/") and "\\" not in fixture and ":" not in fixture else fixture, rules), ctx, T)


@test
def confirmed_rca_yields_coherent_operational_chg_with_resolving_refs():
    view = view_of(fx("positive_confirmed.json"))
    adv = build_change_advisory(view, None, T)
    assert adv["rca_state"]["completeness"] == "CONFIRMED" and len(adv["changes"]) == 1
    c = adv["changes"][0]
    assert re.match(r"^CHG-INC-\d{8}-\d{3}-001$", c["change_id"])
    assert c["change_type"] == "OPERATIONAL_MANUAL"
    assert c["execution_status"] == "NOT_EXECUTED_BY_ESTACK"
    assert all(s["execution_status"] == "NOT_EXECUTED_BY_ESTACK" for s in c["proposed_manual_steps"])
    ev_ids = {e for f in view["findings"] for e in f["evidence_ids"]}
    assert c["evidence_refs"] and set(c["evidence_refs"]) <= ev_ids
    assert set(c["source_refs"]["finding_ids"]) <= {f["finding_id"] for f in view["findings"]}
    assert set(c["source_refs"]["hypothesis_ids"]) <= {h["hypothesis_id"] for h in view["hypotheses"]}
    assert set(c["recommendation_refs"]) <= {r["rec_id"] for r in view["recommendations"]}
    for key in ("schema_version", "generated_at_utc", "generator_version", "sanitization_status", "review_status", "content_digest"):
        assert adv[key], key
    assert adv["content_digest"] == content_digest(adv) and c["content_digest"] == content_digest(c)


@test
def required_change_contract_fields_are_all_present():
    c = build_change_advisory(view_of(fx("positive_confirmed.json")), None, T)["changes"][0]
    required = ["change_id", "change_type", "status", "source_refs", "evidence_refs", "recommendation_refs", "context", "objective",
                "scope", "out_of_scope", "assumptions", "proposed_manual_steps", "entry_criteria", "exit_criteria", "suggested_window",
                "responsible", "dependencies", "impact", "risk_factors", "affected_components", "blast_radius", "service_dependencies",
                "expected_benefit_as_hypothesis", "reversibility", "rollback_plan", "rollback_preconditions", "rollback_risks",
                "validation_plan", "stop_conditions", "observability", "open_questions", "oracle_version", "release_update", "platform",
                "topology", "capability_gate", "license_gate", "privilege_gate", "change_window_gate", "execution_status"]
    missing = [k for k in required if k not in c]
    assert not missing, f"missing contract fields: {missing}"
    assert c["responsible"] == "TO_BE_DEFINED" and c["suggested_window"]["status"] == "TO_BE_DEFINED"


@test
def gates_default_to_unknown_and_block_readiness_unknown_is_not_not_applicable():
    c = build_change_advisory(view_of(fx("positive_confirmed.json")), None, T)["changes"][0]
    for g in ("capability_gate", "license_gate", "privilege_gate", "change_window_gate"):
        assert c[g]["status"] == "UNKNOWN", g
    assert c["readiness"] == "REVIEW_REQUIRED" and c["status"] == "REVIEW_REQUIRED"
    assert {"GATE_UNRESOLVED_CAPABILITY", "GATE_UNRESOLVED_LICENSE", "GATE_UNRESOLVED_PRIVILEGE", "GATE_UNRESOLVED_CHANGE_WINDOW"} <= set(c["review_reasons"])
    assert c["oracle_version"] == "UNKNOWN" and c["platform"] == "UNKNOWN"


@test
def all_gates_pass_makes_it_ready_for_human_review_but_never_approved():
    adv = build_change_advisory(view_of(fx("positive_confirmed.json")), CTX_PASS, T)
    c = adv["changes"][0]
    assert c["readiness"] == "READY_FOR_HUMAN_REVIEW" and c["status"] == "REVIEW_REQUIRED"
    assert c["review_status"] == "REVIEW_REQUIRED" and "approval_declaration" not in c
    assert c["oracle_version"] == "19c" and c["release_update"] == "RU 19.22"


@test
def failed_gate_blocks_the_change():
    ctx = read_json(p12fx("change_context_privilege_fail.json"))
    c = build_change_advisory(view_of(fx("positive_confirmed.json")), ctx, T)["changes"][0]
    assert c["readiness"] == "BLOCKED" and "GATE_FAILED_PRIVILEGE" in c["blockers"] and c["status"] == "DRAFT"


@test
def license_dependent_domain_never_accepts_not_applicable_without_evidence():
    ctx = copy.deepcopy(CTX_PASS)
    ctx["gates"]["license"] = {"status": "NOT_APPLICABLE", "basis": "assumed"}
    view = view_of(p12fx("incidents/dataguard_confirmed.json"), p12fx("rules_cross_domain.json"))
    c = build_change_advisory(view, ctx, T)["changes"][0]
    assert c["license_gate"]["status"] == "UNKNOWN", "Data Guard must not default to NOT_APPLICABLE for licensing"
    assert "GATE_UNRESOLVED_LICENSE" in c["review_reasons"] and c["license_note"]


@test
def rca_inconclusive_produces_no_change_and_asserts_no_cause():
    for name in ("competing_hypotheses.json", "contradiction_blocks_confirmation.json", "mitigation_not_root_cause.json", "negative_temporal_proximity.json"):
        view = view_of(fx(name))
        adv = build_change_advisory(view, CTX_PASS, T)
        assert view["root_cause"]["completeness"] in ("INCONCLUSIVE", "INSUFFICIENT_EVIDENCE"), name
        assert adv["changes"] == [], name
        assert adv["readiness"] == "INSUFFICIENT_EVIDENCE", name
        assert "RCA_NOT_CONFIRMED_NO_CAUSE_ASSERTED" in adv["warnings"], name
        assert adv["rca_state"]["completeness"] == view["root_cause"]["completeness"]


@test
def probable_cause_is_proposed_only_with_review_reason_and_high_causal_basis_risk():
    view = view_of(fx("signature_clustering.json"))
    assert view["root_cause"]["completeness"] == "PROBABLE"
    adv = build_change_advisory(view, CTX_PASS, T)
    for c in adv["changes"]:
        assert "CAUSE_NOT_CONFIRMED" in c["review_reasons"]
        assert next(r for r in c["risk_factors"] if r["dimension"] == "causal_basis")["level"] == "MEDIUM"
        assert c["readiness"] != "READY_FOR_HUMAN_REVIEW"


@test
def incomplete_evidence_manifest_forces_review_and_high_evidence_risk():
    view = view_of(fx("missing_evidence_ref.json"))
    adv = build_change_advisory(view, CTX_PASS, T)
    assert view["evidence_manifest"]["completeness"] == "INCOMPLETE_REFS"
    for c in adv["changes"]:
        assert "EVIDENCE_INCOMPLETE" in c["review_reasons"]
        assert next(r for r in c["risk_factors"] if r["dimension"] == "evidence_completeness")["level"] == "HIGH"


@test
def no_opaque_numeric_risk_score_only_named_factors_with_criteria():
    adv = build_change_advisory(view_of(fx("positive_confirmed.json")), CTX_PASS, T)
    c = adv["changes"][0]
    for r in c["risk_factors"]:
        assert set(r) >= {"dimension", "level", "criterion", "basis"}
        assert r["level"] in ("LOW", "MEDIUM", "HIGH", "UNKNOWN") and r["criterion"]
    assert not any(k in json.dumps(adv).lower() for k in ('"risk_score"', '"score"', '"risk_index"'))


@test
def dangerous_action_is_flagged_high_interruption_and_stays_manual_text():
    view = view_of(p12fx("incidents/network_listener_confirmed.json"))
    texts = [r["action_summary"] for r in view["recommendations"]]
    adv = build_change_advisory(view, CTX_PASS, T)
    listener = [c for c in adv["changes"] if re.search(r"(?i)restart", c["objective"])]
    assert listener, f"expected a restart-type proposal among {texts}"
    for c in listener:
        assert next(r for r in c["risk_factors"] if r["dimension"] == "service_interruption_potential")["level"] == "HIGH"
        assert any("interruption" in s.lower() for s in c["stop_conditions"])
        assert c["execution_status"] == "NOT_EXECUTED_BY_ESTACK"
        assert all(s["executor"] == "TO_BE_DEFINED" for s in c["proposed_manual_steps"])


@test
def rollback_and_validation_are_defined_or_they_block():
    c = build_change_advisory(view_of(fx("positive_confirmed.json")), CTX_PASS, T)["changes"][0]
    assert c["rollback_plan"]["status"] == "DEFINED_GENERIC" and c["rollback_plan"]["steps"]
    assert c["validation_plan"]["status"] == "DEFINED" and c["validation_plan"]["checks"]
    view = view_of(fx("positive_confirmed.json"))
    view["recommendations"][0]["postcheck"] = ""
    c2 = build_change_advisory(view, CTX_PASS, T)["changes"][0]
    assert "VALIDATION_MISSING" in c2["blockers"] and c2["readiness"] == "BLOCKED"


@test
def invalid_version_shape_and_unknown_context_keys_fail_closed():
    bad = copy.deepcopy(CTX_PASS)
    bad["target"]["oracle_version"] = "latest; drop everything"
    expect_error(lambda: parse_change_context(bad), "E_INPUT_INVALID")
    bad = copy.deepcopy(CTX_PASS)
    bad["surprise"] = 1
    expect_error(lambda: parse_change_context(bad), "E_INPUT_INVALID")
    bad = copy.deepcopy(CTX_PASS)
    bad["gates"]["capability"]["status"] = "MAYBE"
    expect_error(lambda: parse_change_context(bad), "E_INPUT_INVALID")


@test
def version_is_taken_from_context_never_assumed_19c():
    ctx = read_json(p12fx("change_context_12_2_license_unknown.json"))
    adv = build_change_advisory(view_of(fx("positive_confirmed.json")), ctx, T)
    md = render_change_advisory_md(adv)
    assert adv["changes"][0]["oracle_version"] == "12.2" and "19c" not in md and "19c" not in json.dumps(adv)
    none = json.dumps(build_change_advisory(view_of(fx("positive_confirmed.json")), None, T))
    assert "19c" not in none, "no context => version must stay UNKNOWN, never a 19c default"


@test
def approval_requires_matching_external_record_and_binds_the_digest():
    view = view_of(fx("positive_confirmed.json"))
    base = build_change_advisory(view, CTX_PASS, T)["changes"][0]
    ok = make_auth(base["change_id"], base["content_digest"])
    ctx = copy.deepcopy(CTX_PASS)
    ctx["human_authorizations"] = [ok]
    approved = build_change_advisory(view, ctx, T)["changes"][0]
    assert approved["status"] == "APPROVED_BY_HUMAN" and approved["review_status"] == "APPROVED_BY_HUMAN"
    assert approved["approval_declaration"]["verification"] == "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"
    assert approved["execution_status"] == "NOT_EXECUTED_BY_ESTACK", "approval must never imply execution"
    assert approved["content_digest"] == base["content_digest"], "approval must not change the digest it is bound to"
    stale = copy.deepcopy(CTX_PASS)
    stale["human_authorizations"] = [make_auth(base["change_id"], "0" * 64)]
    expect_error(lambda: build_change_advisory(view, stale, T), "E_AUTH_DIGEST_MISMATCH")
    other = copy.deepcopy(CTX_PASS)
    other["human_authorizations"] = [make_auth("CHG-INC-20260311-999-001", base["content_digest"])]
    expect_error(lambda: build_change_advisory(view, other, T), "E_REFERENCE")


@test
def content_change_invalidates_a_previous_approval():
    view = view_of(fx("positive_confirmed.json"))
    base = build_change_advisory(view, CTX_PASS, T)["changes"][0]
    approval = make_auth(base["change_id"], base["content_digest"])
    changed_ctx = copy.deepcopy(CTX_PASS)
    changed_ctx["gates"]["change_window"] = {"status": "UNKNOWN", "basis": "window no longer confirmed"}
    changed_ctx["human_authorizations"] = [approval]
    expect_error(lambda: build_change_advisory(view, changed_ctx, T), "E_AUTH_DIGEST_MISMATCH")


@test
def proposer_cannot_be_its_own_reviewer():
    view = view_of(fx("positive_confirmed.json"))
    base = build_change_advisory(view, CTX_PASS, T)["changes"][0]
    ctx = copy.deepcopy(CTX_PASS)
    ctx["proposer_ids"] = ["REV-TESTREV01"]
    ctx["human_authorizations"] = [make_auth(base["change_id"], base["content_digest"], reviewer="REV-TESTREV01")]
    expect_error(lambda: build_change_advisory(view, ctx, T), "E_AUTH_SELF_APPROVAL")


@test
def blocked_change_cannot_be_approved():
    ctx = read_json(p12fx("change_context_privilege_fail.json"))
    view = view_of(fx("positive_confirmed.json"))
    base = build_change_advisory(view, ctx, T)["changes"][0]
    ctx["human_authorizations"] = [make_auth(base["change_id"], base["content_digest"])]
    expect_error(lambda: build_change_advisory(view, ctx, T), "E_TRANSITION_DENIED")


@test
def external_execution_report_is_unverified_and_does_not_alter_execution_status():
    view = view_of(fx("positive_confirmed.json"))
    base = build_change_advisory(view, CTX_PASS, T)["changes"][0]
    ctx = copy.deepcopy(CTX_PASS)
    ctx["execution_reports"] = [{"change_id": base["change_id"], "reported_by": "REV-TESTREV02", "reported_at_utc": "2026-03-12T10:00:00Z",
                                 "outcome": "The administrator reports the limit was raised"}]
    c = build_change_advisory(view, ctx, T)["changes"][0]
    assert c["external_execution_report"]["status"] == "HUMAN_REPORTED_UNVERIFIED"
    assert c["external_execution_report"]["epistemic"] == "human_reported"
    assert c["execution_status"] == "NOT_EXECUTED_BY_ESTACK"
    ctx["execution_reports"][0]["change_id"] = "CHG-INC-20260311-999-001"
    expect_error(lambda: build_change_advisory(view, ctx, T), "E_REFERENCE")


@test
def markdown_is_deterministic_stable_and_contains_the_immutable_execution_status():
    view = view_of(fx("positive_confirmed.json"))
    a1 = build_change_advisory(view, CTX_PASS, T)
    a2 = build_change_advisory(copy.deepcopy(view), copy.deepcopy(CTX_PASS), T)
    assert json.dumps(a1, sort_keys=True) == json.dumps(a2, sort_keys=True)
    md = render_change_advisory_md(a1)
    assert md == render_change_advisory_md(a2) and "NOT_EXECUTED_BY_ESTACK" in md and "ADVISORY ONLY" in md
    md.encode("utf-8")


@test
def hostile_recommendation_text_is_escaped_in_markdown():
    view = view_of(fx("positive_confirmed.json"))
    view["recommendations"][0]["action_summary"] = "Review <script>alert(1)</script> and [click](javascript:alert(1)) | # heading"
    md = render_change_advisory_md(build_change_advisory(view, CTX_PASS, T))
    assert "<script>" not in md and not re.search(r"(?<!\\)\]\(", md), "raw HTML or an unescaped Markdown link survived"


# --- plane B: e-stack evolution governance ---
@test
def estack_change_reaches_pending_human_review_and_promote_stays_human():
    g = build_estack_change(read_json(p12fx("estack_request_pending_review.json")), T)
    c = g["change"]
    assert c["change_type"] == "ESTACK_DEVELOPMENT" and c["governance_state"] == "PENDING_HUMAN_REVIEW"
    assert c["current_stage"] == "HUMAN_REVIEW" and c["promote_status"] == "HUMAN_ACTION_REQUIRED"
    assert c["status"] == "REVIEW_REQUIRED" and c["review_status"] == "PENDING_HUMAN_REVIEW"
    assert c["execution_status"] == "NOT_EXECUTED_BY_ESTACK"


@test
def estack_failed_security_stage_returns_to_proposal_and_unknown_compat_blocks():
    c = build_estack_change(read_json(p12fx("estack_request_security_failed.json")), T)["change"]
    assert c["governance_state"] == "RETURNED_TO_PROPOSAL" and "STAGE_FAILED_SECURITY_VALIDATION" in c["blockers"]
    assert "COMPATIBILITY_QUERY_CONTRACT_UNKNOWN" in c["blockers"]
    c2 = build_estack_change(read_json(p12fx("estack_request_compat_unknown.json")), T)["change"]
    assert c2["governance_state"] != "PENDING_HUMAN_REVIEW", "unknown compatibility must not be treated as supported"


@test
def estack_promote_can_never_be_reported_by_the_engine_and_stage_order_is_enforced():
    req = read_json(p12fx("estack_request_pending_review.json"))
    req["stages"]["PROMOTE"] = {"status": "PASS", "evidence_note": "x"}
    expect_error(lambda: build_estack_change(req, T), "E_TRANSITION_DENIED")
    req = read_json(p12fx("estack_request_pending_review.json"))
    del req["stages"]["TEST"]
    expect_error(lambda: build_estack_change(req, T), "E_INPUT_INVALID")   # a later stage PASS without TEST


@test
def estack_self_approval_and_approval_before_review_are_denied():
    req = read_json(p12fx("estack_request_pending_review.json"))
    digest = build_estack_change(req, T)["change"]["content_digest"]
    req["authorization"] = make_auth("CHG-ESTACK-001", digest, reviewer="REV-PROPOSER01")
    expect_error(lambda: build_estack_change(req, T), "E_AUTH_SELF_APPROVAL")
    req["authorization"] = make_auth("CHG-ESTACK-001", digest, reviewer="REV-TESTREV03")
    approved = build_estack_change(req, T)["change"]
    assert approved["status"] == "APPROVED_BY_HUMAN" and approved["promote_status"] == "HUMAN_ACTION_REQUIRED"
    early = read_json(p12fx("estack_request_security_failed.json"))
    early["authorization"] = make_auth("CHG-ESTACK-001", "0" * 64, reviewer="REV-TESTREV03")
    expect_error(lambda: build_estack_change(early, T), "E_TRANSITION_DENIED")


@test
def estack_unknown_artifact_type_and_unknown_keys_are_rejected():
    req = read_json(p12fx("estack_request_pending_review.json"))
    req["artifact_types"] = ["collector"]
    expect_error(lambda: build_estack_change(req, T), "E_INPUT_INVALID")
    req = read_json(p12fx("estack_request_pending_review.json"))
    req["extra"] = 1
    expect_error(lambda: build_estack_change(req, T), "E_INPUT_INVALID")


if __name__ == "__main__":
    raise SystemExit(run_all())
