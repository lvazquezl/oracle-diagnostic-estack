"""
capacity_engine.threshold — threshold-crossing date estimation (# 7 del prompt).

Always operates on the utilization_percent daily series (never a raw absolute series), and only
under a STABLE denominator — the segmentation step (capacity_engine.segmentation) already ensures
total_capacity is constant within the analyzed segment, which is exactly the "denominador estable"
precondition the prompt requires before converting percentage <-> used/total.

CPU semantics (# 46 del prompt, section 78): this function computes a threshold-crossing DATE for
a sustained-utilization trend — it never computes or exposes a "days until exhausted"/saturation
concept. Callers must not label a CPU ThresholdResult as an exhaustion date; the caller-facing
limitation text enforcing that lives in capacity_engine.engine.
"""
from __future__ import annotations

import math
from datetime import timedelta
from typing import Optional

from .common import ThresholdResult
from .stats import ols_fit, predict

MAX_HORIZON_DAYS = 6 * 31  # generous calendar-month upper bound for "within horizon"


def evaluate_threshold(
    resource: str,
    threshold_name: str,
    threshold_percent: Optional[float],
    util_fit: Optional[dict],
    trend_classification: str,
    current_utilization: Optional[float],
    x_end: int,
    history_end_day,
    data_quality_status: str,
    confidence: str,
) -> ThresholdResult:
    if threshold_percent is None or not (0 < threshold_percent <= 100):
        return ThresholdResult(resource, threshold_name, threshold_percent, "INVALID_THRESHOLD", None, confidence)

    if data_quality_status in ("INSUFFICIENT", "INVALID"):
        return ThresholdResult(resource, threshold_name, threshold_percent, "INSUFFICIENT_EVIDENCE", None, confidence)

    if current_utilization is not None and current_utilization >= threshold_percent:
        return ThresholdResult(resource, threshold_name, threshold_percent, "ALREADY_EXCEEDED", None, confidence)

    if util_fit is None or trend_classification in ("UNKNOWN",):
        return ThresholdResult(resource, threshold_name, threshold_percent, "INSUFFICIENT_EVIDENCE", None, confidence)

    if trend_classification == "VOLATILE":
        return ThresholdResult(resource, threshold_name, threshold_percent, "NON_MONOTONIC", None, confidence)

    slope = util_fit["slope"]
    if slope <= 1e-9:
        return ThresholdResult(resource, threshold_name, threshold_percent, "NOT_EXPECTED_WITHIN_HORIZON", None, confidence)

    x_cross = (threshold_percent - util_fit["intercept"]) / slope
    days_until = x_cross - x_end

    if days_until <= 0:
        # The fitted line already implies the threshold was crossed at/(before) the last
        # observed point, even though the raw current_utilization reading was under it (noise) —
        # treat as already effectively exceeded rather than fabricating a past date.
        return ThresholdResult(resource, threshold_name, threshold_percent, "ALREADY_EXCEEDED", None, confidence)

    if days_until > MAX_HORIZON_DAYS:
        return ThresholdResult(resource, threshold_name, threshold_percent, "NOT_EXPECTED_WITHIN_HORIZON", None, confidence)

    estimated_date = (history_end_day + timedelta(days=round(days_until))).isoformat()
    return ThresholdResult(resource, threshold_name, threshold_percent, "DATE_ESTIMATED", estimated_date, confidence)
