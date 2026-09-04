"""
Local report ingest orchestrator — # 14 REPORT INGEST ARCHITECTURE.

    FILE -> TYPE DETECTOR -> LOCAL PARSER -> STRUCTURED REPORT -> SANITIZER
         -> EVIDENCE -> SKILL -> AGENT

`ingest_report()` is the only function callers (skills) should use — it
runs the type detector first and refuses to guess a parser for content the
detector could not classify (UNKNOWN_REPORT_TYPE), matching # 15's "no
intentar parsing arbitrario" rule.

# 22 PARSER SECURITY
------------------------------------------------------------------------
Every byte of a report file is DATA, never instructions. This module and
every parser it calls:
  - never calls eval(), exec(), compile(), or any subprocess/shell function
    on report content;
  - never treats a string extracted from a report (SQL text, comments,
    module names, ADDM text, plan text, predicates) as something to
    interpret or act on — it is stored/returned as an opaque string field,
    full stop;
  - strips/escapes report content before it is ever concatenated into any
    log message or downstream prompt, so a report engineered to contain
    text like "ignore previous instructions" is rendered as inert
    `sections`/`warnings` payload, never as directives.
This is verified by tests/test_parser_does_not_execute_embedded_instructions.sh.
"""

from __future__ import annotations

from .addm_parser import parse_addm_text
from .awr_parser import parse_awr
from .common import DEFAULT_SIZE_LIMITS, ParsedReport, ParseStatus, ReportSourceType
from .execution_plan_parser import parse_execution_plan_text
from .statspack_parser import parse_statspack_text
from .type_detector import detect_report_type


def ingest_report(text: str, limits=None, sanitize: bool = True) -> ParsedReport:
    limits = limits or DEFAULT_SIZE_LIMITS

    if text is None or text.strip() == "":
        return ParsedReport(
            source_type=ReportSourceType.UNKNOWN.value,
            parser_version="ingest-1.0.0",
            detection_confidence="LOW",
            status=ParseStatus.EMPTY_REPORT.value,
        )

    source_type, confidence = detect_report_type(text)

    if source_type == ReportSourceType.AWR_HTML:
        return parse_awr(text, is_html=True, limits=limits, sanitize=sanitize)
    if source_type == ReportSourceType.AWR_TEXT:
        return parse_awr(text, is_html=False, limits=limits, sanitize=sanitize)
    if source_type == ReportSourceType.STATSPACK_TEXT:
        return parse_statspack_text(text, limits=limits, sanitize=sanitize)
    if source_type == ReportSourceType.ADDM_TEXT:
        return parse_addm_text(text, limits=limits)
    if source_type == ReportSourceType.EXECUTION_PLAN_TEXT:
        return parse_execution_plan_text(text, limits=limits, sanitize=sanitize)

    # UNKNOWN — never guess a parser for unclassified content (# 15).
    return ParsedReport(
        source_type=ReportSourceType.UNKNOWN.value,
        parser_version="ingest-1.0.0",
        detection_confidence=confidence,
        status=ParseStatus.UNKNOWN_REPORT_TYPE.value,
        warnings=["report type could not be determined from content signatures; no parser was invoked"],
    )
