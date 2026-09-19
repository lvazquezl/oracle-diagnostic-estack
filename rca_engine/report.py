"""
rca_engine.report — renders an RcaResult (see engine.run_rca) as a human-readable Markdown RCA
report. Every value in the report is read directly from the RcaResult dict — never recomputed or
hardcoded — so JSON and Markdown structurally cannot disagree on cause, confidence, contradictions,
impact or references (test_rca_json_markdown_consistency).
"""
from __future__ import annotations


def _fmt_list(items: list) -> str:
    return ", ".join(items) if items else "—"


def render_rca_report(result: dict) -> str:
    lines = [
        f"# RCA Report — {result['incident_id']}",
        "",
        f"- `rca_id`: `{result['root_cause']['rca_id']}`",
        f"- `target_id`: `{result['target_id']}`",
        f"- `contract_version`: `{result['contract_version']}`  ·  "
        f"`engine_version`: `{result['engine_version']}`  ·  `rules_version`: `{result['rules_version']}`",
        f"- `analysis_origin` (deterministic anchor, never wall-clock): `{result['analysis_origin']}`",
        f"- `generated_at` (audit metadata only): `{result['generated_at']}`",
        "",
        "## Root cause",
        "",
        f"- **completeness**: `{result['root_cause']['completeness']}`",
        f"- **confirmed_hypothesis_ids**: {_fmt_list(result['root_cause']['confirmed_hypothesis_ids'])}",
        f"- **competing_hypothesis_ids**: {_fmt_list(result['root_cause']['competing_hypothesis_ids'])}",
        f"- **reasoning**: {result['root_cause']['reasoning']}",
        "",
        "## Hypotheses",
        "",
        "| hypothesis_id | status | confidence | supporting | contradicting | independent_sources | temporal_proof |",
        "|---|---|---|---|---|---|---|",
    ]
    for h in result["hypotheses"]:
        lines.append(
            f"| {h['hypothesis_id']} | {h['status']} | {h['confidence']} "
            f"| {_fmt_list(h['supporting_evidence_ids'])} | {_fmt_list(h['contradicting_evidence_ids'])} "
            f"| {h['independent_source_count']} | {h['temporal_proof']} |"
        )
    lines.append("")

    for h in result["hypotheses"]:
        lines.append(f"### {h['hypothesis_id']} — {h['rule_id']}")
        lines.append("")
        lines.append(h["statement"])
        lines.append("")
        lines.append("Causal chain: " + " → ".join(h["causal_chain"]))
        if h["missing_evidence"]:
            lines.append("")
            lines.append("Missing evidence:")
            for m in h["missing_evidence"]:
                lines.append(f"- {m}")
        lines.append("")

    lines.append("## Evidence manifest")
    lines.append("")
    em = result["evidence_manifest"]
    lines.append(f"- completeness: `{em['completeness']}`")
    lines.append(f"- declared_refs: {_fmt_list(em['declared_refs'])}")
    lines.append(f"- missing_refs: {_fmt_list(em['missing_refs'])}")
    lines.append("")

    lines.append("## Timeline")
    lines.append("")
    lines.append(f"- timeline_confidence: `{'DEGRADED' if result['timeline']['degraded'] else 'NORMAL'}`")
    if result["timeline"]["degradation_reasons"]:
        lines.append("- degradation_reasons:")
        for r in result["timeline"]["degradation_reasons"]:
            lines.append(f"  - {r}")
    lines.append("")
    lines.append("| timestamp_utc | domain | event_type | signature_status | canonical_signature | signature_token | count | evidence_ids |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for e in result["timeline"]["events"]:
        # canonical_signature is only ever non-null when signature_status == CERTIFIED; otherwise
        # only the opaque signature_token is shown — never the raw text, by construction (PHASE 11
        # — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING).
        lines.append(
            f"| {e['timestamp_utc']} | {e['domain']} | {e['event_type']} | {e['signature_status']} "
            f"| {e['canonical_signature'] or '—'} | {e['signature_token'] or '—'} "
            f"| {e['count']} | {_fmt_list(e['evidence_ids'])} |"
        )
    lines.append("")

    lines.append("## Cross-domain evidence reuse")
    lines.append("")
    lines.append(_fmt_list(result["cross_domain_domains_involved"]))
    lines.append("")

    lines.append("## Manual remediation (NOT_EXECUTED — human execution required)")
    lines.append("")
    if not result["recommendations"]:
        lines.append("No recommendations — root cause not CONFIRMED.")
    else:
        for rec in result["recommendations"]:
            lines.append(f"### {rec['rec_id']} (linked to {rec['linked_to']})")
            lines.append("")
            lines.append(f"- action: {rec['action_summary']}")
            lines.append(f"- precheck: {rec['precheck']}")
            lines.append(f"- risk: {rec['risk']}")
            lines.append(f"- postcheck: {rec['postcheck']}")
            lines.append(f"- requires_change: {rec['requires_change']}")
            lines.append(f"- execution_status: `{rec['execution_status']}`")
            lines.append("")

    if result["limitations"]:
        lines.append("## Limitations")
        lines.append("")
        for lim in result["limitations"]:
            lines.append(f"- {lim}")
        lines.append("")

    return "\n".join(lines)
