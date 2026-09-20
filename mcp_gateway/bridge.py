"""
mcp_gateway.bridge — report bridge from gateway evidence to Phase 11 (RCA) and Phase 12 (change advisory,
knowledge candidate state). It reuses the real engines by import:

    sanitized evidence (already stored by the gateway)
      -> rca_engine.engine.run_rca               (Phase 11: hypotheses, contradictions, confidence)
      -> change_documentation_knowledge.schema.adapt_rca_result
      -> change_documentation_knowledge.change.build_change_advisory   (text-only, NOT_EXECUTED_BY_ESTACK)
      -> change_documentation_knowledge.knowledge.build_kb_candidate   (candidate state only — never published)

Only collectors that declare an `rca` mapping in the catalog can contribute. The bridge NEVER receives raw
data, never turns temporal proximity into causality (that is rca_engine's contract), never approves or
publishes anything, and returns short structured states — not documents, not commands.
"""
from __future__ import annotations

from change_documentation_knowledge.change import build_change_advisory
from change_documentation_knowledge.common import AdvisoryError, now_utc
from change_documentation_knowledge.knowledge import build_kb_candidate
from change_documentation_knowledge.schema import adapt_rca_result
from rca_engine.engine import DEFAULT_RULES_PATH, run_rca
from rca_engine.rules import load_rules

from .common import GatewayError


def build_rca_fixture(target_alias: str, items: list) -> dict:
    """items: [(collector, evidence_ref, sanitized_payload)] -> a Phase 11 fixture built ONLY from sanitized
    values. Every free-text field is a fixed string owned by this module."""
    evidence, lineage = [], []
    n = 0
    stamps = []
    for collector, ref, payload in items:
        m = collector.rca
        if not m:
            continue
        for row in payload["rows"]:
            ts = row.get(m["timestamp_field"])
            if ts is None:
                continue
            n += 1
            ev = {"evidence_id": f"EVD-{n}", "domain": m["domain"], "source_id": m["source_id"], "timestamp": ts,
                  "event_type": m["event_type"], "attributes": {}}
            sig_field = m.get("signature_field")
            if sig_field and row.get(sig_field):
                ev["signature"] = row[sig_field]          # certified literal or SIG- token, never raw text
            for attr, field in m.get("attributes", {}).items():
                if field in row:
                    ev["attributes"][attr] = row[field]
            evidence.append(ev)
            lineage.append({"evidence_id": ev["evidence_id"], "evidence_ref": ref, "collector_id": collector.collector_id})
            stamps.append(ts)
    if not evidence:
        raise GatewayError("E_INSUFFICIENT_EVIDENCE")
    day = max(stamps)[:10].replace("-", "")
    fixture = {"incident": {"id": f"INC-{day}-001", "target_id": target_alias,
                            "symptom_description": "incident assembled by the gateway from sanitized collector evidence",
                            "declared_evidence_refs": [e["evidence_id"] for e in evidence]},
               "evidence": evidence}
    return fixture, lineage


def analyze(target_alias: str, items: list) -> dict:
    fixture, lineage = build_rca_fixture(target_alias, items)
    try:
        result, _token_map = run_rca(fixture)          # the token map (raw target id) is discarded, never returned
        rules = load_rules(DEFAULT_RULES_PATH)
        view = adapt_rca_result(result, rules)
        advisory = build_change_advisory(view, None, now_utc())
    except Exception:                                   # fixed code only; nothing from the input is echoed
        raise GatewayError("E_ANALYSIS_FAILED")
    try:
        candidate = build_kb_candidate(view, rules, None, None, now_utc())
    except AdvisoryError:                               # e.g. no hypothesis at all: nothing to curate
        candidate = None
    rc = view["root_cause"]
    return {
        "incident_id": view["incident_id"], "target_token": view["target_id"],
        "rca": {"rca_id": rc["rca_id"], "completeness": rc["completeness"], "authority": "rca_engine (Phase 11)",
                "confirmed_hypothesis_ids": rc["confirmed_hypothesis_ids"], "competing_hypothesis_ids": rc["competing_hypothesis_ids"]},
        "hypotheses": [{"hypothesis_id": h["hypothesis_id"], "status": h["status"], "confidence": h["confidence"],
                        "supporting_evidence_ids": h["supporting_evidence_ids"],
                        "contradicting_evidence_ids": h["contradicting_evidence_ids"],
                        "missing_evidence": h["missing_evidence"]} for h in view["hypotheses"]],
        "recommendations": [{"rec_id": r["rec_id"], "action_summary": r["action_summary"], "requires_change": r["requires_change"],
                             "execution_status": r["execution_status"]} for r in view["recommendations"]],
        "change_advisory": {"advisory_id": advisory["advisory_id"], "readiness": advisory["readiness"],
                            "review_status": advisory["review_status"], "execution_status": advisory["execution_status"],
                            "change_ids": [c["change_id"] for c in advisory["changes"]],
                            "warnings": advisory["warnings"]},
        "knowledge_candidate": ({"lifecycle_state": candidate["lifecycle_state"], "quality_gate": candidate["quality_gate"]["status"],
                                 "blocking_reasons": candidate["quality_gate"]["blocking_reasons"],
                                 "note": "a candidate is not knowledge; publication requires an external human authorization record"}
                                if candidate else {"lifecycle_state": "NOT_APPLICABLE", "quality_gate": "NOT_EVALUATED",
                                                   "blocking_reasons": ["NO_HYPOTHESIS_TO_CURATE"],
                                                   "note": "nothing to curate; nothing is published"}),
        "evidence_lineage": lineage, "warnings": view["warnings"], "limitations": view["limitations"],
    }
