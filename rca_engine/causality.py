"""
rca_engine.causality — aggregates evaluated hypotheses into a single RootCauseResult, generates
manual-only recommendations, and computes the cross-domain evidence-reuse summary.

Confirmation gate order (section 3/4 del prompt de hardening):
  1. A broken/missing declared evidence reference (evidence_manifest.completeness ==
     INCOMPLETE_REFS) structurally caps EVERY hypothesis at SUPPORTED at most — no hypothesis may
     reach CONFIRMED while required evidence is missing, regardless of how strong its matched
     evidence looks. This downgrade happens before the RCA-level rollup so JSON and Markdown always
     agree (test_rca_json_markdown_consistency, test_rca_missing_or_broken_evidence_ref).
  2. Competing, equally-supported hypotheses (same top independent_source_count, none confirmed)
     produce an explicit INCONCLUSIVE RCA result rather than an arbitrarily chosen winner
     (test_rca_competing_hypotheses_remain_inconclusive).
  3. Multiple hypotheses may legitimately reach CONFIRMED independently — the model allows more
     than one root cause (docs/INCIDENT_ROOT_CAUSE_MODEL.md#múltiples-causas-raíz).

Python 3 standard library only.
"""
from __future__ import annotations

from .common import (
    ConfidenceLevel, EvidenceManifestCompleteness, Hypothesis, HypothesisStatus, Recommendation,
    RootCauseCompleteness, RootCauseResult,
)


def apply_evidence_completeness_gate(hypotheses: list, manifest) -> list:
    if manifest.completeness != EvidenceManifestCompleteness.INCOMPLETE_REFS:
        return hypotheses
    adjusted = []
    for h in hypotheses:
        if h.status == HypothesisStatus.CONFIRMED:
            adjusted.append(Hypothesis(
                hypothesis_id=h.hypothesis_id, rule_id=h.rule_id, domain=h.domain,
                statement=h.statement, causal_chain=h.causal_chain,
                status=HypothesisStatus.SUPPORTED,
                supporting_evidence_ids=h.supporting_evidence_ids,
                contradicting_evidence_ids=h.contradicting_evidence_ids,
                unresolved_critical_contradiction=h.unresolved_critical_contradiction,
                missing_evidence=h.missing_evidence + ["declared evidence reference(s) missing — capped below CONFIRMED"],
                independent_source_count=h.independent_source_count, temporal_proof=h.temporal_proof,
                confidence=ConfidenceLevel.MEDIUM,
            ))
        else:
            adjusted.append(h)
    return adjusted


def aggregate_root_cause(incident_id: str, hypotheses: list) -> RootCauseResult:
    rca_id = f"RCA-{incident_id}-001"
    confirmed = [h for h in hypotheses if h.status == HypothesisStatus.CONFIRMED]

    if confirmed:
        reasoning = (
            f"{len(confirmed)} hypothesis(es) reached CONFIRMED (>= min independent evidence "
            f"sources or unambiguous temporal proof, no unresolved critical contradiction)."
            if len(confirmed) == 1 else
            f"{len(confirmed)} independent hypotheses each individually reached CONFIRMED — "
            f"multiple root causes, never collapsed into one."
        )
        return RootCauseResult(
            rca_id=rca_id, completeness=RootCauseCompleteness.CONFIRMED,
            confirmed_hypothesis_ids=[h.hypothesis_id for h in confirmed],
            competing_hypothesis_ids=[], reasoning=reasoning,
        )

    supported = [h for h in hypotheses if h.status == HypothesisStatus.SUPPORTED]
    if not supported:
        return RootCauseResult(
            rca_id=rca_id, completeness=RootCauseCompleteness.INSUFFICIENT_EVIDENCE,
            confirmed_hypothesis_ids=[], competing_hypothesis_ids=[],
            reasoning="No hypothesis reached sufficient evidentiary support — evidence insufficient "
                      "to confirm, weaken or reject any candidate cause.",
        )

    max_score = max(h.independent_source_count for h in supported)
    top = [h for h in supported if h.independent_source_count == max_score]
    if len(top) == 1:
        return RootCauseResult(
            rca_id=rca_id, completeness=RootCauseCompleteness.PROBABLE,
            confirmed_hypothesis_ids=[], competing_hypothesis_ids=[],
            reasoning=f"Single strongest candidate ({top[0].hypothesis_id}) is supported by evidence "
                      f"but does not meet the confirmation bar (independent sources or temporal proof).",
        )

    return RootCauseResult(
        rca_id=rca_id, completeness=RootCauseCompleteness.INCONCLUSIVE,
        confirmed_hypothesis_ids=[], competing_hypothesis_ids=[h.hypothesis_id for h in top],
        reasoning=f"{len(top)} hypotheses are equally supported (independent_source_count={max_score}) "
                  f"with no differentiating evidence — no forced winner; result is explicitly inconclusive.",
    )


def build_recommendations(rules_catalog: dict, hypotheses: list, root_cause: RootCauseResult) -> list:
    """Manual-only recommendations, always execution_status=NOT_EXECUTED (dataclass default).
    Linked only to CONFIRMED root-cause hypotheses — never generated for a merely PROBABLE/
    INCONCLUSIVE candidate, so a recommendation always traces to a resolved cause."""
    if root_cause.completeness != RootCauseCompleteness.CONFIRMED:
        return []
    rules_by_id = {r["rule_id"]: r for r in rules_catalog["rules"]}
    recs = []
    seq = 1
    for h in hypotheses:
        if h.hypothesis_id not in root_cause.confirmed_hypothesis_ids:
            continue
        rule = rules_by_id.get(h.rule_id, {})
        for action in rule.get("manual_actions", []):
            recs.append(Recommendation(
                rec_id=f"REC-{root_cause.rca_id}-{seq:03d}", linked_to=root_cause.rca_id,
                action_summary=action["action_summary"], precheck=action["precheck"],
                risk=action["risk"], postcheck=action["postcheck"],
                requires_change=bool(action.get("requires_change", True)),
            ))
            seq += 1
    return recs


def cross_domain_domains_involved(hypotheses: list, evidence_by_id: dict) -> list:
    domains = set()
    for h in hypotheses:
        for eid in h.supporting_evidence_ids + h.contradicting_evidence_ids:
            ev = evidence_by_id.get(eid)
            if ev is not None:
                domains.add(ev.domain)
        domains.add(h.domain)
    return sorted(domains)
