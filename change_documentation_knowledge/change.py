"""
change_documentation_knowledge.change — deterministic change-advisory engine (Phase 12, plane A) and
e-stack evolution governance (plane B).

PLANE A (OPERATIONAL_MANUAL): sanitized RCA view (schema.adapt_rca_result) + optional change
context -> `change_advisory.json` / `change_advisory.md`. Every proposed step is TEXT for an
authorized human administrator. Nothing here executes, schedules, approves or promotes anything:
  * `execution_status` is the constant NOT_EXECUTED_BY_ESTACK on every change;
  * `status` is never APPROVED_BY_HUMAN unless a matching EXTERNAL authorization record is supplied
    (authorization.verify_authorization) — and even then identity is NOT verified;
  * UNKNOWN gates block readiness (UNKNOWN != NOT_APPLICABLE); compatibility and licensing are never
    inferred from an Oracle version or a default;
  * no opaque numeric risk score — only named, explainable risk factors with their criterion.

PLANE B (ESTACK_DEVELOPMENT): governance state machine for changes to the e-stack repository itself
(`/change` workflow). The engine can only *report* the stage a request is at; PROMOTE is always a
human action (`promote_status: HUMAN_ACTION_REQUIRED`) and a proposer can never be its own reviewer.
"""
from __future__ import annotations

import re

from .authorization import verify_authorization
from .common import (
    EXECUTION_STATUS_HUMAN_REPORTED, EXECUTION_STATUS_NOT_EXECUTED, GENERATOR_VERSION, SCHEMA_VERSION,
    AdvisoryError, ChangeStatus, ChangeType, GateStatus, Readiness, ReviewStatus, SanitizationStatus,
    content_digest, is_utc_timestamp,
)
from .safety import (
    clean_text, has_executable_content, has_instruction_markers, md_code, md_escape, require_id,
    require_sanitizer,
)
from .schema import (
    id_list, req_bool, req_dict, req_enum, req_list, req_utc, strict_keys, text_list,
)

_VERSION_SHAPE = re.compile(r'^(?:[0-9]{1,2}(?:\.[0-9]{1,2}){0,4}|9i|10g|11g|11gR2|12c|12cR1|12cR2|18c|19c|21c|23ai|23c)$')
_RU_SHAPE = re.compile(r'^[A-Za-z0-9._ -]{1,40}$')
_PLATFORM_SHAPE = re.compile(r'^[A-Za-z0-9._ /-]{1,60}$')
_HAZARD = re.compile(r'(?i)\b(restart|reboot|bounce|failover|switchover|relocat\w*|kill\w*|shut\s*down|drop\w*|delete\w*|'
                     r'resiz\w*|rebalanc\w*|reconfigur\w*|rewrite|purge\w*|detach\w*|disable\w*)\b')

GATES = ("capability", "license", "privilege", "change_window")

# Domain guidance (text only). Conservative: guidance describes what a human must consider; it never
# asserts compatibility, entitlement or privilege — those are gates resolved by the human/context.
DOMAIN_GUIDANCE = {
    "oracle": {"components": ["Oracle instance / database configuration"], "breadth": "MEDIUM",
               "blast": "The affected database instance(s); scope must be stated by the reviewer.",
               "reversibility": "PARTIAL",
               "rollback": ["Restore the previously recorded configuration value or state (captured in the pre-change step) using the site's approved procedure.",
                            "Confirm instance health and an error-free alert log after restoring."],
               "license_dependent": False},
    "os": {"components": ["Operating system configuration of the database host"], "breadth": "MEDIUM",
           "blast": "The host and every Oracle instance sharing the affected OS limit or resource.",
           "reversibility": "REVERSIBLE_IF_PRIOR_VALUE_RECORDED",
           "rollback": ["Restore the prior OS setting recorded before the change, following the platform team's procedure.",
                        "Re-measure the affected resource and confirm the database host is stable."],
           "license_dependent": False},
    "rac": {"components": ["Grid Infrastructure / RAC cluster resources"], "breadth": "HIGH",
            "blast": "Cluster-wide: more than one node or instance may be affected; do not assume a single-node scope.",
            "reversibility": "PARTIAL",
            "rollback": ["Revert node by node in the reverse order of the applied change, keeping cluster quorum in mind.",
                         "Confirm all cluster resources and services are in their expected state on every node."],
            "license_dependent": False},
    "asm": {"components": ["ASM instance / disk groups / storage paths"], "breadth": "HIGH",
            "blast": "Every database using the affected disk group; rebalance activity may extend the impact window.",
            "reversibility": "PARTIAL_OR_IRREVERSIBLE_UNKNOWN",
            "rollback": ["Some storage operations may not be reversible; confirm reversibility with the storage owner before proceeding.",
                         "If reversible, restore the prior configuration and confirm disk group health and rebalance completion."],
            "license_dependent": False},
    "dataguard": {"components": ["Data Guard configuration (primary and standby databases)"], "breadth": "HIGH",
                  "blast": "Primary and standby databases; transport/apply and role behavior may be affected. Do not assume symmetry between sites.",
                  "reversibility": "PARTIAL",
                  "rollback": ["Restore the previous transport/apply configuration recorded before the change on each affected database.",
                               "Confirm transport and apply status and that no gap was introduced."],
                  "license_dependent": True,
                  "license_note": "Some Data Guard capabilities (for example Active Data Guard features) require a separate entitlement; entitlement must be confirmed, never assumed."},
    "multitenant": {"components": ["CDB / PDB configuration"], "breadth": "MEDIUM",
                    "blast": "The container database or the named PDB(s); the reviewer must state whether the scope is CDB-wide or per-PDB.",
                    "reversibility": "PARTIAL",
                    "rollback": ["Restore the prior CDB/PDB setting recorded before the change, in the same container scope.",
                                 "Confirm PDB open mode and services after restoring."],
                    "license_dependent": False},
    "rman": {"components": ["Backup and recovery configuration (RMAN, FRA, retention)"], "breadth": "MEDIUM",
             "blast": "Backup schedule and recoverability window; overlap with running backups must be excluded.",
             "reversibility": "REVERSIBLE_IF_PRIOR_VALUE_RECORDED",
             "rollback": ["Restore the previously recorded backup configuration values.",
                          "Confirm the next backup completes and recoverability is preserved."],
             "license_dependent": False},
    "network": {"components": ["Listener / SCAN / name resolution / network path"], "breadth": "HIGH",
                "blast": "New and possibly existing client connections to the affected service endpoints.",
                "reversibility": "REVERSIBLE_IF_PRIOR_VALUE_RECORDED",
                "rollback": ["Restore the prior listener or network configuration recorded before the change.",
                             "Confirm that new client connections succeed through every affected endpoint."],
                "license_dependent": False},
    "security": {"components": ["Security posture (accounts, audit, encryption, privileges)"], "breadth": "HIGH",
                 "blast": "Access paths and audit coverage for the affected accounts or components; compliance evidence may be affected.",
                 "reversibility": "PARTIAL",
                 "rollback": ["Restore the previously recorded security setting through the security team's approved procedure.",
                              "Confirm audit coverage and access for legitimate users is intact."],
                 "license_dependent": False},
    "capacity": {"components": ["Capacity of storage, memory, CPU or tablespace resources"], "breadth": "MEDIUM",
                 "blast": "The resource pool being resized and the workloads that depend on it.",
                 "reversibility": "PARTIAL",
                 "rollback": ["A capacity increase is usually additive; if the increase must be undone, follow the storage/platform owner's procedure and confirm no dependent object is affected.",
                              "Re-measure utilization after any rollback."],
                 "license_dependent": False},
    "performance": {"components": ["Instance or SQL performance configuration"], "breadth": "MEDIUM",
                    "blast": "Workloads on the affected instance; a tuning change can shift behavior for unrelated statements.",
                    "reversibility": "REVERSIBLE_IF_PRIOR_VALUE_RECORDED",
                    "rollback": ["Restore the previously recorded setting or plan baseline configuration.",
                                 "Compare the same performance indicators before and after the rollback."],
                    "license_dependent": True,
                    "license_note": "Use of AWR/ASH/ADDM and some tuning features requires a licensed management pack; entitlement must be confirmed, never assumed."},
}

ESTACK_WORKFLOW_STAGES = (
    "DETECT_GAP", "CHANGE_REQUEST", "GAP_ANALYSIS", "IMPACT_ANALYSIS", "PROPOSAL", "IMPLEMENT", "TEST",
    "SECURITY_VALIDATION", "REGRESSION_VALIDATION", "DOCUMENT", "HUMAN_REVIEW", "PROMOTE",
)
ESTACK_ARTIFACT_TYPES = frozenset({"skill", "agent", "query", "workflow", "policy", "knowledge", "compatibility",
                                   "documentation", "security", "rule", "schema", "template"})
ESTACK_COMPAT_CHECKS = ("version_coverage", "query_contract", "dictionary_columns", "architecture",
                        "cost_and_license", "test_coverage")
_STAGE_STATUS = frozenset({"PASS", "FAIL", "NOT_RUN"})


# --- context -------------------------------------------------------------------------------------

def parse_change_context(ctx) -> dict:
    """Optional operational context. Absent/None => every gate UNKNOWN (never assumed PASS or N/A)."""
    require_sanitizer()
    empty = {"target": {"oracle_version": None, "release_update": None, "platform": None,
                        "architecture": {"cdb": None, "rac": None, "dataguard": None, "asm": None}},
             "gates": {g: {"status": GateStatus.UNKNOWN, "basis": "No context supplied; not assumed."} for g in GATES},
             "human_authorizations": [], "execution_reports": [], "proposer_ids": []}
    if ctx is None:
        return empty
    ctx = req_dict(ctx, "context")
    strict_keys(ctx, set(), {"schema_version", "target", "gates", "human_authorizations", "execution_reports",
                             "proposer_ids"}, "context")
    if ctx.get("schema_version", SCHEMA_VERSION) != SCHEMA_VERSION:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "context.schema_version")
    out = empty
    if "target" in ctx:
        t = req_dict(ctx["target"], "context.target")
        strict_keys(t, set(), {"oracle_version", "release_update", "platform", "architecture"}, "context.target")
        v = t.get("oracle_version")
        if v is not None:
            if not (isinstance(v, str) and _VERSION_SHAPE.match(v)):
                raise AdvisoryError("E_INPUT_INVALID", "context.target.oracle_version")
            out["target"]["oracle_version"] = v
        for key, shape in (("release_update", _RU_SHAPE), ("platform", _PLATFORM_SHAPE)):
            if t.get(key) is not None:
                if not (isinstance(t[key], str) and shape.match(t[key])):
                    raise AdvisoryError("E_INPUT_INVALID", f"context.target.{key}")
                out["target"][key] = clean_text(t[key], 60, key)
        if "architecture" in t:
            a = req_dict(t["architecture"], "context.target.architecture")
            strict_keys(a, set(), {"cdb", "rac", "dataguard", "asm"}, "context.target.architecture")
            for k, val in a.items():
                if val is not None:
                    req_bool(val, "context.target.architecture")
                out["target"]["architecture"][k] = val
    if "gates" in ctx:
        g = req_dict(ctx["gates"], "context.gates")
        strict_keys(g, set(), set(GATES), "context.gates")
        for name, spec in g.items():
            spec = req_dict(spec, f"context.gates.{name}")
            strict_keys(spec, {"status"}, {"basis"}, f"context.gates.{name}")
            out["gates"][name] = {"status": req_enum(spec["status"], GateStatus.ALL, f"context.gates.{name}.status"),
                                  "basis": clean_text(spec.get("basis", "Declared in the supplied context."), 200, "gate.basis")}
    out["human_authorizations"] = req_list(ctx.get("human_authorizations", []), "context.human_authorizations", 50)
    reports = []
    for r in req_list(ctx.get("execution_reports", []), "context.execution_reports", 50):
        r = req_dict(r, "context.execution_reports")
        strict_keys(r, {"change_id", "reported_by", "reported_at_utc", "outcome"}, set(), "context.execution_reports")
        reports.append({"change_id": require_id(r["change_id"], ("CHG",), "execution_report.change_id"),
                        "reported_by": require_id(r["reported_by"], ("REV",), "execution_report.reported_by"),
                        "reported_at_utc": req_utc(r["reported_at_utc"], "execution_report.reported_at_utc"),
                        "outcome": clean_text(r["outcome"], 300, "execution_report.outcome")})
    out["execution_reports"] = reports
    out["proposer_ids"] = id_list(ctx.get("proposer_ids", []), ("REV",), "context.proposer_ids", 20)
    return out


# --- risk / impact -------------------------------------------------------------------------------

def _risk_factors(view: dict, rec: dict, guidance: dict, hazard: bool, supporting: list, contradicting: list) -> list:
    """Transparent, explainable factors. Each states the criterion applied; there is no aggregate
    numeric score, and UNKNOWN is reported as UNKNOWN."""
    state = view["root_cause"]["completeness"]
    incomplete = view["evidence_manifest"]["completeness"] != "COMPLETE"
    factors = [
        {"dimension": "causal_basis", "level": {"CONFIRMED": "LOW", "PROBABLE": "MEDIUM"}.get(state, "HIGH"),
         "criterion": "RCA state is authoritative: CONFIRMED=LOW, PROBABLE=MEDIUM, anything else=HIGH risk of acting on a wrong cause.",
         "basis": f"RCA completeness is {state}.", "epistemic": "inferred"},
        {"dimension": "evidence_completeness", "level": "HIGH" if incomplete else "LOW",
         "criterion": "Declared evidence references missing from the manifest raise this factor to HIGH.",
         "basis": "Evidence manifest is INCOMPLETE_REFS." if incomplete else "Evidence manifest is COMPLETE.",
         "epistemic": "observed"},
        {"dimension": "contradicting_evidence", "level": "MEDIUM" if contradicting else "LOW",
         "criterion": "Any contradicting evidence on the linked hypothesis is preserved and raises this factor to at least MEDIUM.",
         "basis": f"{len(contradicting)} contradicting evidence reference(s) on the linked hypothesis(es).",
         "epistemic": "observed"},
        {"dimension": "service_interruption_potential", "level": "HIGH" if hazard else ("MEDIUM" if rec["requires_change"] else "LOW"),
         "criterion": "Action text implying restart/failover/relocation/removal/resize=HIGH; any change=MEDIUM.",
         "basis": "Action text contains a disruptive verb." if hazard else "No disruptive verb detected in the action text.",
         "epistemic": "inferred"},
        {"dimension": "topology_breadth", "level": guidance["breadth"],
         "criterion": "Domain breadth table: RAC/ASM/Data Guard/network/security=HIGH; others=MEDIUM. The real scope is UNKNOWN until the reviewer states it.",
         "basis": guidance["blast"], "epistemic": "inferred"},
    ]
    if guidance["license_dependent"]:
        factors.append({"dimension": "licensing", "level": "UNKNOWN",
                        "criterion": "Domains touching licensed options are UNKNOWN until entitlement is confirmed; never assumed from version/default.",
                        "basis": guidance.get("license_note", ""), "epistemic": "unknown"})
    return factors


def _gate_view(context: dict, view: dict, guidance: dict) -> dict:
    out = {}
    for name in GATES:
        g = dict(context["gates"][name])
        if name == "license" and guidance["license_dependent"] and g["status"] == GateStatus.NOT_APPLICABLE:
            # A licence-dependent domain can never be silently NOT_APPLICABLE.
            g = {"status": GateStatus.UNKNOWN, "basis": "License-dependent domain: NOT_APPLICABLE is not accepted without evidence."}
        out[name] = g
    return out


def _readiness(view, gates, rollback_ok, validation_ok, has_evidence, state) -> tuple:
    blockers, review = [], []
    if not has_evidence:
        blockers.append("NO_EVIDENCE_REFS")
    for name, g in gates.items():
        if g["status"] == GateStatus.FAIL:
            blockers.append(f"GATE_FAILED_{name.upper()}")
        elif g["status"] not in GateStatus.NON_BLOCKING:
            review.append(f"GATE_UNRESOLVED_{name.upper()}")
    if not rollback_ok:
        blockers.append("ROLLBACK_MISSING")
    if not validation_ok:
        blockers.append("VALIDATION_MISSING")
    if state != "CONFIRMED":
        review.append("CAUSE_NOT_CONFIRMED")
    if view["evidence_manifest"]["completeness"] != "COMPLETE":
        review.append("EVIDENCE_INCOMPLETE")
    if not has_evidence:
        readiness = Readiness.INSUFFICIENT_EVIDENCE
    elif blockers:
        readiness = Readiness.BLOCKED
    elif review:
        readiness = Readiness.REVIEW_REQUIRED
    else:
        readiness = Readiness.READY_FOR_HUMAN_REVIEW
    return readiness, sorted(set(blockers)), sorted(set(review))


# --- operational advisory ------------------------------------------------------------------------

def _steps(prefix: str, rec: dict) -> list:
    steps = []
    n = 0
    for phase, text in (("PRECHECK", "Record the current state/value of the affected setting before any change."),
                        ("PRECHECK", rec["precheck"]),
                        ("MANUAL_ACTION", "Proposed for a human administrator, subject to human approval: " + rec["action_summary"]),
                        ("POSTCHECK", rec["postcheck"])):
        if not text:
            continue
        n += 1
        steps.append({"step_id": f"{prefix}-S{n:02d}", "order": n, "phase": phase, "text": text,
                      "executor": "TO_BE_DEFINED", "execution_status": EXECUTION_STATUS_NOT_EXECUTED})
    return steps


def build_change_advisory(view: dict, context_raw, generated_at: str) -> dict:
    require_sanitizer()
    context = parse_change_context(context_raw)
    incident_id = view["incident_id"]
    state = view["root_cause"]["completeness"]
    hyps = {h["hypothesis_id"]: h for h in view["hypotheses"]}
    findings = view["findings"]
    changes, notes = [], []
    warnings = list(view["warnings"])

    actionable = state in ("CONFIRMED", "PROBABLE")
    if not actionable:
        warnings.append("RCA_NOT_CONFIRMED_NO_CAUSE_ASSERTED")

    n = 0
    for rec in view["recommendations"]:
        if not actionable or not rec["requires_change"]:
            notes.append({"rec_id": rec["rec_id"], "kind": "INVESTIGATION_NOTE" if not rec["requires_change"] else "DEFERRED_NO_CONFIRMED_CAUSE",
                          "text": rec["action_summary"], "execution_status": EXECUTION_STATUS_NOT_EXECUTED,
                          "epistemic": "proposed"})
            continue
        n += 1
        change_id = f"CHG-{incident_id}-{n:03d}"
        hyp_refs = list(rec["hypothesis_refs"]) or list(view["root_cause"]["confirmed_hypothesis_ids"])
        linked = [hyps[h] for h in hyp_refs if h in hyps]
        domain = linked[0]["domain"] if linked else (view["domains_involved"][0] if view["domains_involved"] else "oracle")
        guidance = DOMAIN_GUIDANCE[domain]
        supporting = sorted({e for h in linked for e in h["supporting_evidence_ids"]})
        contradicting = sorted({e for h in linked for e in h["contradicting_evidence_ids"]})
        finding_refs = sorted(f["finding_id"] for f in findings if set(f["evidence_ids"]) & set(supporting))
        hazard = bool(_HAZARD.search(rec["action_summary"]))
        gates = _gate_view(context, view, guidance)
        steps = _steps(change_id, rec)
        for s in steps:
            if has_executable_content(s["text"]):
                raise AdvisoryError("E_UNSAFE_CONTENT", "proposed_manual_steps")
        rollback_steps = guidance["rollback"]
        rollback_ok = bool(rollback_steps)
        validation_ok = bool(rec["postcheck"])
        readiness, blockers, review_reasons = _readiness(view, gates, rollback_ok, validation_ok, bool(supporting), state)
        arch = context["target"]["architecture"]
        change = {
            "change_id": change_id, "change_type": ChangeType.OPERATIONAL_MANUAL,
            "status": ChangeStatus.DRAFT if readiness in (Readiness.BLOCKED, Readiness.INSUFFICIENT_EVIDENCE) else ChangeStatus.REVIEW_REQUIRED,
            "review_status": ReviewStatus.REVIEW_REQUIRED,
            "readiness": readiness, "blockers": blockers, "review_reasons": review_reasons,
            "source_refs": {"incident_id": incident_id, "rca_id": view["root_cause"]["rca_id"],
                            "hypothesis_ids": sorted(hyp_refs), "finding_ids": finding_refs},
            "evidence_refs": supporting, "recommendation_refs": [rec["rec_id"]],
            "context": {"rca_state": state, "rca_state_authority": "rca_engine (Phase 11); never re-derived here",
                        "domain": domain},
            "objective": rec["action_summary"],
            "scope": {"statement": "Scope of the target to be defined by the human reviewer.", "status": "TO_BE_DEFINED",
                      "target_token": view["target_id"]},
            "out_of_scope": ["Execution of this change by the e-stack", "Any change not listed in proposed_manual_steps",
                             "Application-level or business-data changes"],
            "assumptions": ["No assumption of compatibility, entitlement or privilege is made; see the gates.",
                            "The advisory reflects sanitized evidence available at generation time only."],
            "proposed_manual_steps": steps,
            "entry_criteria": ["All gates PASS or NOT_APPLICABLE with a stated basis", "Human approval recorded outside the e-stack",
                               "Rollback plan reviewed by the executing administrator"],
            "exit_criteria": ["Validation plan checks are satisfied", "Result recorded by the human administrator"],
            "suggested_window": {"status": "TO_BE_DEFINED", "note": "A window is a human decision; none is proposed by the engine."},
            "responsible": "TO_BE_DEFINED",
            "dependencies": [{"dependency": d, "status": "TO_BE_DEFINED"} for d in
                             ("Service owners notified", "Platform/infrastructure owners coordinated")],
            "impact": {"affected_scope": guidance["blast"], "epistemic": "inferred"},
            "risk_factors": _risk_factors(view, rec, guidance, hazard, supporting, contradicting),
            "affected_components": list(guidance["components"]),
            "blast_radius": {"statement": guidance["blast"], "status": "UNKNOWN_UNTIL_SCOPE_DEFINED"},
            "service_dependencies": "UNKNOWN",
            "expected_benefit_as_hypothesis": ("Hypothesis (not a guarantee): addressing the linked cause may resolve the reported symptom: "
                                               + (linked[0]["statement"] if linked else "no linked hypothesis")),
            "reversibility": guidance["reversibility"],
            "rollback_plan": {"status": "DEFINED_GENERIC" if rollback_ok else "MISSING", "steps": list(rollback_steps),
                              "epistemic": "proposed"},
            "rollback_preconditions": ["Pre-change value/state was recorded", "The executing administrator is authorized for the rollback"],
            "rollback_risks": ["Rollback may itself interrupt service", "A generic rollback does not replace a site-specific plan"],
            "validation_plan": {"status": "DEFINED" if validation_ok else "MISSING", "checks": [rec["postcheck"]] if validation_ok else []},
            "stop_conditions": ["Any unexpected error during the manual steps",
                                "Any gate is found to be FAIL or UNKNOWN at execution time"]
                               + (["Unplanned service interruption is observed"] if hazard else []),
            "observability": ["Alert log and monitoring of the affected component during and after the change"],
            "open_questions": [f"Gate {g.upper()}: {v['status']}" for g, v in gates.items() if v["status"] not in GateStatus.NON_BLOCKING]
                              + ["Which exact instances/PDBs/nodes are in scope?"],
            "oracle_version": context["target"]["oracle_version"] or "UNKNOWN",
            "release_update": context["target"]["release_update"] or "UNKNOWN",
            "platform": context["target"]["platform"] or "UNKNOWN",
            "topology": {k: ("UNKNOWN" if v is None else v) for k, v in arch.items()},
            "capability_gate": gates["capability"], "license_gate": gates["license"],
            "privilege_gate": gates["privilege"], "change_window_gate": gates["change_window"],
            "license_note": guidance.get("license_note"),
            "execution_status": EXECUTION_STATUS_NOT_EXECUTED,
            "external_execution_report": None,
            "epistemic": "proposed",
        }
        change["content_digest"] = content_digest(change)
        changes.append(change)

    # --- external declarations (never executed by the engine) ---
    ids = {c["change_id"]: c for c in changes}
    for rep in context["execution_reports"]:
        if rep["change_id"] not in ids:
            raise AdvisoryError("E_REFERENCE", "execution_report.change_id")
        ids[rep["change_id"]]["external_execution_report"] = {
            "status": EXECUTION_STATUS_HUMAN_REPORTED, "epistemic": "human_reported",
            "reported_by": rep["reported_by"], "reported_at_utc": rep["reported_at_utc"], "outcome": rep["outcome"],
            "note": "Declared externally; not verified by the e-stack. Verification requires read-only evidence."}
    used = set()
    for raw in context["human_authorizations"]:
        from .authorization import parse_authorization
        rec = parse_authorization(raw)
        chg = ids.get(rec["artifact_id"])
        if chg is None:
            raise AdvisoryError("E_REFERENCE", "authorization.artifact_id")
        used.add(rec["artifact_id"])
        if rec["decision"] == "REJECTED":
            decl = verify_authorization(raw, artifact_id=chg["change_id"], artifact_digest=chg["content_digest"], version="1",
                                        proposer_ids=context["proposer_ids"], require_decision="REJECTED")
            chg["status"], chg["review_status"] = ChangeStatus.REJECTED, ReviewStatus.REJECTED
            chg["approval_declaration"] = decl
            continue
        if chg["readiness"] in (Readiness.BLOCKED, Readiness.INSUFFICIENT_EVIDENCE):
            raise AdvisoryError("E_TRANSITION_DENIED", "change.status")  # a blocked change cannot be approved
        decl = verify_authorization(raw, artifact_id=chg["change_id"], artifact_digest=chg["content_digest"], version="1",
                                    proposer_ids=context["proposer_ids"])
        chg["status"], chg["review_status"] = ChangeStatus.APPROVED_BY_HUMAN, ReviewStatus.APPROVED_BY_HUMAN
        chg["approval_declaration"] = decl
        # APPROVED_BY_HUMAN never alters execution_status.
        assert chg["execution_status"] == EXECUTION_STATUS_NOT_EXECUTED

    order = {Readiness.INSUFFICIENT_EVIDENCE: 0, Readiness.BLOCKED: 1, Readiness.REVIEW_REQUIRED: 2, Readiness.READY_FOR_HUMAN_REVIEW: 3}
    if changes:
        readiness = min((c["readiness"] for c in changes), key=lambda r: order[r])
    else:
        readiness = Readiness.INSUFFICIENT_EVIDENCE if not actionable else Readiness.REVIEW_REQUIRED
        if actionable:
            warnings.append("NO_CHANGE_REQUIRED_BY_RECOMMENDATIONS")
    advisory = {
        "schema_version": SCHEMA_VERSION, "artifact_type": "change_advisory",
        "advisory_id": f"ADV-{incident_id}", "change_type": ChangeType.OPERATIONAL_MANUAL,
        "generated_at_utc": generated_at, "generator_version": GENERATOR_VERSION,
        "sanitization_status": SanitizationStatus.SANITIZED, "review_status": ReviewStatus.REVIEW_REQUIRED,
        "source_refs": {"incident_id": incident_id, "rca_id": view["root_cause"]["rca_id"],
                        "recommendation_ids": [r["rec_id"] for r in view["recommendations"]],
                        "hypothesis_ids": [h["hypothesis_id"] for h in view["hypotheses"]],
                        "evidence_ids": view["evidence_manifest"]["present_refs"],
                        "finding_ids": [f["finding_id"] for f in findings]},
        "target_token": view["target_id"],
        "rca_state": {"completeness": state, "confirmed_hypothesis_ids": view["root_cause"]["confirmed_hypothesis_ids"],
                      "competing_hypothesis_ids": view["root_cause"]["competing_hypothesis_ids"],
                      "authority": "rca_engine (Phase 11)"},
        "readiness": readiness,
        "warnings": sorted(set(warnings)),
        "limitations": view["limitations"] + [
            "Advisory only: nothing here was executed, scheduled, approved or promoted by the e-stack.",
            "Compatibility, licensing and privilege are never inferred from version or defaults; unresolved gates are UNKNOWN.",
            "An approval declaration, if present, is an external declaration whose identity is not verified by the e-stack."],
        "changes": changes, "non_change_notes": notes,
        "execution_status": EXECUTION_STATUS_NOT_EXECUTED,
    }
    advisory["content_digest"] = content_digest(advisory)
    return advisory


# --- plane B: e-stack evolution governance -------------------------------------------------------

def build_estack_change(request, generated_at: str) -> dict:
    """`request` (strict): {schema_version, change_request_id, title, gap_description,
    artifact_types[], proposer_id (REV token), stages{STAGE: {status, evidence_note}},
    compatibility{check: PASS|FAIL|UNKNOWN}, authorization? (external record for HUMAN_REVIEW)}"""
    require_sanitizer()
    req = req_dict(request, "estack_request")
    strict_keys(req, {"schema_version", "change_request_id", "title", "gap_description", "artifact_types",
                      "proposer_id", "stages", "compatibility"}, {"authorization"}, "estack_request")
    if req["schema_version"] != SCHEMA_VERSION:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "estack_request.schema_version")
    crq = require_id(req["change_request_id"], ("CHG",), "estack_request.change_request_id")
    types = text_list(req["artifact_types"], "estack_request.artifact_types", 12, 30)
    if not types or any(t not in ESTACK_ARTIFACT_TYPES for t in types):
        raise AdvisoryError("E_INPUT_INVALID", "estack_request.artifact_types")
    proposer = require_id(req["proposer_id"], ("REV",), "estack_request.proposer_id")
    stages_in = req_dict(req["stages"], "estack_request.stages")
    if set(stages_in) - set(ESTACK_WORKFLOW_STAGES):
        raise AdvisoryError("E_INPUT_INVALID", "estack_request.stages")
    stages = []
    for st in ESTACK_WORKFLOW_STAGES:
        spec = stages_in.get(st, {"status": "NOT_RUN"})
        spec = req_dict(spec, "estack_request.stages")
        strict_keys(spec, {"status"}, {"evidence_note"}, "estack_request.stages")
        status = req_enum(spec["status"], _STAGE_STATUS, "estack_request.stages.status")
        stages.append({"stage": st, "status": status,
                       "evidence_note": clean_text(spec.get("evidence_note", ""), 200, "stage.evidence_note")})
    # PROMOTE can never be reported PASS by the engine — it is a human action outside the e-stack.
    if stages[-1]["status"] != "NOT_RUN":
        raise AdvisoryError("E_TRANSITION_DENIED", "estack_request.stages.PROMOTE")
    seen_gap = False
    for s in stages:                                   # PASS stages must form a contiguous prefix
        if s["status"] != "PASS":
            seen_gap = True
        elif seen_gap:
            raise AdvisoryError("E_INPUT_INVALID", "estack_request.stages")
    compat_in = req_dict(req["compatibility"], "estack_request.compatibility")
    if set(compat_in) - set(ESTACK_COMPAT_CHECKS):
        raise AdvisoryError("E_INPUT_INVALID", "estack_request.compatibility")
    compat = {c: req_enum(compat_in.get(c, "UNKNOWN"), {"PASS", "FAIL", "UNKNOWN"}, "estack_request.compatibility") for c in ESTACK_COMPAT_CHECKS}

    blockers = []
    first_open = next((s for s in stages if s["status"] != "PASS"), None)
    failed = [s["stage"] for s in stages if s["status"] == "FAIL"]
    if failed:
        blockers += [f"STAGE_FAILED_{x}" for x in failed]
    blockers += [f"COMPATIBILITY_{k.upper()}_{v}" for k, v in compat.items() if v != "PASS"]   # unknown != supported
    security_or_regression_failed = any(x in failed for x in ("SECURITY_VALIDATION", "REGRESSION_VALIDATION"))
    docs_done = all(s["status"] == "PASS" for s in stages if s["stage"] in ESTACK_WORKFLOW_STAGES[:ESTACK_WORKFLOW_STAGES.index("HUMAN_REVIEW")])
    if security_or_regression_failed:
        state = "RETURNED_TO_PROPOSAL"
    elif docs_done and not [b for b in blockers if b.startswith(("COMPATIBILITY", "STAGE_FAILED"))]:
        state = "PENDING_HUMAN_REVIEW"
    else:
        state = "IN_PROGRESS" if not failed else "BLOCKED"
    change = {
        "change_id": crq, "change_type": ChangeType.ESTACK_DEVELOPMENT,
        "status": ChangeStatus.DRAFT if state != "PENDING_HUMAN_REVIEW" else ChangeStatus.REVIEW_REQUIRED,
        "review_status": ReviewStatus.PENDING_HUMAN_REVIEW if state == "PENDING_HUMAN_REVIEW" else ReviewStatus.REVIEW_REQUIRED,
        "governance_state": state, "current_stage": first_open["stage"] if first_open else "PROMOTE",
        "title": clean_text(req["title"], 120, "title"), "gap_description": clean_text(req["gap_description"], 300, "gap"),
        "artifact_types": sorted(types), "proposer_id": proposer, "stages": stages, "compatibility": compat,
        "blockers": sorted(set(blockers)), "promote_status": "HUMAN_ACTION_REQUIRED",
        "policy": ["Changes are implemented only on the development branch.",
                   "The engine never promotes, merges, tags, pushes or publishes.",
                   "The proposer cannot be the human reviewer of its own change."],
        "execution_status": EXECUTION_STATUS_NOT_EXECUTED, "epistemic": "proposed",
    }
    if has_instruction_markers(req["title"]) or has_instruction_markers(req["gap_description"]):
        change["warnings"] = ["INSTRUCTION_LIKE_TEXT_TREATED_AS_DATA"]
    change["content_digest"] = content_digest(change)
    if "authorization" in req:
        if state != "PENDING_HUMAN_REVIEW":
            raise AdvisoryError("E_TRANSITION_DENIED", "estack_request.authorization")
        change["approval_declaration"] = verify_authorization(
            req["authorization"], artifact_id=crq, artifact_digest=change["content_digest"], version="1", proposer_ids=[proposer])
        change["review_status"] = ReviewStatus.APPROVED_BY_HUMAN
        change["status"] = ChangeStatus.APPROVED_BY_HUMAN
        # Even approved: PROMOTE remains a manual repository action.
    return {"schema_version": SCHEMA_VERSION, "artifact_type": "estack_change_governance",
            "generated_at_utc": generated_at, "generator_version": GENERATOR_VERSION,
            "sanitization_status": SanitizationStatus.SANITIZED, "review_status": change["review_status"],
            "source_refs": {"change_request_id": crq}, "change": change,
            "limitations": ["Governance report only; no repository change, tag, merge, push or promotion was performed."],
            "content_digest": content_digest(change)}


# --- Markdown rendering --------------------------------------------------------------------------

def _bul(items) -> list:
    return [f"- {md_escape(i)}" for i in items] or ["- _none_"]


def render_change_advisory_md(adv: dict) -> str:
    L = []
    L.append(f"# Change Advisory {md_code(adv['advisory_id'])}")
    L.append("")
    L.append("> ADVISORY ONLY — READ-ONLY, HUMAN-EXECUTED. Nothing described here was executed, scheduled, approved or promoted by the e-stack.")
    L.append("")
    L.append("| Field | Value |")
    L.append("|---|---|")
    for k, v in (("Incident", adv["source_refs"]["incident_id"]), ("RCA", adv["source_refs"]["rca_id"]),
                 ("RCA state (authoritative)", adv["rca_state"]["completeness"]), ("Readiness", adv["readiness"]),
                 ("Review status", adv["review_status"]), ("Execution status", adv["execution_status"]),
                 ("Generated (UTC)", adv["generated_at_utc"]), ("Generator", adv["generator_version"]),
                 ("Sanitization", adv["sanitization_status"]), ("Schema", adv["schema_version"]),
                 ("Content digest", adv["content_digest"])):
        L.append(f"| {md_escape(k)} | {md_escape(v)} |")
    L.append("")
    L.append("## Warnings")
    L += _bul(adv["warnings"])
    L.append("")
    L.append("## Limitations")
    L += _bul(adv["limitations"])
    for c in adv["changes"]:
        L.append("")
        L.append(f"## Change {md_code(c['change_id'])} — {md_escape(c['status'])}")
        L.append("")
        L.append(f"- **Type:** {md_escape(c['change_type'])}")
        L.append(f"- **Readiness:** {md_escape(c['readiness'])}")
        L.append(f"- **Execution status:** {md_escape(c['execution_status'])}")
        L.append(f"- **Objective:** {md_escape(c['objective'])}")
        L.append(f"- **Oracle version / RU / platform:** {md_escape(c['oracle_version'])} / {md_escape(c['release_update'])} / {md_escape(c['platform'])}")
        L.append(f"- **Evidence refs:** {', '.join(md_code(e) for e in c['evidence_refs']) or '_none_'}")
        L.append(f"- **Recommendation refs:** {', '.join(md_code(e) for e in c['recommendation_refs'])}")
        L.append(f"- **Hypothesis refs:** {', '.join(md_code(e) for e in c['source_refs']['hypothesis_ids']) or '_none_'}")
        L.append("")
        L.append("### Gates")
        L.append("")
        L.append("| Gate | Status | Basis |")
        L.append("|---|---|---|")
        for g in ("capability_gate", "license_gate", "privilege_gate", "change_window_gate"):
            L.append(f"| {md_escape(g)} | {md_escape(c[g]['status'])} | {md_escape(c[g]['basis'])} |")
        L.append("")
        L.append("### Blockers and review reasons")
        L += _bul(c["blockers"] + c["review_reasons"])
        L.append("")
        L.append("### Proposed manual steps (text for a human administrator — not executed)")
        for s in c["proposed_manual_steps"]:
            L.append(f"{s['order']}. **{md_escape(s['phase'])}** — {md_escape(s['text'])} _(executor: {md_escape(s['executor'])}; {md_escape(s['execution_status'])})_")
        L.append("")
        L.append("### Risk factors (explainable; no numeric score)")
        L.append("")
        L.append("| Dimension | Level | Criterion | Basis |")
        L.append("|---|---|---|---|")
        for r in c["risk_factors"]:
            L.append(f"| {md_escape(r['dimension'])} | {md_escape(r['level'])} | {md_escape(r['criterion'])} | {md_escape(r['basis'])} |")
        L.append("")
        L.append("### Impact and blast radius")
        L.append(f"- {md_escape(c['impact']['affected_scope'])}")
        L.append(f"- Blast radius status: {md_escape(c['blast_radius']['status'])}")
        L.append("")
        L.append("### Rollback (generic, proposed)")
        L.append(f"- Status: {md_escape(c['rollback_plan']['status'])}; reversibility: {md_escape(c['reversibility'])}")
        L += _bul(c["rollback_plan"]["steps"])
        L.append("")
        L.append("### Validation plan")
        L += _bul(c["validation_plan"]["checks"])
        L.append("")
        L.append("### Stop conditions")
        L += _bul(c["stop_conditions"])
        L.append("")
        L.append("### Open questions")
        L += _bul(c["open_questions"])
        L.append("")
        L.append("### Approvals")
        if c.get("approval_declaration"):
            a = c["approval_declaration"]
            L.append(f"- Decision {md_escape(a['decision'])} by {md_code(a['reviewer_id'])} at {md_escape(a['decision_at_utc'])} "
                     f"(verification: {md_escape(a['verification'])})")
        else:
            L.append("- Pending: no external human authorization record supplied.")
        if c.get("external_execution_report"):
            r = c["external_execution_report"]
            L.append(f"- External execution report ({md_escape(r['status'])}): {md_escape(r['outcome'])}")
    if adv["non_change_notes"]:
        L.append("")
        L.append("## Notes without a change proposal")
        for n in adv["non_change_notes"]:
            L.append(f"- {md_code(n['rec_id'])} ({md_escape(n['kind'])}): {md_escape(n['text'])}")
    L.append("")
    return "\n".join(L)
