"""
change_documentation_knowledge.documents — documentation factory (Phase 12).

ANALYZE ONCE, DOCUMENT MANY: every document is derived from ONE sanitized RCA view
(schema.adapt_rca_result output) and/or one validated advisory / assessment input. Nothing here
re-analyzes evidence, re-derives a cause, or invents a number: the root-cause state printed by the
technical report, the executive summary and the post-incident review is the same authoritative
`root_cause.completeness` value.

Document contract (JSON): document_id, document_type, audience, schema_version, incident_id /
change_id / assessment_id, source_refs, generated_at_utc, generator_version, content_status
(COMPLETE|PARTIAL), review_status, sanitization_status, redaction_profile, limitations, warnings,
sections[], content_digest. Sections carry an explicit status (PRESENT|NOT_PROVIDED_BY_SOURCE|
MISSING) — a missing required section yields a PARTIAL document with a structured warning; the
generator never substitutes assumed text.

Markdown rendering: stable section order, every value escaped (safety.md_escape), single-line
values, UTF-8, bounded size.
"""
from __future__ import annotations

import re

from .change import DOMAIN_GUIDANCE
from .common import (
    EXECUTION_STATUS_HUMAN_REPORTED, EXECUTION_STATUS_NOT_EXECUTED, GENERATOR_VERSION, SCHEMA_VERSION,
    AdvisoryError, ReviewStatus, SanitizationStatus, content_digest,
)
from .safety import (
    MAX_LIST_ITEMS, audit_strings, clean_text, has_instruction_markers, md_code, md_escape, require_id,
    require_sanitizer,
)
from .schema import id_list, req_dict, req_enum, req_list, req_utc, strict_keys

REDACTION_PROFILE = "phase11-sanitizer+tokenization+signature-allowlist"
DOC_KINDS = {"rca": "INCIDENT_RCA_TECHNICAL_REPORT", "executive": "EXECUTIVE_SUMMARY",
             "change": "CHANGE_ADVISORY_REPORT", "assessment": "ASSESSMENT_REPORT",
             "post-incident": "POST_INCIDENT_REVIEW"}
_AUDIENCE = {"rca": "TECHNICAL", "executive": "EXECUTIVE", "change": "TECHNICAL_AND_CHANGE_REVIEW",
             "assessment": "TECHNICAL", "post-incident": "TECHNICAL_AND_MANAGEMENT"}
_KIND_SUFFIX = {"rca": "RCA", "executive": "EXEC", "change": "CHANGE", "assessment": "ASSESS", "post-incident": "PIR"}

_STATE_STATEMENT = {
    "CONFIRMED": "The RCA engine CONFIRMED a root cause under its evidence rules.",
    "PROBABLE": "A PROBABLE cause was identified; it is NOT confirmed.",
    "INCONCLUSIVE": "The analysis is INCONCLUSIVE: competing explanations remain and no cause is asserted.",
    "INSUFFICIENT_EVIDENCE": "Evidence is INSUFFICIENT to state a cause; no cause is asserted.",
}


def _section(section_id, title, items=None, status="PRESENT", columns=None, rows=None):
    return {"section_id": section_id, "title": title, "status": status,
            "items": items or [], "columns": columns or [], "rows": rows or []}


def _item(text, refs=None, epistemic="observed"):
    return {"text": text, "refs": sorted(refs or []), "epistemic": epistemic}


def _sig_label(ev: dict) -> str:
    if ev["signature_status"] == "CERTIFIED":
        return ev["canonical_signature"]
    return ev["signature_token"] or "none"


def _finalize(doc: dict) -> dict:
    total = sum(len(s["items"]) + len(s["rows"]) for s in doc["sections"])
    if total > 2000:
        raise AdvisoryError("E_OUTPUT_TOO_LARGE")
    audit_strings(doc)
    doc["content_digest"] = content_digest(doc)
    return doc


def _base(kind: str, ref_id: str, view_or_none, generated_at: str, source_refs: dict, content_status: str,
          sections: list, limitations: list, warnings: list, extra: dict = None) -> dict:
    doc = {
        "schema_version": SCHEMA_VERSION, "artifact_type": "document", "document_id": f"DOC-{ref_id}-{_KIND_SUFFIX[kind]}",
        "document_type": DOC_KINDS[kind], "audience": _AUDIENCE[kind], "generated_at_utc": generated_at,
        "generator_version": GENERATOR_VERSION, "sanitization_status": SanitizationStatus.SANITIZED,
        "review_status": ReviewStatus.REVIEW_REQUIRED, "redaction_profile": REDACTION_PROFILE,
        "content_status": content_status, "source_refs": source_refs, "limitations": limitations,
        "warnings": sorted(set(warnings)), "sections": sections,
    }
    doc.update(extra or {})
    return doc


def _source_refs(view: dict, advisory: dict = None) -> dict:
    refs = {"incident_id": view["incident_id"], "rca_id": view["root_cause"]["rca_id"],
            "hypothesis_ids": [h["hypothesis_id"] for h in view["hypotheses"]],
            "evidence_ids": view["evidence_manifest"]["present_refs"],
            "finding_ids": [f["finding_id"] for f in view["findings"]],
            "recommendation_ids": [r["rec_id"] for r in view["recommendations"]]}
    refs["change_ids"] = [c["change_id"] for c in advisory["changes"]] if advisory else []
    return refs


# --- 1. incident / RCA technical report ---------------------------------------------------------

def build_rca_report(view: dict, advisory: dict, generated_at: str) -> dict:
    require_sanitizer()
    rc = view["root_cause"]
    hyps = {h["hypothesis_id"]: h for h in view["hypotheses"]}
    warnings = list(view["warnings"])
    secs = []
    secs.append(_section("context", "Context", [
        _item(f"Incident {view['incident_id']}; target token {view['target_id'] or 'none'}; RCA {rc['rca_id']}"),
        _item(f"Analysis produced by rca_engine (contract {view['rca_contract_version']}, rules {view['rules_version']}). "
              "This document re-formats that result; it does not re-analyze it.", epistemic="observed"),
    ]))
    tl = view["timeline"]
    rows = [[ev["timestamp_utc"] or "UNPARSEABLE", ev["domain"], ev["event_type"], _sig_label(ev),
             ",".join(ev["evidence_ids"]), str(ev["count"]), "DEGRADED" if ev["timeline_degraded"] else "NORMAL"]
            for ev in tl["events"]]
    tl_items = [_item("Times are UTC as normalized by the RCA engine; the source timezone text is not reproduced.")]
    if tl["degraded"]:
        tl_items.append(_item("TIMELINE_CONFIDENCE_DEGRADED: " + "; ".join(tl["degradation_reasons"] or ["reason not provided"]),
                              epistemic="observed"))
        warnings.append("TIMELINE_CONFIDENCE_DEGRADED")
    secs.append(_section("timeline", "Timeline (UTC)", tl_items,
                         status="PRESENT" if rows else "MISSING",
                         columns=["timestamp_utc", "domain", "event_type", "signature", "evidence", "count", "confidence"],
                         rows=rows))
    em = view["evidence_manifest"]
    ev_items = [_item(f"Manifest completeness: {em['completeness']}"),
                _item("Declared evidence: " + (", ".join(em["declared_refs"]) or "none"), em["declared_refs"]),
                _item("Present evidence: " + (", ".join(em["present_refs"]) or "none"), em["present_refs"])]
    if em["missing_refs"]:
        ev_items.append(_item("MISSING evidence references: " + ", ".join(em["missing_refs"]), em["missing_refs"], "not_verified"))
        warnings.append("EVIDENCE_REFERENCES_MISSING")
    secs.append(_section("evidence", "Evidence", ev_items, "PRESENT" if em["present_refs"] else "MISSING"))
    secs.append(_section("findings", "Findings (observed)", [
        _item(f"{f['finding_id']}: {f['event_type']} in {f['domain']} at {f['timestamp_utc'] or 'unparseable time'}"
              f" (signature {_sig_label(f)})", f["evidence_ids"], "observed") for f in view["findings"]],
        "PRESENT" if view["findings"] else "MISSING"))
    hy_items = []
    for h in view["hypotheses"]:
        hy_items.append(_item(
            f"{h['hypothesis_id']} [{h['status']}, confidence {h['confidence']}] {h['statement']}",
            h["supporting_evidence_ids"] + h["contradicting_evidence_ids"], "inferred"))
        hy_items.append(_item("  Supporting evidence: " + (", ".join(h["supporting_evidence_ids"]) or "none")
                              + "; contradicting evidence: " + (", ".join(h["contradicting_evidence_ids"]) or "none")
                              + f"; unresolved critical contradiction: {'YES' if h['unresolved_critical_contradiction'] else 'no'}",
                              h["supporting_evidence_ids"] + h["contradicting_evidence_ids"], "observed"))
        if h["missing_evidence"]:
            hy_items.append(_item("  Missing evidence: " + "; ".join(h["missing_evidence"]), [], "not_verified"))
    secs.append(_section("hypotheses", "Hypotheses (for and against)", hy_items, "PRESENT" if hy_items else "MISSING"))
    rc_items = [_item(f"Root cause state (authoritative, from rca_engine): {rc['completeness']}", [rc["rca_id"]], "inferred"),
                _item(_STATE_STATEMENT[rc["completeness"]], [], "inferred")]
    for hid in rc["confirmed_hypothesis_ids"]:
        h = hyps[hid]
        rc_items.append(_item(f"Confirmed hypothesis {hid}: {h['statement']}", [hid] + h["supporting_evidence_ids"], "inferred"))
        rc_items.append(_item(f"Confidence {h['confidence']} justified by {h['independent_source_count']} independent evidence source(s); "
                              f"temporal proof: {'yes' if h['temporal_proof'] else 'no'}. No additional justification is invented.", [hid], "inferred"))
        for step in h["causal_chain"]:
            rc_items.append(_item("  Causal chain: " + step, [hid], "inferred"))
    for hid in rc["competing_hypothesis_ids"]:
        rc_items.append(_item(f"Competing hypothesis remains open: {hid}", [hid], "unknown"))
    secs.append(_section("root_cause", "Root cause", rc_items))
    secs.append(_section("contributing_factors", "Contributing factors",
                         [_item("The RCA result does not provide contributing factors; none are inferred here.", [], "not_verified")],
                         "NOT_PROVIDED_BY_SOURCE"))
    secs.append(_section("impact", "Impact", [_item("Domains involved: " + (", ".join(view["domains_involved"]) or "none reported")
                                                    + ". Business impact and duration are not provided by the RCA result and are not estimated.", [], "not_verified")],
                         "NOT_PROVIDED_BY_SOURCE"))
    rec_items = [_item(f"{r['rec_id']}: {r['action_summary']} (proposal; execution status {r['execution_status']})",
                       [r["rec_id"]] + r["hypothesis_refs"], "proposed") for r in view["recommendations"]]
    if advisory:
        for c in advisory["changes"]:
            rec_items.append(_item(f"{c['change_id']}: change proposal {c['status']}, readiness {c['readiness']} "
                                   f"(execution {c['execution_status']})", [c["change_id"]] + c["recommendation_refs"], "proposed"))
    secs.append(_section("recommendations_and_changes", "Recommendations and change proposals", rec_items,
                         "PRESENT" if rec_items else "NOT_PROVIDED_BY_SOURCE"))
    secs.append(_section("limitations", "Limitations", [_item(x, [], "unknown") for x in view["limitations"]]
                         + [_item("A recommendation is not an authorization; a change proposal is not an approval or an execution.", [], "unknown")]))
    required = {"context", "timeline", "evidence", "findings", "hypotheses", "root_cause", "limitations"}
    missing_required = sorted(s["section_id"] for s in secs if s["section_id"] in required and s["status"] != "PRESENT")
    if missing_required:
        warnings.append("REQUIRED_SECTIONS_MISSING")
    content_status = "PARTIAL" if missing_required or em["completeness"] != "COMPLETE" else "COMPLETE"
    doc = _base("rca", view["incident_id"], view, generated_at, _source_refs(view, advisory), content_status, secs,
                view["limitations"], warnings, {"incident_id": view["incident_id"], "root_cause_state": rc["completeness"]})
    return _finalize(doc)


# --- 2. executive summary -----------------------------------------------------------------------

def build_executive_summary(view: dict, advisory: dict, generated_at: str) -> dict:
    require_sanitizer()
    rc = view["root_cause"]
    hyps = {h["hypothesis_id"]: h for h in view["hypotheses"]}
    warnings = list(view["warnings"])
    head = [_item(f"Root cause status: {rc['completeness']}. {_STATE_STATEMENT[rc['completeness']]}", [rc["rca_id"]], "inferred")]
    for hid in rc["confirmed_hypothesis_ids"]:
        head.append(_item("Confirmed cause: " + hyps[hid]["statement"], [hid], "inferred"))
    unc = []
    open_h = [h for h in view["hypotheses"] if h["status"] not in ("CONFIRMED", "REJECTED")]
    unc.append(_item(f"{len(open_h)} hypothesis(es) are not confirmed or rejected.", [h["hypothesis_id"] for h in open_h], "unknown"))
    contr = [h for h in view["hypotheses"] if h["contradicting_evidence_ids"]]
    for h in contr:
        unc.append(_item(f"Contradicting evidence exists for {h['hypothesis_id']}"
                         + (" and is UNRESOLVED." if h["unresolved_critical_contradiction"] else "."),
                         h["contradicting_evidence_ids"], "observed"))
    if view["evidence_manifest"]["completeness"] != "COMPLETE":
        unc.append(_item("Some declared evidence is missing: " + ", ".join(view["evidence_manifest"]["missing_refs"]),
                         view["evidence_manifest"]["missing_refs"], "not_verified"))
    if view["timeline"]["degraded"]:
        unc.append(_item("Timeline confidence is degraded (timestamp ambiguity or clock skew).", [], "observed"))
    risk = []
    if advisory:
        for c in advisory["changes"]:
            levels = ", ".join(f"{r['dimension']}={r['level']}" for r in c["risk_factors"])
            risk.append(_item(f"{c['change_id']} readiness {c['readiness']}; risk factors: {levels}. No numeric score is computed.",
                              [c["change_id"]], "inferred"))
    secs = [_section("headline", "Headline", head),
            _section("uncertainty", "Uncertainty and open questions", unc),
            _section("risk", "Risk of proposed actions", risk or [_item("No change proposal is available; risk of actions is not assessed.", [], "not_verified")],
                     "PRESENT" if risk else "NOT_PROVIDED_BY_SOURCE"),
            _section("next_steps", "Proposed next steps (proposals for human decision)",
                     [_item(r["action_summary"], [r["rec_id"]], "proposed") for r in view["recommendations"]]
                     or [_item("No recommendation available.", [], "not_verified")]),
            _section("limitations", "Limitations", [_item(x, [], "unknown") for x in view["limitations"]]
                     + [_item("This summary introduces no conclusion beyond the RCA state above.", [], "unknown")])]
    doc = _base("executive", view["incident_id"], view, generated_at, _source_refs(view, advisory),
                "COMPLETE", secs, view["limitations"], warnings,
                {"incident_id": view["incident_id"], "root_cause_state": rc["completeness"]})
    return _finalize(doc)


# --- 3. change advisory report (from a validated advisory) --------------------------------------

def validate_advisory(adv) -> dict:
    """Integrity + contract checks for an advisory read from disk. The advisory is OUR artifact: it must
    verify against its own digest, keep the immutable execution status, and pass the output audit."""
    require_sanitizer()
    adv = req_dict(adv, "advisory")
    if adv.get("artifact_type") != "change_advisory":
        raise AdvisoryError("E_INPUT_INVALID", "advisory.artifact_type")
    if adv.get("schema_version") != SCHEMA_VERSION:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "advisory.schema_version")
    digest = adv.get("content_digest")
    if not (isinstance(digest, str) and re.match(r'^[0-9a-f]{64}$', digest)) or content_digest(adv) != digest:
        raise AdvisoryError("E_INPUT_INVALID", "advisory.content_digest")
    if adv.get("execution_status") != EXECUTION_STATUS_NOT_EXECUTED:
        raise AdvisoryError("E_INPUT_INVALID", "advisory.execution_status")
    require_id(adv.get("advisory_id"), ("ADV",), "advisory.advisory_id")
    for c in req_list(adv.get("changes"), "advisory.changes", 100):
        c = req_dict(c, "advisory.changes")
        require_id(c.get("change_id"), ("CHG",), "change.change_id")
        if c.get("execution_status") != EXECUTION_STATUS_NOT_EXECUTED:
            raise AdvisoryError("E_INPUT_INVALID", "change.execution_status")
        for s in req_list(c.get("proposed_manual_steps"), "change.proposed_manual_steps", 100):
            if req_dict(s, "change.step").get("execution_status") != EXECUTION_STATUS_NOT_EXECUTED:
                raise AdvisoryError("E_INPUT_INVALID", "change.step.execution_status")
    audit_strings(adv)
    return adv


def build_change_report(adv: dict, generated_at: str) -> dict:
    adv = validate_advisory(adv)
    warnings = list(adv.get("warnings", []))
    secs = [_section("summary", "Summary", [
        _item(f"Advisory {adv['advisory_id']} for incident {adv['source_refs']['incident_id']}; RCA state {adv['rca_state']['completeness']} (authoritative).",
              [adv["advisory_id"]], "inferred"),
        _item(f"Readiness: {adv['readiness']}. Execution status: {adv['execution_status']}.", [], "observed")])]
    for c in adv["changes"]:
        pre = [s for s in c["proposed_manual_steps"] if s["phase"] == "PRECHECK"]
        act = [s for s in c["proposed_manual_steps"] if s["phase"] == "MANUAL_ACTION"]
        post = [s for s in c["proposed_manual_steps"] if s["phase"] == "POSTCHECK"]
        secs.append(_section(f"{c['change_id']}", f"Change {c['change_id']} ({c['status']})", [
            _item("Objective: " + c["objective"], c["recommendation_refs"], "proposed"),
            _item("Prerequisites: " + "; ".join(s["text"] for s in pre), c["evidence_refs"], "proposed"),
            _item("Manual actions (text for a human administrator; not executed): " + "; ".join(s["text"] for s in act), [], "proposed"),
            _item("Validation: " + "; ".join(c["validation_plan"]["checks"] or ["MISSING"]), [], "proposed"),
            _item(f"Rollback ({c['rollback_plan']['status']}, reversibility {c['reversibility']}): " + " ".join(c["rollback_plan"]["steps"]), [], "proposed"),
            _item("Impact: " + c["impact"]["affected_scope"], [], "inferred"),
            _item("Risk factors: " + "; ".join(f"{r['dimension']}={r['level']}" for r in c["risk_factors"]), [], "inferred"),
            _item("Gates: " + "; ".join(f"{g.replace('_gate', '')}={c[g]['status']}" for g in ("capability_gate", "license_gate", "privilege_gate", "change_window_gate")), [], "observed"),
            _item("Blockers: " + (", ".join(c["blockers"]) or "none") + "; review reasons: " + (", ".join(c["review_reasons"]) or "none"), [], "observed"),
            _item("Approval: " + (f"declared {c['approval_declaration']['decision']} by {c['approval_declaration']['reviewer_id']} "
                                  f"(identity not verified)" if c.get("approval_declaration") else "PENDING — no external authorization record."), [], "human_reported" if c.get("approval_declaration") else "unknown")]))
    secs.append(_section("limitations", "Limitations", [_item(x, [], "unknown") for x in adv["limitations"]]))
    doc = _base("change", adv["source_refs"]["incident_id"], None, generated_at,
                {"incident_id": adv["source_refs"]["incident_id"], "rca_id": adv["source_refs"]["rca_id"],
                 "advisory_id": adv["advisory_id"], "change_ids": [c["change_id"] for c in adv["changes"]],
                 "recommendation_ids": adv["source_refs"]["recommendation_ids"]},
                "COMPLETE" if adv["changes"] else "PARTIAL", secs, adv["limitations"], warnings,
                {"incident_id": adv["source_refs"]["incident_id"], "root_cause_state": adv["rca_state"]["completeness"],
                 "advisory_digest": adv["content_digest"]})
    if not adv["changes"]:
        doc["warnings"] = sorted(set(doc["warnings"]) | {"NO_CHANGE_PROPOSALS_IN_ADVISORY"})
    return _finalize(doc)


# --- 4. assessment / healthcheck -----------------------------------------------------------------

_SEVERITIES = ("INFO", "LOW", "MEDIUM", "HIGH", "CRITICAL")
_COVERAGE = ("SUPPORTED", "UNSUPPORTED", "UNKNOWN")
_ENTITLEMENT = ("ENTITLED", "NOT_ENTITLED", "UNKNOWN")


def parse_assessment(raw) -> dict:
    require_sanitizer()
    a = req_dict(raw, "assessment")
    strict_keys(a, {"schema_version", "assessment_id", "title", "target", "findings", "coverage"},
                {"license_notes", "exceptions", "pending"}, "assessment")
    if a["schema_version"] != SCHEMA_VERSION:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "assessment.schema_version")
    aid = require_id(a["assessment_id"], ("DOC", "INC", "CHG", "ADV"), "assessment.assessment_id")
    target = req_dict(a["target"], "assessment.target")
    strict_keys(target, {"oracle_version"}, {"platform", "architecture"}, "assessment.target")
    findings = []
    for f in req_list(a["findings"], "assessment.findings", 200):
        f = req_dict(f, "assessment.findings")
        strict_keys(f, {"finding_id", "domain", "title", "severity", "evidence_ids"}, {"status"}, "assessment.findings")
        from rca_engine.common import ALLOWED_DOMAINS
        if f["domain"] not in ALLOWED_DOMAINS:
            raise AdvisoryError("E_INPUT_INVALID", "assessment.findings.domain")
        findings.append({"finding_id": require_id(f["finding_id"], ("FND",), "finding.finding_id"), "domain": f["domain"],
                         "title": clean_text(f["title"], 160, "finding.title"),
                         "severity": req_enum(f["severity"], _SEVERITIES, "finding.severity"),
                         "evidence_ids": id_list(f["evidence_ids"], ("EVD",), "finding.evidence_ids", 50),
                         "status": req_enum(f.get("status", "OBSERVED"), ("OBSERVED", "NOT_VERIFIED"), "finding.status")})
    if len({f["finding_id"] for f in findings}) != len(findings):
        raise AdvisoryError("E_REFERENCE", "assessment.findings")
    cov = []
    for c in req_list(a["coverage"], "assessment.coverage", 100):
        c = req_dict(c, "assessment.coverage")
        strict_keys(c, {"area", "status"}, {"note"}, "assessment.coverage")
        cov.append({"area": clean_text(c["area"], 80, "coverage.area"), "status": req_enum(c["status"], _COVERAGE, "coverage.status"),
                    "note": clean_text(c.get("note", ""), 200, "coverage.note")})
    lic = []
    for l in req_list(a.get("license_notes", []), "assessment.license_notes", 50):
        l = req_dict(l, "assessment.license_notes")
        strict_keys(l, {"feature", "status"}, set(), "assessment.license_notes")
        lic.append({"feature": clean_text(l["feature"], 80, "license.feature"),
                    "status": req_enum(l["status"], _ENTITLEMENT, "license.status")})
    return {"assessment_id": aid, "title": clean_text(a["title"], 120, "assessment.title"),
            "oracle_version": clean_text(str(target["oracle_version"]), 20, "assessment.target"),
            "findings": sorted(findings, key=lambda f: (f["domain"], _SEVERITIES.index(f["severity"]) * -1, f["finding_id"])),
            "coverage": sorted(cov, key=lambda c: c["area"]), "license_notes": sorted(lic, key=lambda x: x["feature"]),
            "exceptions": [clean_text(x, 200, "assessment.exceptions") for x in req_list(a.get("exceptions", []), "assessment.exceptions", 50)],
            "pending": [clean_text(x, 200, "assessment.pending") for x in req_list(a.get("pending", []), "assessment.pending", 50)]}


def build_assessment_report(raw, generated_at: str) -> dict:
    a = parse_assessment(raw)
    counts = {s: sum(1 for c in a["coverage"] if c["status"] == s) for s in _COVERAGE}
    warnings = []
    if counts["UNKNOWN"]:
        warnings.append("COVERAGE_UNKNOWN_PRESENT")
    if not a["findings"]:
        warnings.append("NO_FINDINGS_PROVIDED")
    secs = [
        _section("scope", "Scope", [_item(f"Assessment {a['assessment_id']}: {a['title']}. Oracle version declared: {a['oracle_version']}. "
                                          "Coverage for other versions is not implied.", [], "human_reported")]),
        _section("coverage", "Coverage (SUPPORTED / UNSUPPORTED / UNKNOWN)",
                 [_item(f"SUPPORTED={counts['SUPPORTED']}, UNSUPPORTED={counts['UNSUPPORTED']}, UNKNOWN={counts['UNKNOWN']}. UNKNOWN is not treated as supported.", [], "observed")],
                 columns=["area", "status", "note"], rows=[[c["area"], c["status"], c["note"]] for c in a["coverage"]]),
        _section("findings", "Findings", [_item(f"{f['finding_id']} [{f['severity']}] ({f['domain']}) {f['title']}", f["evidence_ids"],
                                                "observed" if f["status"] == "OBSERVED" else "not_verified") for f in a["findings"]],
                 "PRESENT" if a["findings"] else "MISSING"),
        _section("licensing", "Licensing", [_item(f"{l['feature']}: {l['status']}", [], "unknown" if l["status"] == "UNKNOWN" else "human_reported")
                                            for l in a["license_notes"]] or [_item("No licensing information provided; entitlement is not assumed.", [], "unknown")]),
        _section("exceptions", "Exceptions", [_item(x, [], "human_reported") for x in a["exceptions"]]
                 or [_item("None reported.", [], "not_verified")]),
        _section("pending", "Pending items", [_item(x, [], "proposed") for x in a["pending"]] or [_item("None reported.", [], "not_verified")]),
        _section("limitations", "Limitations", [_item("Findings are reused as provided; nothing is re-analyzed or scored.", [], "unknown")]),
    ]
    status = "COMPLETE" if a["findings"] and a["coverage"] else "PARTIAL"
    doc = _base("assessment", a["assessment_id"], None, generated_at,
                {"assessment_id": a["assessment_id"], "finding_ids": [f["finding_id"] for f in a["findings"]],
                 "evidence_ids": sorted({e for f in a["findings"] for e in f["evidence_ids"]})},
                status, secs, ["Findings are reused as provided; nothing is re-analyzed or scored."], warnings,
                {"assessment_id": a["assessment_id"]})
    return _finalize(doc)


# --- 5. post-incident review ---------------------------------------------------------------------

def parse_review_input(raw) -> dict:
    require_sanitizer()
    if raw is None:
        return {"reported_actions": [], "follow_ups": [], "lessons": []}
    r = req_dict(raw, "review")
    strict_keys(r, {"schema_version"}, {"reported_actions", "follow_ups", "lessons"}, "review")
    if r["schema_version"] != SCHEMA_VERSION:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "review.schema_version")
    acts = []
    for x in req_list(r.get("reported_actions", []), "review.reported_actions", 50):
        x = req_dict(x, "review.reported_actions")
        strict_keys(x, {"text", "reported_by", "reported_at_utc"}, set(), "review.reported_actions")
        acts.append({"text": clean_text(x["text"], 240, "review.action"), "reported_by": require_id(x["reported_by"], ("REV",), "review.reported_by"),
                     "reported_at_utc": req_utc(x["reported_at_utc"], "review.reported_at_utc")})
    return {"reported_actions": acts,
            "follow_ups": [clean_text(x, 240, "review.follow_ups") for x in req_list(r.get("follow_ups", []), "review.follow_ups", 50)],
            "lessons": [clean_text(x, 240, "review.lessons") for x in req_list(r.get("lessons", []), "review.lessons", 50)]}


def build_post_incident_review(view: dict, review_raw, generated_at: str) -> dict:
    rv = parse_review_input(review_raw)
    rc = view["root_cause"]
    warnings = list(view["warnings"])
    if not rv["reported_actions"] and not rv["follow_ups"] and not rv["lessons"]:
        warnings.append("REVIEW_INPUT_NOT_PROVIDED")
    secs = [
        _section("summary", "Summary", [_item(f"Incident {view['incident_id']}: root cause status {rc['completeness']} (authoritative). "
                                              + _STATE_STATEMENT[rc["completeness"]], [rc["rca_id"]], "inferred")]),
        _section("reported_actions", "Actions reported by people (not verified)",
                 [_item(f"{a['text']} (reported by {a['reported_by']} at {a['reported_at_utc']}; status {EXECUTION_STATUS_HUMAN_REPORTED})",
                        [], "human_reported") for a in rv["reported_actions"]] or [_item("None reported.", [], "not_verified")],
                 "PRESENT" if rv["reported_actions"] else "NOT_PROVIDED_BY_SOURCE"),
        _section("proposed_actions", "Actions proposed by the analysis (not executed)",
                 [_item(f"{r['rec_id']}: {r['action_summary']} (execution status {r['execution_status']})", [r["rec_id"]], "proposed")
                  for r in view["recommendations"]] or [_item("None.", [], "not_verified")]),
        _section("follow_ups", "Follow-ups", [_item(x, [], "proposed") for x in rv["follow_ups"]] or [_item("None provided.", [], "not_verified")],
                 "PRESENT" if rv["follow_ups"] else "NOT_PROVIDED_BY_SOURCE"),
        _section("lessons", "Lessons learned (proposals; blameless — no individual is assessed)",
                 [_item(x, [], "proposed") for x in rv["lessons"]] or [_item("None provided.", [], "not_verified")],
                 "PRESENT" if rv["lessons"] else "NOT_PROVIDED_BY_SOURCE"),
        _section("metrics", "Metrics", [_item("MTTR, SLA and duration are NOT computed: the sources do not provide validated values, and none are invented.", [], "not_verified")],
                 "NOT_PROVIDED_BY_SOURCE"),
        _section("limitations", "Limitations", [_item(x, [], "unknown") for x in view["limitations"]]),
    ]
    doc = _base("post-incident", view["incident_id"], view, generated_at, _source_refs(view), "PARTIAL" if any(
        w in warnings for w in ("REVIEW_INPUT_NOT_PROVIDED",)) else "COMPLETE", secs, view["limitations"], warnings,
        {"incident_id": view["incident_id"], "root_cause_state": rc["completeness"]})
    return _finalize(doc)


# --- Markdown rendering --------------------------------------------------------------------------

def render_document_md(doc: dict) -> str:
    L = [f"# {md_escape(doc['document_type'])} {md_code(doc['document_id'])}", ""]
    L.append("| Field | Value |")
    L.append("|---|---|")
    for k in ("audience", "content_status", "review_status", "sanitization_status", "redaction_profile",
              "generated_at_utc", "generator_version", "schema_version"):
        L.append(f"| {k} | {md_escape(doc[k])} |")
    if "root_cause_state" in doc:
        L.append(f"| root_cause_state | {md_escape(doc['root_cause_state'])} |")
    L.append(f"| content_digest | {doc['content_digest']} |")
    L.append("")
    if doc["warnings"]:
        L.append("**Warnings:** " + ", ".join(md_code(w) for w in doc["warnings"]))
        L.append("")
    L.append("**Source references:** " + "; ".join(
        f"{md_escape(k)}: " + (", ".join(md_code(x) for x in v) if isinstance(v, list) else md_code(v))
        for k, v in sorted(doc["source_refs"].items()) if v))
    L.append("")
    for s in doc["sections"]:
        L.append(f"## {md_escape(s['title'])}")
        if s["status"] != "PRESENT":
            L.append(f"_Section status: {md_escape(s['status'])}_")
        L.append("")
        if s["columns"]:
            L.append("| " + " | ".join(md_escape(c) for c in s["columns"]) + " |")
            L.append("|" + "---|" * len(s["columns"]))
            for row in s["rows"]:
                L.append("| " + " | ".join(md_escape(c) for c in row) + " |")
            L.append("")
        for it in s["items"]:
            refs = (" — refs: " + ", ".join(md_code(r) for r in it["refs"])) if it["refs"] else ""
            L.append(f"- {md_escape(it['text'].strip())} _[{md_escape(it['epistemic'])}]_{refs}")
        L.append("")
    return "\n".join(L)
