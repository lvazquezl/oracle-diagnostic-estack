"""
ADDM text report parser — # 18 of docs/PHASE_3_COMPLETION_HARDENING.md.

Extracts analysis period, finding identifiers, impact, finding description,
recommendation summaries and rationale. Every finding extracted here is
classified EVIDENCE_SOURCE by the caller (skills/performance/addm-analysis)
— never a confirmed root cause; this parser itself makes no causal claim,
it only structures what the ADDM report already states.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from .common import (
    DEFAULT_SIZE_LIMITS,
    ParsedReport,
    ParseStatus,
    sha256_of_text,
    truncate_to_limit,
)

PARSER_VERSION = "1.0.0"

_FINDING_RE = re.compile(
    r"FINDING\s+(\d+):\s*"
    r"([\d.]+)\s*(?:%|percent)\s*impact\s*\(([\d,]+)\s*seconds?\)\s*\n"
    r"(.*?)"
    r"(?=FINDING\s+\d+:|RECOMMENDATION\s+\d+:|\Z)",
    re.IGNORECASE | re.DOTALL,
)

_RECOMMENDATION_RE = re.compile(
    r"RECOMMENDATION\s+(\d+):\s*"
    r"(?:Estimated Benefit is\s*([\d,.]+)\s*(\w+)[^\n]*\n)?"
    r"(.*?)"
    r"(?=RECOMMENDATION\s+\d+:|FINDING\s+\d+:|\Z)",
    re.IGNORECASE | re.DOTALL,
)


def _extract_period(text: str) -> dict[str, str | None]:
    m = re.search(r"Analysis Period:\s*(.+)", text)
    period = m.group(1).strip() if m else None
    m2 = re.search(r"Task Name:\s*(\S+)", text)
    task_name = m2.group(1) if m2 else None
    return {"analysis_period": period, "task_name": task_name}


def _extract_findings(text: str, max_findings: int = 100) -> list[dict[str, object]]:
    findings = []
    for m in _FINDING_RE.finditer(text):
        description_block = m.group(4)
        # The finding's free-text description ends where a nested
        # RECOMMENDATION begins (if any) — keep only the description part.
        description = re.split(r"\n\s*RECOMMENDATION\s+\d+:", description_block)[0]
        findings.append({
            "finding_id": f"ADDM-F{m.group(1)}",
            "impact_pct": m.group(2),
            "impact_seconds": m.group(3).replace(",", ""),
            "description": " ".join(description.split())[:2000],
            "classification": "EVIDENCE_SOURCE",
        })
        if len(findings) >= max_findings:
            break
    return findings


def _extract_recommendations(text: str, max_recs: int = 100) -> list[dict[str, object]]:
    recs = []
    for m in _RECOMMENDATION_RE.finditer(text):
        recs.append({
            "recommendation_id": f"ADDM-R{m.group(1)}",
            "estimated_benefit_value": m.group(2),
            "estimated_benefit_unit": m.group(3),
            "summary": " ".join(m.group(4).split())[:2000],
            "manual_execution_required": True,
        })
        if len(recs) >= max_recs:
            break
    return recs


def parse_addm_text(
    text: str,
    limits=DEFAULT_SIZE_LIMITS,
) -> ParsedReport:
    parse_ts = datetime.now(timezone.utc).isoformat()

    if text is None or text.strip() == "":
        return ParsedReport(
            source_type="ADDM_TEXT", parser_version=PARSER_VERSION,
            detection_confidence="LOW", status=ParseStatus.EMPTY_REPORT.value,
            parse_timestamp=parse_ts,
        )

    truncated_text, was_truncated = truncate_to_limit(text, limits.max_report_size_bytes)
    warnings: list[str] = []
    if was_truncated:
        warnings.append(f"report truncated at {limits.max_report_size_bytes} bytes")
    source_hash = sha256_of_text(text)

    if "ADDM" not in truncated_text and "FINDING" not in truncated_text.upper():
        return ParsedReport(
            source_type="ADDM_TEXT", parser_version=PARSER_VERSION,
            detection_confidence="LOW", status=ParseStatus.MALFORMED_REPORT.value,
            warnings=["no recognizable ADDM report markers found"],
            source_file_hash=source_hash, parse_timestamp=parse_ts,
        )

    metadata = _extract_period(truncated_text)
    findings = _extract_findings(truncated_text)
    recommendations = _extract_recommendations(truncated_text)

    sections = {"findings": findings, "recommendations": recommendations}
    completeness = {
        "findings": "SUPPORTED" if findings else "UNSUPPORTED",
        "recommendations": "SUPPORTED" if recommendations else "UNSUPPORTED",
    }
    sections_extracted = [k for k, v in completeness.items() if v != "UNSUPPORTED"]
    sections_missing = [k for k, v in completeness.items() if v == "UNSUPPORTED"]
    status = ParseStatus.SUCCESS.value if (findings and not sections_missing) else ParseStatus.PARTIAL.value

    return ParsedReport(
        source_type="ADDM_TEXT", parser_version=PARSER_VERSION,
        detection_confidence="MEDIUM", status=status,
        metadata=metadata, sections=sections, warnings=warnings,
        completeness=completeness, sensitivity="MEDIUM",
        sanitization_status="NOT_APPLIED", source_file_hash=source_hash,
        parse_timestamp=parse_ts, sections_extracted=sections_extracted,
        sections_missing=sections_missing,
    )
