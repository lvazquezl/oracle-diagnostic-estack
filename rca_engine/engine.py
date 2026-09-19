"""
rca_engine.engine — orchestrates the full local RCA pipeline (section 2 del prompt de hardening):

  synthetic incident + evidence fixture
    -> schema validation and intake                    (intake.py)
    -> timestamp/timezone normalization                  (timeline.py)
    -> event extraction, ordering and deduplication       (timeline.py)
    -> evidence plan/completeness                          (intake.py, evidence manifest)
    -> findings + hypotheses with support/contradictions    (hypothesis.py, rules.py)
    -> cautious causal assessment                            (causality.py)
    -> RCA result OR explicitly inconclusive result           (causality.py)
    -> manual-only recommendations                              (causality.py)
    -> RcaResult (JSON) + Markdown report + evidence manifest    (this module, report.py)

Determinism: `analysis_origin` (the causal-reasoning anchor) is always the maximum normalized
evidence timestamp actually used — never wall-clock "now". `generated_at` is real-clock audit
metadata only and MUST be excluded when comparing two runs for reproducibility (mirrors
capacity_engine.engine's history_end vs generated_at distinction — see
tests/test_rca_reproducibility_same_input.sh).

Runs entirely offline: no LLM, no MCP, no network, no Oracle connection — Python 3 standard
library only.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone

from .causality import (
    aggregate_root_cause, apply_evidence_completeness_gate, build_recommendations,
    cross_domain_domains_involved,
)
from .common import CONTRACT_VERSION, ENGINE_VERSION, RcaResult
from .hypothesis import generate_hypotheses
from .intake import build_evidence_manifest, validate_and_sanitize
from .rules import load_rules
from .timeline import build_timeline, normalize_evidence

DEFAULT_RULES_PATH = os.path.join(os.path.dirname(__file__), "rules", "default_rules.json")

DEFAULT_POLICY = {
    "max_hypotheses": 10,
    "min_independent_sources_default": 2,  # per-rule min_independent_sources always takes precedence
    "dedup_window_seconds": 1,
    "clock_skew_threshold_seconds": 5,
}


def run_rca(fixture: dict, rules_path: str = None, policy: dict = None) -> tuple:
    """fixture: {"incident": {...}, "evidence": [...]}. Returns (RcaResult.to_dict(), token_map).
    `token_map` (token -> raw identifier, for target_id/source_id) is NEVER embedded in the
    RcaResult itself — it exists solely so a caller can optionally persist it to a separate,
    access-controlled local file (see cli.py's --token-map), never to the JSON/Markdown/manifest
    artifacts that reach a model or a shared report.
    Raises intake.IntakeError / rules.RulesError / sanitize.SanitizationError on malformed input —
    never proceeds partially. Rules are loaded FIRST because intake's attribute allowlist is
    derived from the rules catalog (PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK
    PREVENTION HARDENING, § 3)."""
    policy = {**DEFAULT_POLICY, **(policy or {})}
    generated_at = datetime.now(timezone.utc).isoformat()

    rules_catalog = load_rules(rules_path or DEFAULT_RULES_PATH)

    intake_result = validate_and_sanitize(fixture, rules_catalog)
    incident = intake_result["incident"]
    incident_id = incident["id"]
    token_map = intake_result["token_map"]

    norm = normalize_evidence(intake_result["evidence"], policy)
    evidence = norm["evidence"]
    validation_issues = [i.to_dict() for i in norm["issues"]]

    timeline = build_timeline(evidence, policy)

    manifest = build_evidence_manifest(incident, intake_result["evidence"])

    gen = generate_hypotheses(incident_id, rules_catalog, evidence, policy)
    hypotheses = apply_evidence_completeness_gate(gen["hypotheses"], manifest)

    root_cause = aggregate_root_cause(incident_id, hypotheses)
    recommendations = build_recommendations(rules_catalog, hypotheses, root_cause)

    evidence_by_id = {e.evidence_id: e for e in evidence}
    domains_involved = cross_domain_domains_involved(hypotheses, evidence_by_id)

    valid_timestamps = [e.timestamp_utc for e in evidence if e.timestamp_utc is not None]
    analysis_origin = max(valid_timestamps) if valid_timestamps else "UNKNOWN"

    limitations = []
    if gen["truncated_rule_ids"]:
        limitations.append(
            f"{len(gen['truncated_rule_ids'])} additional candidate rule(s) matched but were "
            f"truncated by policy.max_hypotheses={policy['max_hypotheses']}: "
            + ", ".join(gen["truncated_rule_ids"])
        )
    if validation_issues:
        limitations.append(
            f"{len(validation_issues)} evidence item(s) excluded from the timeline due to unparseable timestamps."
        )
    if manifest.completeness != "COMPLETE":
        limitations.append(
            f"evidence_manifest completeness={manifest.completeness} — no hypothesis may reach "
            f"CONFIRMED while a declared evidence reference is missing."
        )
    if timeline["degraded"]:
        limitations.append("timeline_confidence degraded — see timeline.degradation_reasons.")
    limitations.append(
        "Synthetic fixture-based deterministic rule evaluation — not a substitute for production "
        "validation or professional DBA judgment."
    )

    result = RcaResult(
        contract_version=CONTRACT_VERSION, engine_version=ENGINE_VERSION,
        rules_version=rules_catalog["rules_version"], incident_id=incident_id,
        target_id=incident["target_id"], analysis_origin=analysis_origin,
        timeline={
            "events": [e.to_dict() for e in timeline["events"]],
            "degraded": timeline["degraded"], "degradation_reasons": timeline["degradation_reasons"],
            "event_count": len(timeline["events"]),
        },
        evidence_manifest=manifest.to_dict(),
        hypotheses=[h.to_dict() for h in hypotheses],
        root_cause=root_cause.to_dict(),
        recommendations=[r.to_dict() for r in recommendations],
        cross_domain_domains_involved=domains_involved,
        validation_issues=validation_issues, limitations=limitations, generated_at=generated_at,
    )
    return result.to_dict(), token_map
