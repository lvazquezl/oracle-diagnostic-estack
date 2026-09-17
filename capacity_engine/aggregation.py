"""
capacity_engine.aggregation — deterministic daily aggregation over a (segmented) sample series
(# 5 del prompt: "normalización temporal y agregación diaria configurada (media y, donde proceda,
p95/peak; no usar promedio simple sobre muestreo irregular sin ponderación o justificación)").

Design note: regression (capacity_engine.trend/forecast) fits over the resulting DAILY series
using an integer day_offset x-axis — one point per calendar day — rather than over raw, possibly
irregularly-sampled timestamps directly. This is the "ponderación/justificación" the prompt asks
for: each day contributes exactly one representative value (its mean) regardless of how many raw
samples landed in it, so a day with 50 samples never outweighs a day with 1 in the fit.
"""
from __future__ import annotations

import statistics
from datetime import timedelta, timezone
from typing import Optional

from .common import DailyAggregate


def _percentile_95(values: list) -> float:
    if len(values) == 1:
        return values[0]
    # statistics.quantiles needs n>=2; method="inclusive" matches the common percentile
    # definition used elsewhere in this project's docs (p95/p99 of CPU/latency).
    qs = statistics.quantiles(values, n=100, method="inclusive")
    return qs[94]


def aggregate_daily(samples: list, tz_offset_minutes: int = 0) -> list:
    """Group normalized samples (already segmented) into one DailyAggregate per calendar day, in
    the timezone described by tz_offset_minutes (default UTC — # 29 del prompt de Fase 10:
    "todas las series deben normalizar timezone"). day_offset is an integer count of days since
    the first day present, forming the clean, uniformly-spaced x-axis the regression needs.
    """
    if not samples:
        return []

    offset = timedelta(minutes=tz_offset_minutes)
    buckets: dict = {}
    for s in samples:
        local_dt = s.timestamp + offset
        day = local_dt.date()
        buckets.setdefault(day, []).append(s)

    days_sorted = sorted(buckets.keys())
    first_day = days_sorted[0]
    aggregates: list = []
    for day in days_sorted:
        day_samples = buckets[day]
        used_values = [s.used_capacity for s in day_samples]
        util_values = [s.utilization_percent for s in day_samples if s.utilization_percent is not None]
        aggregates.append(DailyAggregate(
            day=day,
            day_offset=(day - first_day).days,
            mean=statistics.fmean(used_values),
            p95=_percentile_95(sorted(used_values)),
            peak=max(used_values),
            utilization_mean=(statistics.fmean(util_values) if util_values else None),
            n_samples=len(day_samples),
        ))
    return aggregates
