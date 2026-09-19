"""
change_documentation_knowledge.schema — strict validators + the versioned Phase 11 -> Phase 12
contract adapter (`adapt_rca_result`).

Adapter contract (registered incompatibilities, see docs/PHASE_12_*.md "Contract audit"):
  * rca_engine emits INC, EVD, HYP, RCA, REC ids. It does NOT emit FND ids. This adapter derives
    stable, deterministic `FND-<incident>-<NNN>` findings ONE-TO-ONE from timeline events (kind
    `timeline_event`, epistemic `observed`), so the logical graph INC->EVD->FND->HYP->RCA->REC is
    complete without inventing any evidence. FND ids are labelled `derived_by: p12_contract_adapter`.
  * rca_engine emits no CHG ids — CHG ids are created by change.py and only for recommendations
    with `requires_change: true`.
  * RCA states are authoritative. This adapter can only *verify* them (impossible combinations
    are rejected, never repaired) — it never promotes PROBABLE/SUPPORTED to CONFIRMED.
  * Hypothesis text and recommendation text are re-anchored on the versioned rules catalog
    (`rca_engine/rules/default_rules.json`): a rule_id unknown to the catalog is an E_REFERENCE
    reject; a statement/causal_chain that differs from the catalog is replaced by the catalog text.
"""
from __future__ import annotations

import re

from .common import (
    SUPPORTED_RCA_CONTRACT_VERSIONS, AdvisoryError,
)
from .safety import (
    MAX_LIST_ITEMS, clean_text, has_executable_content, has_instruction_markers, is_safe_id,
    require_id, require_sanitizer,
)

from rca_engine.common import (  # Phase 11 public contract enums/constants
    ALL_EVENT_TYPES, ALLOWED_DOMAINS, EvidenceManifestCompleteness, HypothesisStatus,
    RootCauseCompleteness, SignatureStatus,
)
from rca_engine.rules import collect_certified_signatures
from rca_engine.sanitize import classify_signature

_TOKEN_TGT = re.compile(r'^TGT-[0-9a-f]{16}$')
_TOKEN_SRC = re.compile(r'^SRC-[0-9a-f]{16}$')
_TOKEN_SIG = re.compile(r'^SIG-[0-9a-f]{16}$')
_TS = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$')
_HYP_STATUSES = frozenset({HypothesisStatus.OPEN, HypothesisStatus.SUPPORTED, HypothesisStatus.WEAKENED,
                          HypothesisStatus.REJECTED, HypothesisStatus.CONFIRMED,
                          HypothesisStatus.INSUFFICIENT_EVIDENCE})
_RC_STATES = frozenset({RootCauseCompleteness.CONFIRMED, RootCauseCompleteness.PROBABLE,
                        RootCauseCompleteness.INCONCLUSIVE, RootCauseCompleteness.INSUFFICIENT_EVIDENCE})
_CONFIDENCES = frozenset({"HIGH", "MEDIUM", "LOW", "INSUFFICIENT"})
_SIG_STATUSES = frozenset({SignatureStatus.CERTIFIED, SignatureStatus.UNRECOGNIZED_SIGNATURE,
                           SignatureStatus.INSUFFICIENT_EVIDENCE})


# --- generic strict helpers ----------------------------------------------------------------------

def req_dict(value, field: str) -> dict:
    if not isinstance(value, dict):
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def req_list(value, field: str, max_items: int = MAX_LIST_ITEMS) -> list:
    if not isinstance(value, list) or len(value) > max_items:
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def strict_keys(obj: dict, required: set, optional: set, field: str) -> None:
    """Own (Phase 12) inputs are strict: unknown keys fail closed and are never echoed."""
    keys = set(obj.keys())
    if not all(isinstance(k, str) for k in keys) or (required - keys) or (keys - required - optional):
        raise AdvisoryError("E_INPUT_INVALID", field)


def req_enum(value, allowed, field: str):
    if not isinstance(value, str) or value not in allowed:
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def req_bool(value, field: str) -> bool:
    if not isinstance(value, bool):
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def req_int(value, field: str, lo: int = 0, hi: int = 10_000_000) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not (lo <= value <= hi):
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def req_utc(value, field: str) -> str:
    from .common import is_utc_timestamp
    if not is_utc_timestamp(value):
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def id_list(value, prefixes, field: str, max_items: int = MAX_LIST_ITEMS) -> list:
    items = req_list(value, field, max_items)
    out = []
    for v in items:
        out.append(require_id(v, prefixes, field))
    if len(set(out)) != len(out):
        raise AdvisoryError("E_INPUT_INVALID", field)
    return out


def text_list(value, field: str, max_items: int = 30, max_len: int = 300) -> list:
    return [clean_text(v, max_len, field) for v in req_list(value, field, max_items)]


# --- Phase 11 RCA contract adapter ---------------------------------------------------------------

def _catalog_index(rules_catalog: dict) -> dict:
    return {r["rule_id"]: r for r in rules_catalog.get("rules", [])}


def _adapt_timeline(timeline: dict, incident_id: str, certified: frozenset, warnings: list) -> dict:
    tl = req_dict(timeline, "timeline")
    events = []
    for i, ev in enumerate(req_list(tl.get("events", []), "timeline.events", 500)):
        ev = req_dict(ev, "timeline.events")
        domain = ev.get("domain")
        if domain not in ALLOWED_DOMAINS:
            raise AdvisoryError("E_RCA_CONTRACT", "timeline.domain")
        etype = ev.get("event_type")
        if etype not in ALL_EVENT_TYPES:
            raise AdvisoryError("E_RCA_CONTRACT", "timeline.event_type")
        sig_status = ev.get("signature_status")
        if sig_status not in _SIG_STATUSES:
            raise AdvisoryError("E_RCA_CONTRACT", "timeline.signature_status")
        canonical = ev.get("canonical_signature")
        token = ev.get("signature_token")
        if sig_status == SignatureStatus.CERTIFIED:
            # Re-verify with the Phase 11 allowlist: a forged 'CERTIFIED' free-text signature is
            # replaced by an opaque token, never echoed (fail closed on the literal).
            if not isinstance(canonical, str):
                raise AdvisoryError("E_RCA_CONTRACT", "timeline.canonical_signature")
            status, canon2, tok2 = classify_signature(canonical, incident_id, certified)
            if status != SignatureStatus.CERTIFIED:
                raise AdvisoryError("E_RCA_CONTRACT", "timeline.canonical_signature")
            canonical, token = canon2, None
        else:
            if canonical is not None:
                raise AdvisoryError("E_RCA_CONTRACT", "timeline.canonical_signature")
            if token is not None and not (isinstance(token, str) and _TOKEN_SIG.match(token)):
                raise AdvisoryError("E_RCA_CONTRACT", "timeline.signature_token")
        srcs = req_list(ev.get("source_ids", []), "timeline.source_ids", 50)
        for s in srcs:
            if not (isinstance(s, str) and _TOKEN_SRC.match(s)):
                raise AdvisoryError("E_RCA_CONTRACT", "timeline.source_ids")
        ts = ev.get("timestamp_utc")
        if ts is not None and not (isinstance(ts, str) and _TS.match(ts)):
            raise AdvisoryError("E_RCA_CONTRACT", "timeline.timestamp_utc")
        events.append({
            "domain": domain, "event_type": etype, "signature_status": sig_status,
            "canonical_signature": canonical, "signature_token": token,
            "timestamp_utc": ts, "count": req_int(ev.get("count", 1), "timeline.count", 1, 1_000_000),
            "evidence_ids": id_list(ev.get("evidence_ids", []), ("EVD",), "timeline.evidence_ids", 200),
            "source_ids": list(srcs), "timeline_degraded": bool(ev.get("timeline_degraded", False)),
        })
    reasons = [clean_text(r, 200, "timeline.degradation_reasons")
               for r in req_list(tl.get("degradation_reasons", []), "timeline.degradation_reasons", 50)]
    return {"events": events, "degraded": bool(tl.get("degraded", False)), "degradation_reasons": reasons}


def adapt_rca_result(rca: dict, rules_catalog: dict) -> dict:
    """Validate a Phase 11 RcaResult dict and project it onto the sanitized Phase 12 view. Raises
    AdvisoryError (stable code, no reflection) on any contract violation."""
    require_sanitizer()
    rca = req_dict(rca, "rca")
    warnings = []
    if rca.get("contract_version") not in SUPPORTED_RCA_CONTRACT_VERSIONS:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "rca.contract_version")

    incident_id = require_id(rca.get("incident_id"), ("INC",), "rca.incident_id")
    target = rca.get("target_id")
    if target is not None and not (isinstance(target, str) and _TOKEN_TGT.match(target)):
        raise AdvisoryError("E_RCA_CONTRACT", "rca.target_id")

    catalog = _catalog_index(rules_catalog)
    certified = collect_certified_signatures(rules_catalog)

    # ---- evidence manifest
    em = req_dict(rca.get("evidence_manifest"), "rca.evidence_manifest")
    completeness = em.get("completeness")
    if completeness not in (EvidenceManifestCompleteness.COMPLETE, EvidenceManifestCompleteness.INCOMPLETE_REFS):
        raise AdvisoryError("E_RCA_CONTRACT", "rca.evidence_manifest.completeness")
    declared = id_list(em.get("declared_refs", []), ("EVD",), "evidence_manifest.declared_refs", 500)
    present = id_list(em.get("present_refs", []), ("EVD",), "evidence_manifest.present_refs", 500)
    missing = id_list(em.get("missing_refs", []), ("EVD",), "evidence_manifest.missing_refs", 500)
    if set(missing) & set(present) or (completeness == EvidenceManifestCompleteness.COMPLETE and missing):
        raise AdvisoryError("E_RCA_CONTRACT", "rca.evidence_manifest")

    timeline = _adapt_timeline(rca.get("timeline", {}), incident_id, certified, warnings)
    known_evidence = set(present) | {e for ev in timeline["events"] for e in ev["evidence_ids"]}

    # ---- hypotheses
    hyps = []
    seen = set()
    for h in req_list(rca.get("hypotheses", []), "rca.hypotheses", 100):
        h = req_dict(h, "rca.hypotheses")
        rule_id = h.get("rule_id")
        if not isinstance(rule_id, str) or rule_id not in catalog:
            raise AdvisoryError("E_REFERENCE", "hypothesis.rule_id")
        rule = catalog[rule_id]
        hyp_id = h.get("hypothesis_id")
        if hyp_id != f"HYP-{incident_id}-{rule_id}" or hyp_id in seen:
            raise AdvisoryError("E_REFERENCE", "hypothesis.hypothesis_id")
        seen.add(hyp_id)
        if h.get("domain") != rule["domain"] or rule["domain"] not in ALLOWED_DOMAINS:
            raise AdvisoryError("E_RCA_CONTRACT", "hypothesis.domain")
        status = h.get("status")
        if status not in _HYP_STATUSES:
            raise AdvisoryError("E_RCA_CONTRACT", "hypothesis.status")
        sup = id_list(h.get("supporting_evidence_ids", []), ("EVD",), "hypothesis.supporting_evidence_ids", 200)
        con = id_list(h.get("contradicting_evidence_ids", []), ("EVD",), "hypothesis.contradicting_evidence_ids", 200)
        if not (set(sup) | set(con)) <= known_evidence:
            raise AdvisoryError("E_REFERENCE", "hypothesis.evidence_ids")
        unresolved = req_bool(h.get("unresolved_critical_contradiction", False), "hypothesis.unresolved")
        if status == HypothesisStatus.CONFIRMED and (unresolved or not sup):
            raise AdvisoryError("E_RCA_CONTRACT", "hypothesis.status")  # impossible state — never repaired
        if h.get("statement") != rule["statement"] or h.get("causal_chain") != rule["causal_chain"]:
            warnings.append("HYPOTHESIS_TEXT_REANCHORED_ON_CATALOG")
        confidence = h.get("confidence")
        if confidence not in _CONFIDENCES:
            raise AdvisoryError("E_RCA_CONTRACT", "hypothesis.confidence")
        missing_ev = [clean_text(m, 200, "hypothesis.missing_evidence")
                      for m in req_list(h.get("missing_evidence", []), "hypothesis.missing_evidence", 30)]
        hyps.append({
            "hypothesis_id": hyp_id, "rule_id": rule_id, "domain": rule["domain"],
            # trusted, versioned catalog text — used verbatim (the broad bare-token heuristic would
            # over-redact e.g. 'ORA-27300/ORA-27301/ORA-27302'); it is never taken from the input.
            "statement": rule["statement"], "causal_chain": list(rule["causal_chain"]),
            "status": status, "supporting_evidence_ids": sup, "contradicting_evidence_ids": con,
            "unresolved_critical_contradiction": unresolved, "missing_evidence": missing_ev,
            "independent_source_count": req_int(h.get("independent_source_count", 0), "hypothesis.independent_source_count", 0, 1000),
            "temporal_proof": req_bool(h.get("temporal_proof", False), "hypothesis.temporal_proof"),
            "confidence": confidence, "epistemic": "inferred",
        })
    hyp_by_id = {h["hypothesis_id"]: h for h in hyps}

    # ---- root cause (authoritative state — verified, never repaired)
    rc = req_dict(rca.get("root_cause"), "rca.root_cause")
    rca_id = rc.get("rca_id")
    if rca_id != f"RCA-{incident_id}-001" or not is_safe_id(rca_id, ("RCA",)):
        raise AdvisoryError("E_REFERENCE", "root_cause.rca_id")
    rc_state = rc.get("completeness")
    if rc_state not in _RC_STATES:
        raise AdvisoryError("E_RCA_CONTRACT", "root_cause.completeness")
    confirmed_ids = id_list(rc.get("confirmed_hypothesis_ids", []), ("HYP",), "root_cause.confirmed_hypothesis_ids", 50)
    competing_ids = id_list(rc.get("competing_hypothesis_ids", []), ("HYP",), "root_cause.competing_hypothesis_ids", 50)
    if not (set(confirmed_ids) | set(competing_ids)) <= set(hyp_by_id):
        raise AdvisoryError("E_REFERENCE", "root_cause.hypothesis_ids")
    if rc_state == RootCauseCompleteness.CONFIRMED:
        if not confirmed_ids or any(hyp_by_id[i]["status"] != HypothesisStatus.CONFIRMED for i in confirmed_ids):
            raise AdvisoryError("E_RCA_CONTRACT", "root_cause.completeness")  # no CONFIRMED without a source
        if completeness == EvidenceManifestCompleteness.INCOMPLETE_REFS:
            raise AdvisoryError("E_RCA_CONTRACT", "root_cause.completeness")
    elif confirmed_ids and rc_state in (RootCauseCompleteness.INCONCLUSIVE, RootCauseCompleteness.INSUFFICIENT_EVIDENCE):
        raise AdvisoryError("E_RCA_CONTRACT", "root_cause.completeness")

    # ---- recommendations
    catalog_actions = {(r["rule_id"], a["action_summary"]) for r in catalog.values() for a in r.get("manual_actions", [])}
    known_actions = {a for (_, a) in catalog_actions}
    recs = []
    for r in req_list(rca.get("recommendations", []), "rca.recommendations", 100):
        r = req_dict(r, "rca.recommendations")
        rec_id = r.get("rec_id")
        if not (isinstance(rec_id, str) and re.match(r'^REC-%s-\d{3}$' % re.escape(rca_id), rec_id)) or not is_safe_id(rec_id, ("REC",)):
            raise AdvisoryError("E_REFERENCE", "recommendation.rec_id")
        if r.get("linked_to") != rca_id:
            raise AdvisoryError("E_REFERENCE", "recommendation.linked_to")
        if r.get("execution_status") != "NOT_EXECUTED":
            raise AdvisoryError("E_RCA_CONTRACT", "recommendation.execution_status")
        cat_action = next((a for rr in catalog.values() for a in rr.get("manual_actions", [])
                           if a["action_summary"] == r.get("action_summary")), None)
        names = ("action_summary", "precheck", "risk", "postcheck")
        if cat_action is not None and all(r.get(n) == cat_action[n] for n in names):
            provenance = "CATALOGUED"   # trusted catalog text, verbatim
            fields = {n: cat_action[n] for n in names}
        else:
            provenance = "UNCATALOGUED_SANITIZED"
            fields = {n: clean_text(r.get(n), 400, f"recommendation.{n}") for n in names}
            warnings.append("RECOMMENDATION_TEXT_NOT_IN_RULES_CATALOG")
        for n in names:
            if has_executable_content(fields[n]):
                raise AdvisoryError("E_UNSAFE_CONTENT", f"recommendation.{n}")
        if has_instruction_markers(" ".join(fields.values())):
            warnings.append("INSTRUCTION_LIKE_TEXT_TREATED_AS_DATA")
        # hypothesis_refs: hypotheses whose catalog rule declares this very manual action and whose
        # status is CONFIRMED/SUPPORTED. Never guessed: an uncatalogued action links to none.
        hyp_refs = sorted(h["hypothesis_id"] for h in hyps
                          if h["status"] in (HypothesisStatus.CONFIRMED, HypothesisStatus.SUPPORTED)
                          and (h["rule_id"], r.get("action_summary")) in catalog_actions)
        recs.append({"rec_id": rec_id, "linked_to": rca_id, "hypothesis_refs": hyp_refs, **fields,
                     "requires_change": req_bool(r.get("requires_change", False), "recommendation.requires_change"),
                     "execution_status": "NOT_EXECUTED", "text_provenance": provenance,
                     "epistemic": "proposed"})
    if len({r["rec_id"] for r in recs}) != len(recs):
        raise AdvisoryError("E_REFERENCE", "recommendation.rec_id")

    # ---- findings derived from the timeline (adapter, one-to-one, observed only)
    findings = []
    for i, ev in enumerate(timeline["events"], start=1):
        findings.append({
            "finding_id": f"FND-{incident_id}-{i:03d}", "derived_by": "p12_contract_adapter",
            "kind": "timeline_event", "domain": ev["domain"], "event_type": ev["event_type"],
            "signature_status": ev["signature_status"], "canonical_signature": ev["canonical_signature"],
            "signature_token": ev["signature_token"], "timestamp_utc": ev["timestamp_utc"],
            "evidence_ids": ev["evidence_ids"], "epistemic": "observed",
        })

    limitations = [clean_text(x, 300, "rca.limitations") for x in req_list(rca.get("limitations", []), "rca.limitations", 30)]
    known = {"contract_version", "engine_version", "rules_version", "incident_id", "target_id", "analysis_origin",
             "timeline", "evidence_manifest", "hypotheses", "root_cause", "recommendations",
             "cross_domain_domains_involved", "validation_issues", "limitations", "generated_at"}
    if set(rca.keys()) - known:
        warnings.append("UNKNOWN_RCA_FIELDS_DROPPED")

    domains = sorted({d for d in req_list(rca.get("cross_domain_domains_involved", []), "rca.domains", 20) if d in ALLOWED_DOMAINS})
    return {
        "incident_id": incident_id, "target_id": target, "rca_contract_version": rca["contract_version"],
        "rules_version": clean_text(str(rules_catalog.get("rules_version", "")), 32),
        "evidence_manifest": {"completeness": completeness, "declared_refs": declared, "present_refs": present,
                              "missing_refs": missing},
        "timeline": timeline, "findings": findings, "hypotheses": hyps,
        "root_cause": {"rca_id": rca_id, "completeness": rc_state, "confirmed_hypothesis_ids": confirmed_ids,
                       "competing_hypothesis_ids": competing_ids, "epistemic": "inferred"},
        "recommendations": recs, "domains_involved": domains, "limitations": limitations,
        "warnings": sorted(set(warnings)),
    }
