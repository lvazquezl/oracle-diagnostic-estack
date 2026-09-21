"""Phase 14 — governance: lifecycle, segregation of duties, structural-only approvals, urgent changes, exceptions,
risk register, and the Phase 12 governance plane (which must stay manual and unpromoted)."""
import copy
import json
import os
import re

from tests.p14.harness import ROOT, run_all, test

NOW = "2026-09-20T20:00:00Z"
VERIF = "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"
PATH = ["PROPOSED", "REVIEWED", "APPROVED", "RELEASED", "DEPRECATED", "RETIRED"]
ACTORS = {"PROPOSED": "REV-PROPOSER-01", "REVIEWED": "REV-REVIEWER-02", "APPROVED": "REV-APPROVER-03", "RELEASED": "REV-RELEASER-04", "DEPRECATED": "REV-RELEASER-04",
          "RETIRED": "REV-RELEASER-04"}


def gov():
    from release_readiness import governance
    return governance


def rec(state="PROPOSED", **over):
    hist = [{"state": s, "at_utc": f"2026-09-{10 + i:02d}T10:00:00Z", "actor_id": ACTORS[s]} for i, s in enumerate(PATH[:PATH.index(state) + 1])]
    r = {"record_id": "GOV-TEST-001", "artifact_type": "skill", "artifact_id": "oracle/example-skill", "semver": "1.2.0", "state": state, "change_class": "NORMAL",
         "owner_role": "estack-maintainer", "proposer_id": ACTORS["PROPOSED"], "sources": ["docs/GOVERNANCE_AND_EVOLUTION.md"], "evidence_refs": ["EVD-20260910-001"],
         "compatibility": {"oracle_versions": ["19c"], "platforms": ["Linux"], "breaking": False}, "history": hist, "revalidate_by_utc": "2027-03-01T00:00:00Z"}
    if state in gov().POST_APPROVAL:
        r["review"] = {"reviewer_id": ACTORS["APPROVED"], "decision": "APPROVED", "decision_at_utc": "2026-09-12T10:00:00Z", "verification": VERIF}
    if state in gov().POST_RELEASE:
        r["release_gate_ref"] = "RUN-20260915T100000Z-abcdef12"
    r.update(over)
    return r


def codes(findings):
    return sorted({f["code"] for f in findings})


def check(r, now=NOW):
    return codes(gov().validate_record(r, now))


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


@test
def the_shipped_records_and_risk_register_are_valid_and_contain_no_fabricated_approval():
    g = gov()
    records = load("config/governance/lifecycle-records.json")
    assert g.validate_records_document(records) == [] and g.validate_risk_register(load("config/governance/risk-register.json")) == []
    assert [r["state"] for r in records["records"]] == ["PROPOSED"], "no approval may be fabricated on behalf of a human"
    assert not any("review" in r or "release_gate_ref" in r for r in records["records"])
    risks = load("config/governance/risk-register.json")["risks"]
    assert len(risks) == 9 and all(r["status"] == "OPEN" and r["owner_role"] and r["closure_condition"] for r in risks)
    text = open(os.path.join(ROOT, "config", "governance", "risk-register.json"), encoding="utf-8").read()
    assert not re.search(r"@|\bjohn\b|\bpassword\b|C:\\\\Users", text), "roles only: no people, mail addresses or secrets"


@test
def a_complete_normal_lifecycle_validates_at_every_step_and_only_single_legal_steps_are_allowed():
    g = gov()
    r = rec("PROPOSED")
    assert check(r) == []
    steps = [("REVIEWED", "REV-REVIEWER-02", "2026-09-11T10:00:00Z", None, None),
             ("APPROVED", "REV-APPROVER-03", "2026-09-12T10:00:00Z", {"reviewer_id": "REV-APPROVER-03", "decision": "APPROVED", "decision_at_utc": "2026-09-12T10:00:00Z", "verification": VERIF}, None),
             ("RELEASED", "REV-RELEASER-04", "2026-09-13T10:00:00Z", None, "RUN-20260913T100000Z-abcdef12"),
             ("DEPRECATED", "REV-RELEASER-04", "2026-09-14T10:00:00Z", None, None), ("RETIRED", "REV-RELEASER-04", "2026-09-15T10:00:00Z", None, None)]
    for state, actor, at, review, ref in steps:
        r, findings = g.apply_transition(r, state, actor, at, review=review, release_gate_ref=ref)
        assert findings == [], (state, findings)
    illegal = [("PROPOSED", "APPROVED"), ("PROPOSED", "RELEASED"), ("REVIEWED", "RELEASED"), ("APPROVED", "REVIEWED"), ("RELEASED", "REVIEWED"), ("RELEASED", "RETIRED"),
               ("RETIRED", "RELEASED"), ("RETIRED", "PROPOSED"), ("DEPRECATED", "APPROVED")]
    for frm, to in illegal:
        _, findings = g.apply_transition(rec(frm), to, "REV-OTHER-09", "2026-09-19T10:00:00Z")
        assert "GOV_TRANSITION_ILLEGAL" in codes(findings), (frm, to)
    back, findings = g.apply_transition(rec("REVIEWED"), "PROPOSED", "REV-REVIEWER-02", "2026-09-19T10:00:00Z")
    assert findings == [], "REVIEWED may legally return to PROPOSED"
    bad_state = rec("PROPOSED")
    bad_state["state"] = "SHIPPED"
    assert "GOV_STATE" in check(bad_state)


@test
def segregation_of_duties_the_proposer_never_reviews_or_approves_their_own_change():
    p = ACTORS["PROPOSED"]
    reviewed_by_proposer = rec("REVIEWED")
    reviewed_by_proposer["history"][1]["actor_id"] = p
    assert "GOV_SELF_APPROVAL" in check(reviewed_by_proposer)
    approved_by_proposer = rec("APPROVED")
    approved_by_proposer["history"][2]["actor_id"] = p
    approved_by_proposer["review"]["reviewer_id"] = p
    assert "GOV_SELF_APPROVAL" in check(approved_by_proposer)
    mismatch = rec("APPROVED")
    mismatch["review"]["reviewer_id"] = "REV-SOMEONE-ELSE-99"
    assert "GOV_REVIEWER_NOT_IN_HISTORY" in check(mismatch)
    _, findings = gov().apply_transition(rec("REVIEWED"), "APPROVED", p, "2026-09-19T10:00:00Z",
                                         review={"reviewer_id": p, "decision": "APPROVED", "decision_at_utc": "2026-09-19T10:00:00Z", "verification": VERIF})
    assert "GOV_SELF_APPROVAL" in codes(findings)


@test
def approvals_are_always_structural_and_the_module_never_fabricates_one():
    r = rec("APPROVED")
    r["review"]["verification"] = "AUTHENTICATED"
    assert "GOV_VERIFICATION_OVERSTATED" in check(r)
    no_review = rec("APPROVED")
    del no_review["review"]
    assert "GOV_REVIEW_MISSING" in check(no_review)
    premature = rec("REVIEWED", review={"reviewer_id": "REV-REVIEWER-02", "decision": "APPROVED", "decision_at_utc": NOW, "verification": VERIF})
    assert "GOV_REVIEW_PREMATURE" in check(premature)
    _, findings = gov().apply_transition(rec("REVIEWED"), "APPROVED", "REV-APPROVER-03", "2026-09-19T10:00:00Z")
    assert "GOV_REVIEW_MISSING" in codes(findings), "a transition to APPROVED without a supplied review is refused, never auto-filled"
    src = open(os.path.join(ROOT, "release_readiness", "governance.py"), encoding="utf-8").read()
    assert not re.search(r'["\']decision["\']\s*:\s*["\']APPROVED["\']', src), "the validator must not contain code that builds an approval"
    assert "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED" in src


@test
def a_release_needs_a_gate_reference_and_evidence_and_a_gate_reference_cannot_come_early():
    no_ref = rec("RELEASED")
    del no_ref["release_gate_ref"]
    assert "GOV_RELEASE_GATE_REF_MISSING" in check(no_ref)
    assert "GOV_RELEASE_GATE_REF_MISSING" in check(rec("RELEASED", release_gate_ref="see my email"))
    assert "GOV_EVIDENCE_MISSING_FOR_RELEASE" in check(rec("RELEASED", evidence_refs=[]))
    assert "GOV_RELEASE_REF_PREMATURE" in check(rec("APPROVED", release_gate_ref="RUN-20260915T100000Z-abcdef12"))
    assert check(rec("RELEASED")) == []


@test
def revalidation_dates_expire_and_timestamps_must_be_real_utc():
    assert "GOV_REVALIDATION_OVERDUE" in check(rec("RELEASED", revalidate_by_utc="2026-09-19T00:00:00Z"))
    assert "GOV_REVALIDATION_OVERDUE" in check(rec("APPROVED", revalidate_by_utc="2026-09-19T00:00:00Z"))
    assert "GOV_REVALIDATION_OVERDUE" not in check(rec("PROPOSED", revalidate_by_utc="2026-09-19T00:00:00Z")), "only approved/released knowledge expires"
    for bad in ("2026-13-45T99:00:00Z", "tomorrow", "2026-09-20", "2026-09-20T10:00:00-05:00", 20260920, None):
        assert "GOV_REVALIDATE_TIMESTAMP" in check(rec("RELEASED", revalidate_by_utc=bad)), bad
    out_of_order = rec("REVIEWED")
    out_of_order["history"][1]["at_utc"] = "2026-09-01T00:00:00Z"
    assert "GOV_TRANSITION_ILLEGAL" in check(out_of_order), "history timestamps may not go backwards"


@test
def urgent_changes_still_need_approval_and_a_post_review():
    urgent = {"justification": "Production-impacting defect needs a same-day fix.", "post_review_due_utc": "2026-09-30T00:00:00Z"}
    assert check(rec("APPROVED", change_class="URGENT", urgent=urgent)) == []
    assert "GOV_URGENT_INCOMPLETE" in check(rec("APPROVED", change_class="URGENT"))
    assert "GOV_URGENT_INCOMPLETE" in check(rec("APPROVED", change_class="URGENT", urgent={"justification": "short", "post_review_due_utc": "2026-09-30T00:00:00Z"}))
    assert "GOV_URGENT_POST_REVIEW_OVERDUE" in check(rec("RELEASED", change_class="URGENT", urgent=dict(urgent, post_review_due_utc="2026-09-15T00:00:00Z")))
    assert "GOV_URGENT_POST_REVIEW_OVERDUE" not in check(rec("RELEASED", change_class="URGENT", urgent=dict(urgent, post_review_due_utc="2026-09-15T00:00:00Z", post_review_completed_utc="2026-09-16T00:00:00Z")))
    assert "GOV_URGENT_UNEXPECTED" in check(rec("APPROVED", urgent=urgent))
    skipped = rec("APPROVED", change_class="URGENT", urgent=urgent)
    skipped["history"] = [skipped["history"][0], skipped["history"][2]]
    assert "GOV_TRANSITION_ILLEGAL" in check(skipped), "urgency never allows skipping the review path"


@test
def exceptions_need_a_risk_controls_a_different_approver_and_a_short_expiry():
    exc = {"risk_id": "RSK-003", "scope": "temporary waiver of separate reviewer for a docs-only change", "expires_at_utc": "2026-10-12T10:00:00Z",
           "compensating_controls": ["second person reviews the merge afterwards"], "approver_id": "REV-EXCEPT-05"}
    ok = rec("APPROVED", change_class="EXCEPTION", exception=exc)
    assert check(ok) == []
    assert "GOV_EXCEPTION_INCOMPLETE" in check(rec("APPROVED", change_class="EXCEPTION"))
    for broken in ({"risk_id": "risk-3"}, {"scope": "x"}, {"compensating_controls": []}, {"approver_id": "someone"}, {"expires_at_utc": "never"}):
        assert "GOV_EXCEPTION_INCOMPLETE" in check(rec("APPROVED", change_class="EXCEPTION", exception=dict(exc, **broken))), broken
    assert "GOV_SELF_APPROVAL" in check(rec("APPROVED", change_class="EXCEPTION", exception=dict(exc, approver_id=ACTORS["PROPOSED"])))
    assert "GOV_EXCEPTION_DURATION" in check(rec("APPROVED", change_class="EXCEPTION", exception=dict(exc, expires_at_utc="2027-03-01T00:00:00Z")))
    assert "GOV_EXCEPTION_DURATION" in check(rec("APPROVED", change_class="EXCEPTION", exception=dict(exc, expires_at_utc="2026-09-01T00:00:00Z")))
    assert "GOV_EXCEPTION_EXPIRED" in check(rec("APPROVED", change_class="EXCEPTION", exception=exc), now="2026-11-01T00:00:00Z")
    assert "GOV_EXCEPTION_UNEXPECTED" in check(rec("APPROVED", exception=exc))


@test
def the_record_schema_is_strict_and_ownership_is_by_role_never_by_person():
    for key, value in (("authenticated", True), ("signature", "abc"), ("approved_by", "someone"), ("auto_approve", True)):
        assert "GOV_SCHEMA" in check(rec("PROPOSED", **{key: value})), key
    r = rec("PROPOSED")
    del r["sources"]
    assert "GOV_SCHEMA" in check(r)
    for role in ("john.doe@corp.example", "John Doe", "jdoe", "R", "role_with_underscore", "x" * 60):
        assert "GOV_OWNER_ROLE" in check(rec("PROPOSED", owner_role=role)), role
    assert "GOV_ARTIFACT_TYPE" in check(rec("PROPOSED", artifact_type="database")) and "GOV_SEMVER" in check(rec("PROPOSED", semver="1.0"))
    assert "GOV_ID" in check(rec("PROPOSED", record_id="gov-1")) and "GOV_PROPOSER" in check(rec("PROPOSED", proposer_id="alice"))
    assert "GOV_COMPATIBILITY" in check(rec("PROPOSED", compatibility={"oracle_versions": ["19c"]}))
    assert "GOV_SOURCES" in check(rec("PROPOSED", sources=[]))
    assert check(rec("PROPOSED", record_id="GOV-TEST-001\n")) != [], "a trailing newline must not slip through the identifier pattern"
    g = gov()
    assert "GOV_DUPLICATE_ID" in codes(g.validate_records_document({"schema_version": "1.0.0", "records": [rec(), rec()]}))
    for doc in ({"records": []}, {"schema_version": "2.0.0", "records": []}, {"schema_version": "1.0.0", "records": "x"}, {"schema_version": "1.0.0", "records": [], "extra": 1}, [], None):
        assert codes(g.validate_records_document(doc)) == ["GOV_DOCUMENT_SCHEMA"]


@test
def the_risk_register_requires_owner_role_closure_condition_and_bounded_acceptance():
    g = gov()
    base = copy.deepcopy(load("config/governance/risk-register.json"))
    r0 = base["risks"][0]

    def with_risk(**over):
        doc = copy.deepcopy(base)
        doc["risks"][0] = dict(r0, **over)
        return codes(g.validate_risk_register(doc, NOW))
    assert with_risk() == []
    assert "RISK_TEXT" in with_risk(closure_condition="") and "RISK_TEXT" in with_risk(mitigation="x")
    assert "RISK_OWNER_ROLE" in with_risk(owner_role="alice@example.com") and "RISK_LEVEL" in with_risk(likelihood="CERTAIN") and "RISK_STATUS" in with_risk(status="WONTFIX")
    assert "RISK_ACCEPTANCE_INCOMPLETE" in with_risk(status="ACCEPTED")
    acc = {"accepted_by_role": "security-reviewer", "accepted_at_utc": "2026-09-01T00:00:00Z", "expires_at_utc": "2026-12-01T00:00:00Z"}
    assert with_risk(status="ACCEPTED", acceptance=acc) == []
    assert "RISK_ACCEPTANCE_EXPIRED" in with_risk(status="ACCEPTED", acceptance=dict(acc, expires_at_utc="2026-09-10T00:00:00Z"))
    assert "RISK_ACCEPTANCE_UNEXPECTED" in with_risk(acceptance=acc)
    dup = copy.deepcopy(base)
    dup["risks"].append(dict(r0))
    assert "RISK_ID" in codes(g.validate_risk_register(dup, NOW))
    for doc in ({"schema_version": "1.0.0", "risks": []}, {"schema_version": "1.0.0"}, [], {"schema_version": "1.0.0", "risks": [{"risk_id": "RSK-001"}]}):
        assert g.validate_risk_register(doc, NOW), doc


@test
def the_phase_12_governance_plane_still_reaches_only_pending_human_review_and_never_promotes():
    from change_documentation_knowledge import change as ch
    from change_documentation_knowledge.common import AdvisoryError
    T = "2026-09-20T20:00:00Z"
    stages = {s: {"status": "PASS", "evidence_note": "done"} for s in ch.ESTACK_WORKFLOW_STAGES[:-1]}
    request = {"schema_version": "1.0.0", "change_request_id": "CHG-P14-001", "title": "Add a governance validator", "gap_description": "Lifecycle records are not validated.",
               "artifact_types": ["policy", "documentation"], "proposer_id": "REV-PROPOSER01", "stages": stages,
               "compatibility": {c: "PASS" for c in ch.ESTACK_COMPAT_CHECKS}}
    out = ch.build_estack_change(copy.deepcopy(request), T)
    c = out["change"]
    assert c["governance_state"] == "PENDING_HUMAN_REVIEW" and c["promote_status"] == "HUMAN_ACTION_REQUIRED" and c["execution_status"] == "NOT_EXECUTED_BY_ESTACK"
    assert c["review_status"] != "APPROVED_BY_HUMAN" and "approval_declaration" not in c
    promoted = copy.deepcopy(request)
    promoted["stages"]["PROMOTE"] = {"status": "PASS", "evidence_note": "the engine promoted it"}
    try:
        ch.build_estack_change(promoted, T)
    except AdvisoryError as e:
        assert e.code == "E_TRANSITION_DENIED"
    else:
        raise AssertionError("the engine accepted a PROMOTE that only a human may perform")
    unknown = copy.deepcopy(request)
    unknown["compatibility"]["version_coverage"] = "UNKNOWN"
    blockers = ch.build_estack_change(unknown, T)["change"]["blockers"]
    assert "COMPATIBILITY_VERSION_COVERAGE_UNKNOWN" in blockers, "unknown compatibility is a blocker, never a pass"
    failed = copy.deepcopy(request)
    failed["stages"]["SECURITY_VALIDATION"]["status"] = "FAIL"
    for later in ("REGRESSION_VALIDATION", "DOCUMENT", "HUMAN_REVIEW"):          # PASS stages must form a contiguous prefix
        failed["stages"][later]["status"] = "NOT_RUN"
    assert ch.build_estack_change(failed, T)["change"]["governance_state"] == "RETURNED_TO_PROPOSAL"


@test
def the_governance_documents_name_agents_that_exist_and_roles_that_the_register_uses():
    text = open(os.path.join(ROOT, "docs", "GOVERNANCE_AND_EVOLUTION.md"), encoding="utf-8").read()
    registry_md = open(os.path.join(ROOT, "agents", "REGISTRY.md"), encoding="utf-8").read()
    agents = set(re.findall(r"`([a-z]+(?:-[a-z]+)+)`", text)) & set(re.findall(r"^\| `([a-z0-9-]+)` \|", registry_md, re.M))
    assert {"estack-evolution-architect", "knowledge-curator", "change-advisor", "technical-documentation-manager"} <= agents
    roles = {r["owner_role"] for r in load("config/governance/risk-register.json")["risks"]}
    assert roles and all(role in text for role in roles), "every role that owns a risk appears in the governance document"
    for rel in ("agents/estack-evolution-architect.md", "agents/knowledge-curator/AGENT.md", "agents/change-advisor/AGENT.md"):
        body = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        assert "release_readiness" in body and "GOVERNANCE_AND_EVOLUTION.md" in body, rel


if __name__ == "__main__":
    raise SystemExit(run_all())
