"""
rca_engine.rules — loads a versioned, allowlisted rules catalog (rca_engine/rules/default_rules.json
by default, or an explicit --rules path) and matches it against normalized evidence.

A rule is a declarative structure — never free-text LLM reasoning — so a defect in causal logic
(e.g. a threshold flipped, a contradiction dropped) is mechanically detectable by a test: this is
what makes the mutation-testing control in tests/test_rca_mutation_testing_control.sh meaningful
(section 6 del prompt de hardening).

Matching only ever considers evidence whose event_type is CAUSAL_ELIGIBLE_EVENT_TYPES — a RECOVERY
event can never satisfy a supporting/contradicting/temporal_proof condition (see common.py).

Python 3 standard library only.
"""
from __future__ import annotations

import json
from typing import Optional

from .common import CAUSAL_ELIGIBLE_EVENT_TYPES, SignatureStatus

_OPS = {
    "==": lambda a, b: a == b,
    "!=": lambda a, b: a != b,
    ">": lambda a, b: a is not None and a > b,
    ">=": lambda a, b: a is not None and a >= b,
    "<": lambda a, b: a is not None and a < b,
    "<=": lambda a, b: a is not None and a <= b,
    "in": lambda a, b: a in b,
}

_REQUIRED_RULE_FIELDS = (
    "rule_id", "domain", "statement", "causal_chain", "symptom_match",
    "supporting_conditions", "contradicting_conditions", "min_independent_sources",
)


class RulesError(ValueError):
    """Raised for a malformed/invalid rules file — never silently ignored."""


# Cross-cutting attributes consumed outside the rule-matching engine itself (e.g. timeline.py's
# clock-skew detection) — allowlisted here too so sanitize_attributes() never drops them.
_CROSS_CUTTING_ATTRIBUTE_KEYS = frozenset({"source_clock_offset_seconds"})


def collect_certified_signatures(rules_catalog: dict) -> frozenset:
    """PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING: derives the
    literal, versioned set of template-shaped `signature_any` values every rule in the loaded
    catalog actually declares — the ONLY basis on which a non-numeric-code signature may ever be
    classified CERTIFIED (see sanitize.classify_signature()). Matching the generic upper-snake-case
    *shape* is deliberately never sufficient on its own — only exact membership in this
    catalog-derived, reviewable set. Numeric ORA/TNS/RMAN/CRS/LSNR/PLS-NNNNN codes are certified by
    grammar instead (a bounded, typed code space, not free text) and are not included here."""
    signatures = set()
    for rule in rules_catalog["rules"]:
        for sig in rule.get("symptom_match", {}).get("signature_any", []):
            signatures.add(sig)
    return frozenset(signatures)


def collect_allowed_attribute_keys(rules_catalog: dict) -> frozenset:
    """Derives the full set of `attributes` keys this engine actually reads — from every rule's
    supporting_conditions/contradicting_conditions/temporal_proof_condition — plus the small fixed
    set of cross-cutting keys consumed outside rule matching. Any `attributes` key NOT in this set
    is unknown to the engine and is dropped by sanitize_attributes(), never propagated (PHASE 11 —
    RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 3: allowlist known
    structural keys, safe-drop unknown ones)."""
    keys = set(_CROSS_CUTTING_ATTRIBUTE_KEYS)
    for rule in rules_catalog["rules"]:
        for cond in rule["supporting_conditions"]:
            keys.add(cond["attribute"])
        for cond in rule["contradicting_conditions"]:
            keys.add(cond["attribute"])
        tp = rule.get("temporal_proof_condition")
        if tp:
            keys.add(tp["attribute"])
    return frozenset(keys)


def load_rules(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if "rules_version" not in data or "rules" not in data:
        raise RulesError(f"{path}: missing 'rules_version' or 'rules' at top level")
    if not isinstance(data["rules"], list) or not data["rules"]:
        raise RulesError(f"{path}: 'rules' must be a non-empty list")
    seen_ids = set()
    for i, rule in enumerate(data["rules"]):
        for field_name in _REQUIRED_RULE_FIELDS:
            if field_name not in rule:
                raise RulesError(f"{path}: rules[{i}] missing required field '{field_name}'")
        if rule["rule_id"] in seen_ids:
            raise RulesError(f"{path}: duplicate rule_id '{rule['rule_id']}'")
        seen_ids.add(rule["rule_id"])
    return data


def _condition_matches(evidence, condition: dict) -> bool:
    if evidence.event_type not in CAUSAL_ELIGIBLE_EVENT_TYPES:
        return False
    cond_domain = condition.get("domain")
    if cond_domain is not None and evidence.domain != cond_domain:
        return False
    attr = condition["attribute"]
    if attr not in evidence.attributes:
        return False
    op = _OPS.get(condition.get("op", "=="))
    if op is None:
        raise RulesError(f"unknown operator '{condition.get('op')}' in condition for attribute '{attr}'")
    try:
        return bool(op(evidence.attributes[attr], condition["value"]))
    except TypeError:
        return False


def _symptom_matches(evidence, symptom_match: dict) -> bool:
    if evidence.event_type not in CAUSAL_ELIGIBLE_EVENT_TYPES:
        return False
    signature_any = symptom_match.get("signature_any")
    # only a CERTIFIED signature may ever satisfy a rule's symptom match — an UNRECOGNIZED_SIGNATURE
    # (canonical_signature is None in that case) can never match, by construction, regardless of
    # what the raw text looked like (PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION
    # MICRO-HARDENING).
    if signature_any and evidence.signature_status == SignatureStatus.CERTIFIED \
            and evidence.canonical_signature in signature_any:
        return True
    event_type_any = symptom_match.get("event_type_any")
    if event_type_any and evidence.event_type in event_type_any and not signature_any:
        return True
    return False


def evaluate_rule(rule: dict, evidence_items: list) -> dict:
    """Evaluate a single rule against normalized evidence. Returns a dict with:
    symptom_evidence_ids, supporting_evidence_ids, contradicting_evidence_ids,
    unresolved_critical_contradiction (bool), missing_evidence (list of description str),
    temporal_proof (bool), independent_source_count (int, distinct source_id among supporting).

    Deterministic: iterates evidence_items in their given (already stably ordered) sequence and
    never reorders results — same input always yields the same lists in the same order.
    """
    symptom_ids = [e.evidence_id for e in evidence_items if _symptom_matches(e, rule["symptom_match"])]

    supporting_ids = []
    supporting_sources = set()
    missing = []
    for cond in rule["supporting_conditions"]:
        matched = [e for e in evidence_items if _condition_matches(e, cond)]
        if matched:
            for e in matched:
                if e.evidence_id not in supporting_ids:
                    supporting_ids.append(e.evidence_id)
                supporting_sources.add(e.source_id)
        else:
            missing.append(cond.get("description", f"{cond.get('domain')}.{cond['attribute']}"))

    contradicting_ids = []
    unresolved_critical = False
    for cond in rule["contradicting_conditions"]:
        matched = [e for e in evidence_items if _condition_matches(e, cond)]
        for e in matched:
            if e.evidence_id not in contradicting_ids:
                contradicting_ids.append(e.evidence_id)
            if cond.get("critical", True):
                unresolved_critical = True

    temporal_proof = False
    tp_cond = rule.get("temporal_proof_condition")
    if tp_cond:
        temporal_proof = any(_condition_matches(e, tp_cond) for e in evidence_items)

    return {
        "symptom_evidence_ids": symptom_ids,
        "supporting_evidence_ids": supporting_ids,
        "contradicting_evidence_ids": contradicting_ids,
        "unresolved_critical_contradiction": unresolved_critical,
        "missing_evidence": missing,
        "temporal_proof": temporal_proof,
        "independent_source_count": len(supporting_sources),
    }
