"""
Report type detector — # 15 REPORT TYPE DETECTION.

Never trusts a file extension alone. Looks at content signatures. If no
signature matches confidently, returns UNKNOWN — callers must not attempt
parsing against an UNKNOWN result (no arbitrary/best-effort parsing).
"""

from __future__ import annotations

from .common import ReportSourceType

_AWR_HTML_MARKERS = ("WORKLOAD REPOSITORY", "awr_report", "AWR Report")
_AWR_TEXT_MARKERS = ("WORKLOAD REPOSITORY report for", "Snap Id", "DB Time(s):")
_STATSPACK_MARKERS = ("STATSPACK REPORT", "Instance Efficiency Percentages", "Top 5 Timed Events")
_ADDM_MARKERS = ("ADDM Report", "FINDING", "TASK_NAME", "ADDM analysis")
_EXECPLAN_MARKERS = ("Plan hash value", "Execution Plan", "| Id  | Operation")


def detect_report_type(text: str) -> tuple[ReportSourceType, str]:
    """Return (source_type, detection_confidence). Signature-based, ordered
    from most to least specific to avoid a generic marker (e.g. 'Snap Id',
    shared by AWR and Statspack) misclassifying a report."""
    if text is None or text.strip() == "":
        return ReportSourceType.UNKNOWN, "LOW"

    head = text[:20000]  # signatures live near the top of real reports; bound the scan
    lower = head.lower()

    is_html = "<html" in lower or "<!doctype html" in lower

    if is_html and any(m.lower() in lower for m in _AWR_HTML_MARKERS):
        return ReportSourceType.AWR_HTML, "HIGH"

    # Execution plans are the most distinctively-shaped text — check before
    # the broader AWR/Statspack text markers to avoid a plan snippet embedded
    # in a larger report being misclassified.
    if _looks_like_execution_plan(head):
        return ReportSourceType.EXECUTION_PLAN_TEXT, "HIGH"

    if any(m in head for m in _ADDM_MARKERS) and "addm" in lower:
        return ReportSourceType.ADDM_TEXT, "MEDIUM"

    if any(m in head for m in _STATSPACK_MARKERS):
        return ReportSourceType.STATSPACK_TEXT, "HIGH"

    if any(m in head for m in _AWR_TEXT_MARKERS) and not is_html:
        return ReportSourceType.AWR_TEXT, "MEDIUM"

    if is_html:
        # HTML but none of our known AWR markers — do not guess.
        return ReportSourceType.UNKNOWN, "LOW"

    return ReportSourceType.UNKNOWN, "LOW"


def _looks_like_execution_plan(head: str) -> bool:
    has_plan_hash = "Plan hash value" in head
    has_plan_table = "| Id  |" in head or "|   Id" in head or "Execution Plan" in head
    has_operation_col = "Operation" in head and ("Cost" in head or "Rows" in head)
    return (has_plan_hash and has_plan_table) or (has_plan_table and has_operation_col)
