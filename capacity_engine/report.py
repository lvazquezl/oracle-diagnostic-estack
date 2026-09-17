"""
capacity_engine.report — renders a ForecastResult (or a list of them) as the Markdown table
described in docs/CAPACITY_REPORTING_MODEL.md#capacity-table:

  Resource | Current | 1M | 3M | 6M | Threshold Date | Risk | Confidence

This is the end-to-end demonstration artifact required by # 9 del prompt: fixture -> engine ->
structured result -> Markdown report with values coming from the engine, never hardcoded.
"""
from __future__ import annotations

from .common import ForecastResult


def _fmt(v, decimals: int = 2) -> str:
    if v is None:
        return "—"
    if isinstance(v, float):
        return f"{v:,.{decimals}f}"
    return str(v)


def render_capacity_table(results: list) -> str:
    lines = [
        "| Resource | Current | 1M | 3M | 6M | Threshold Date | Risk | Confidence |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for r in results:
        current = r.diagnostics.get("trend", {}).get("n") and _current_value(r)
        h1 = r.horizons.get("1m", {})
        h3 = r.horizons.get("3m", {})
        h6 = r.horizons.get("6m", {})
        threshold_date = _first_threshold_date(r)
        risk = _risk_label(r)
        lines.append(
            f"| {r.target_id} / {r.metric} | {_fmt(current)} {r.unit} "
            f"| {_fmt(h1.get('expected'))} ({h1.get('status')}) "
            f"| {_fmt(h3.get('expected'))} ({h3.get('status')}) "
            f"| {_fmt(h6.get('expected'))} ({h6.get('status')}) "
            f"| {threshold_date or '—'} | {risk} | {r.confidence} |"
        )
    return "\n".join(lines)


def _current_value(r: ForecastResult):
    slope = r.method_parameters.get("slope")
    intercept = r.method_parameters.get("intercept")
    trend = r.diagnostics.get("trend", {})
    n = trend.get("n")
    if slope is None or intercept is None or not n:
        return None
    span = r.diagnostics.get("segment_span_days", 1)
    x_end = max(span - 1, 0)
    return intercept + slope * x_end


def _first_threshold_date(r: ForecastResult):
    for t in r.thresholds:
        if t.get("status") == "DATE_ESTIMATED":
            return t.get("estimated_date")
        if t.get("status") == "ALREADY_EXCEEDED":
            return "ALREADY_EXCEEDED"
    return None


def _risk_label(r: ForecastResult) -> str:
    if r.data_quality in ("INSUFFICIENT", "INVALID"):
        return "UNKNOWN"
    for t in r.thresholds:
        if t.get("status") == "ALREADY_EXCEEDED":
            return "CRITICAL"
        if t.get("status") == "DATE_ESTIMATED":
            return "HIGH"
    if any(h.get("status") == "OUT_OF_PHYSICAL_RANGE" for h in r.horizons.values()):
        return "WARNING"
    return "HEALTHY" if r.diagnostics.get("trend", {}).get("classification") != "VOLATILE" else "WATCH"


def render_full_report(results: list, scope_label: str = "capacity assessment") -> str:
    parts = [f"# Capacity Report — {scope_label}", "", "## Capacity table", "",
              render_capacity_table(results), ""]
    for r in results:
        parts.append(f"## {r.target_id} / {r.metric}")
        parts.append("")
        parts.append(f"- data_quality: `{r.data_quality}`")
        parts.append(f"- method: `{r.method}`  (algorithm_version: `{r.algorithm_version}`)")
        parts.append(f"- confidence: `{r.confidence}`")
        if r.limitations:
            parts.append("- limitations:")
            for lim in r.limitations:
                parts.append(f"  - {lim}")
        parts.append("")
    return "\n".join(parts)
