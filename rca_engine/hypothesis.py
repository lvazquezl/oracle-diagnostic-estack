"""
rca_engine.hypothesis — generates and evaluates hypotheses from the rules catalog against
normalized evidence.

Status assignment order (section 4.3 del prompt: "evalua contradicciones criticas antes de asignar
el estado"):
  1. An unresolved critical contradiction is evaluated FIRST — it caps the hypothesis at WEAKENED
     (if some supporting evidence exists) or REJECTED (if none), and structurally prevents
     CONFIRMED regardless of how much supporting evidence or temporal proof exists. This is the
     literal implementation of "una contradiccion critica impide CONFIRMED salvo que exista
     evidencia explicita que la resuelva" — this engine has no contradiction-resolution mechanism,
     so an unresolved critical contradiction ALWAYS blocks CONFIRMED, no exception path.
  2. Otherwise, unambiguous temporal proof (docs/CONTRACTS.md#rca-model's second confirmation path)
     grants CONFIRMED on its own.
  3. Otherwise, independent_source_count >= rule's min_independent_sources grants CONFIRMED (the
     model's first confirmation path: >= 2 independent evidence sources).
  4. Otherwise, any supporting evidence at all grants SUPPORTED.
  5. Otherwise (symptom matched, nothing supports or contradicts it) INSUFFICIENT_EVIDENCE — a
     bare symptom is never, by itself, elevated past this (docs/INCIDENT_CAUSALITY_MODEL.md
     #symptom-not-root-cause).

Python 3 standard library only.
"""
from __future__ import annotations

from .common import ConfidenceLevel, Hypothesis, HypothesisStatus
from .rules import evaluate_rule

DEFAULT_MAX_HYPOTHESES = 10


def _status_and_confidence(evaluation: dict, min_sources: int) -> tuple:
    if evaluation["unresolved_critical_contradiction"]:
        if evaluation["supporting_evidence_ids"]:
            return HypothesisStatus.WEAKENED, ConfidenceLevel.LOW
        return HypothesisStatus.REJECTED, ConfidenceLevel.INSUFFICIENT

    if evaluation["temporal_proof"]:
        return HypothesisStatus.CONFIRMED, ConfidenceLevel.HIGH

    if evaluation["independent_source_count"] >= min_sources:
        return HypothesisStatus.CONFIRMED, ConfidenceLevel.HIGH

    if evaluation["independent_source_count"] >= 1:
        return HypothesisStatus.SUPPORTED, ConfidenceLevel.MEDIUM

    return HypothesisStatus.INSUFFICIENT_EVIDENCE, ConfidenceLevel.INSUFFICIENT


def generate_hypotheses(incident_id: str, rules_catalog: dict, evidence: list, policy: dict) -> dict:
    """Returns {"hypotheses": [Hypothesis...], "truncated_rule_ids": [str, ...]}.

    Only rules whose symptom_match finds at least one eligible evidence item become a candidate
    hypothesis — a rule never fires purely on the absence of contradicting evidence.
    """
    max_hypotheses = policy.get("max_hypotheses", DEFAULT_MAX_HYPOTHESES)
    candidates = []

    for rule in rules_catalog["rules"]:
        evaluation = evaluate_rule(rule, evidence)
        if not evaluation["symptom_evidence_ids"]:
            continue
        status, confidence = _status_and_confidence(evaluation, rule["min_independent_sources"])
        hypothesis_id = f"HYP-{incident_id}-{rule['rule_id']}"
        candidates.append((
            rule, evaluation, Hypothesis(
                hypothesis_id=hypothesis_id, rule_id=rule["rule_id"], domain=rule["domain"],
                statement=rule["statement"], causal_chain=list(rule["causal_chain"]), status=status,
                supporting_evidence_ids=evaluation["supporting_evidence_ids"],
                contradicting_evidence_ids=evaluation["contradicting_evidence_ids"],
                unresolved_critical_contradiction=evaluation["unresolved_critical_contradiction"],
                missing_evidence=evaluation["missing_evidence"],
                independent_source_count=evaluation["independent_source_count"],
                temporal_proof=evaluation["temporal_proof"], confidence=confidence,
            )
        ))

    # Deterministic ranking: strongest evidence first, rule_id as a stable tie-break — never
    # dependent on dict/set iteration order or wall-clock time.
    candidates.sort(key=lambda c: (-c[1]["independent_source_count"], c[0]["rule_id"]))

    kept = candidates[:max_hypotheses]
    truncated = [c[0]["rule_id"] for c in candidates[max_hypotheses:]]

    return {"hypotheses": [c[2] for c in kept], "truncated_rule_ids": truncated}
