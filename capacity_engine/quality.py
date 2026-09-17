"""
capacity_engine.quality — data quality assessment (# 5, # 26-28 del prompt): coverage, freshness,
missingness, gaps, independent-observation count, and robust outlier detection over the daily
aggregate series.

No forecast is ever produced from an INSUFFICIENT/INVALID dataset (enforced by
capacity_engine.engine, not by this module — this module only classifies).
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from .common import DataQualityResult
from .stats import robust_outliers


def assess_quality(
    samples: list,
    aggregates: list,
    policy: dict,
    duplicate_count: int,
    as_of: Optional[datetime] = None,
) -> DataQualityResult:
    """
    policy keys (all optional; a gate is simply not applied when its key is absent — # 65 del
    prompt: "sin valores universales implícitos"):
      minimum_samples          (int, minimum distinct days)
      minimum_history_days     (int, minimum calendar span)
      preferred_history_days   (int, span above which history stops degrading confidence)
      outlier_mad_threshold    (float, default 3.5 — see stats.robust_outliers)
    """
    reasons: list = []

    if not aggregates:
        return DataQualityResult(
            status="INVALID", coverage=None, freshness_hours=None, missingness_pct=None,
            duplicate_count=duplicate_count, gap_count=0, independent_observations=0,
            outlier_days=[], reasons=["no valid samples after normalization"],
        )

    distinct_days = len(aggregates)
    span_days = (aggregates[-1].day - aggregates[0].day).days + 1
    coverage = distinct_days / span_days if span_days > 0 else None
    missingness_pct = (1.0 - coverage) * 100.0 if coverage is not None else None
    gap_count = span_days - distinct_days

    freshness_hours = None
    if as_of is not None:
        last_ts = datetime.combine(aggregates[-1].day, datetime.min.time(), tzinfo=timezone.utc)
        freshness_hours = max(0.0, (as_of - last_ts).total_seconds() / 3600.0)

    outlier_threshold = policy.get("outlier_mad_threshold", 3.5)
    outlier_idx = robust_outliers([a.mean for a in aggregates], threshold=outlier_threshold)
    outlier_days = [aggregates[i].day.isoformat() for i in outlier_idx]

    min_samples = policy.get("minimum_samples")
    min_history_days = policy.get("minimum_history_days")
    preferred_history_days = policy.get("preferred_history_days")

    insufficient = False
    if min_samples is not None and distinct_days < min_samples:
        insufficient = True
        reasons.append(f"distinct_days ({distinct_days}) below minimum_samples ({min_samples})")
    if min_history_days is not None and span_days < min_history_days:
        insufficient = True
        reasons.append(f"span_days ({span_days}) below minimum_history_days ({min_history_days})")

    if insufficient:
        status = "INSUFFICIENT"
    else:
        outlier_ratio = len(outlier_idx) / distinct_days if distinct_days else 0.0
        degraded = duplicate_count > 0 or (coverage is not None and coverage < 0.5) or outlier_ratio > 0.2
        if degraded:
            status = "DEGRADED"
            if duplicate_count > 0:
                reasons.append(f"{duplicate_count} duplicate sample(s) excluded")
            if coverage is not None and coverage < 0.5:
                reasons.append(f"coverage {coverage:.2f} below 0.5")
            if outlier_ratio > 0.2:
                reasons.append(f"outlier ratio {outlier_ratio:.2f} above 0.2")
        elif preferred_history_days is not None and span_days < preferred_history_days:
            status = "ACCEPTABLE"
            reasons.append(f"span_days ({span_days}) below preferred_history_days ({preferred_history_days})")
        else:
            status = "GOOD"

    return DataQualityResult(
        status=status,
        coverage=coverage,
        freshness_hours=freshness_hours,
        missingness_pct=missingness_pct,
        duplicate_count=duplicate_count,
        gap_count=gap_count,
        independent_observations=distinct_days,
        outlier_days=outlier_days,
        reasons=reasons,
    )
