"""
capacity_engine.engine — orchestrates the full local pipeline (# 3 del prompt):

  input local de métricas
    -> validación de esquema / unidades / tiempo         (normalization.py)
    -> control de calidad y cobertura                     (quality.py)
    -> segmentación por cambios de capacidad               (segmentation.py)
    -> agregación temporal determinista                    (aggregation.py)
    -> estadísticas / tendencia                            (trend.py)
    -> selección de método con reglas trazables             (this module)
    -> forecast a 1/3/6 meses                               (this module, via stats.py)
    -> intervalos e indicadores de confianza                (this module, via stats.py)
    -> umbrales / fechas de cruce                           (threshold.py)
    -> resultado estructurado + evidencia + limitaciones     (ForecastResult)

Determinism: the forecast origin is ALWAYS `history_end` (the last valid sample timestamp), never
wall-clock time. `as_of` may be injected explicitly for freshness/audit purposes only — it never
feeds into the regression or horizon dates. `generated_at` is real-clock audit metadata and MUST be
excluded when comparing two runs for reproducibility (see tests/test_forecast_reproducible_same_input.sh).
"""
from __future__ import annotations

from datetime import datetime, timezone

from .common import (
    CONTRACT_VERSION, ALGORITHM_VERSION, ForecastResult, HorizonResult,
)
from .normalization import normalize_samples
from .segmentation import detect_capacity_events, segment_after_last_event
from .aggregation import aggregate_daily
from .quality import assess_quality
from .trend import fit_trend
from .threshold import evaluate_threshold
from .stats import predict, prediction_interval, add_calendar_months

HORIZON_MONTHS = {"1m": 1, "3m": 3, "6m": 6}

DEFAULT_POLICY = {
    # Recommended, non-universal defaults — always overridable via the `policy` argument
    # (# 65 del prompt: "sin valores universales implícitos"; # 25 de la fase declarativa previa:
    # "ejemplo recomendado, NO universal").
    "minimum_samples": 30,
    "minimum_history_days": 30,
    "preferred_history_days": 90,
    "outlier_mad_threshold": 3.5,
    "aggregation_timezone_offset_minutes": 0,
}


def _extrapolation_ratio(fit: dict, x_end: int, target_x: int, span_days: int) -> float:
    horizon_days = target_x - x_end
    return horizon_days / span_days if span_days > 0 else float("inf")


def _compute_confidence(data_quality_status: str, trend_classification: str, n: int,
                         fit: dict, policy: dict, span_days: int, x_end: int) -> str:
    if data_quality_status in ("INSUFFICIENT", "INVALID"):
        return "INSUFFICIENT"
    if trend_classification == "UNKNOWN":
        return "INSUFFICIENT"

    preferred = policy.get("preferred_history_days")
    if trend_classification == "VOLATILE" or (preferred is not None and span_days < preferred):
        return "LOW"

    target_x_6m = x_end + 183  # ~6 calendar months, used as the conservative anchor horizon
    ratio_6m = _extrapolation_ratio(fit, x_end, target_x_6m, span_days)
    if ratio_6m > 1.0:
        # Never grant HIGH confidence to a forecast that extrapolates further than the history
        # itself spans, no matter how good the historical fit looks (# 80 del prompt).
        return "LOW" if ratio_6m > 2.0 else "MEDIUM"

    r2 = fit.get("r_squared")
    se = fit.get("slope_stderr")
    slope = fit.get("slope", 0.0)
    well_fit = r2 is not None and r2 >= 0.7 and (se is None or abs(slope) > 3 * se)
    if well_fit and ratio_6m <= 0.5:
        return "HIGH"
    return "MEDIUM"


def _horizon_result(fit: dict, x_end: int, x0: int, target_date, total_capacity, is_percent: bool) -> HorizonResult:
    expected = predict(fit, x0)
    interval = prediction_interval(fit, x0)
    lower, upper = (interval if interval else (None, None))
    status = "OK" if interval else "OK_NO_INTERVAL"

    def _out_of_range(v):
        if v is None:
            return False
        if v < 0:
            return True
        if is_percent and v > 100:
            return True
        if total_capacity is not None and v > total_capacity:
            return True
        return False

    if _out_of_range(expected) or _out_of_range(lower) or _out_of_range(upper):
        status = "OUT_OF_PHYSICAL_RANGE"

    return HorizonResult(
        date=target_date.isoformat(), expected=expected, lower=lower, upper=upper, status=status,
    )


def run_capacity_forecast(raw_samples: list, policy: dict = None, thresholds: dict = None,
                            as_of: str = None, resource_type_hint: str = None) -> ForecastResult:
    """Run the full local capacity forecasting pipeline over a list of raw metric-sample dicts.

    raw_samples: list of dicts with target_id/technology/resource_type/metric_name/timestamp/
                 total_capacity/used_capacity(or utilization_percent)/unit/source_id/evidence_id.
    policy:      see DEFAULT_POLICY — merged over the defaults, never silently replacing an
                 explicit caller value.
    thresholds:  {"warning_percent": .., "critical_percent": .., "emergency_percent": ..} or any
                 subset/superset of named percent thresholds.
    as_of:       ISO-8601 timestamp used ONLY for freshness/audit metadata — never affects the
                 regression or horizon dates (those originate at history_end).
    """
    policy = {**DEFAULT_POLICY, **(policy or {})}
    thresholds = thresholds or {}
    generated_at = datetime.now(timezone.utc).isoformat()

    norm = normalize_samples(raw_samples, resource_type_hint=resource_type_hint)
    samples = norm["samples"]
    issues = norm["issues"]

    if not samples:
        return ForecastResult(
            contract_version=CONTRACT_VERSION, algorithm_version=ALGORITHM_VERSION,
            target_id=(raw_samples[0].get("target_id") if raw_samples else "UNKNOWN"),
            metric="unknown", unit="unknown", input_evidence_ids=[], source_id="unknown",
            history_start=None, history_end=None, sample_count=0, daily_aggregate_count=0,
            data_quality="INVALID", exclusions=[i.to_dict() for i in issues], capacity_events=[],
            method="NONE", method_parameters={}, diagnostics={"reason": "no valid samples after normalization"},
            horizons={k: HorizonResult(None, None, None, None, "INSUFFICIENT_EVIDENCE").to_dict() for k in HORIZON_MONTHS},
            thresholds=[], confidence="INSUFFICIENT",
            limitations=["No valid samples after normalization — see exclusions."],
            generated_at=generated_at,
        )

    target_id = samples[0].target_id
    metric_name = samples[0].metric_name
    unit = samples[0].unit
    resource_type = samples[0].resource_type
    source_id = samples[0].source_id
    evidence_ids = sorted({s.evidence_id for s in samples})

    events = detect_capacity_events(samples, source="capacity_engine")
    segment = segment_after_last_event(samples, events)

    tz_offset = policy.get("aggregation_timezone_offset_minutes", 0)
    aggregates = aggregate_daily(segment, tz_offset_minutes=tz_offset)

    as_of_dt = None
    if as_of:
        as_of_dt = datetime.fromisoformat(as_of.replace("Z", "+00:00"))
        if as_of_dt.tzinfo is None:
            as_of_dt = as_of_dt.replace(tzinfo=timezone.utc)

    quality = assess_quality(segment, aggregates, policy, duplicate_count=norm["duplicate_count"], as_of=as_of_dt)

    limitations: list = []
    if events:
        limitations.append(
            f"{len(events)} capacity_resize event(s) detected — series segmented, only data at/after "
            f"the last resize ({events[-1].timestamp}) was used for trend/forecast."
        )
    if resource_type.lower() == "cpu":
        limitations.append(
            "resource_type=cpu: thresholds/horizons reflect a conditional sustained-utilization "
            "trend projection, never an 'exhaustion date' — CPU is a utilization metric, not an "
            "accumulated resource."
        )

    history_start = segment[0].timestamp.isoformat() if segment else None
    history_end = segment[-1].timestamp.isoformat() if segment else None

    if quality.status in ("INSUFFICIENT", "INVALID"):
        limitations.append(f"data_quality={quality.status}: {'; '.join(quality.reasons) or 'insufficient evidence'}")
        empty_thresholds = [
            evaluate_threshold(resource_type, name, pct, None, "UNKNOWN", None, 0,
                                aggregates[-1].day if aggregates else None, quality.status, "INSUFFICIENT")
            for name, pct in thresholds.items()
        ]
        return ForecastResult(
            contract_version=CONTRACT_VERSION, algorithm_version=ALGORITHM_VERSION,
            target_id=target_id, metric=metric_name, unit=unit, input_evidence_ids=evidence_ids,
            source_id=source_id, history_start=history_start, history_end=history_end,
            sample_count=len(segment), daily_aggregate_count=len(aggregates),
            data_quality=quality.status, exclusions=[i.to_dict() for i in issues],
            capacity_events=[e.to_dict() for e in events],
            method="INSUFFICIENT_HISTORY", method_parameters={},
            diagnostics={"data_quality": quality.to_dict()},
            horizons={k: HorizonResult(None, None, None, None, "INSUFFICIENT_EVIDENCE").to_dict() for k in HORIZON_MONTHS},
            thresholds=[t.to_dict() for t in empty_thresholds],
            confidence="INSUFFICIENT", limitations=limitations, generated_at=generated_at,
        )

    outlier_threshold = policy.get("outlier_mad_threshold", 3.5)
    trend_result, fit = fit_trend(aggregates, outlier_mad_threshold=outlier_threshold)
    if trend_result.excluded_days:
        limitations.append(
            f"{len(trend_result.excluded_days)} outlier day(s) excluded from the fit via MAD "
            f"rule (threshold={outlier_threshold}): {', '.join(trend_result.excluded_days)}"
        )
    if quality.outlier_days:
        limitations.append(f"outlier day(s) detected by data-quality assessment: {', '.join(quality.outlier_days)}")

    is_percent = unit == "percentage"
    total_capacity = segment[-1].total_capacity

    if fit is None:
        horizons = {k: HorizonResult(None, None, None, None, "NOT_ESTIMABLE").to_dict() for k in HORIZON_MONTHS}
        confidence = "INSUFFICIENT"
        method = "NONE"
        method_params = {}
    else:
        method = "linear_regression"
        method_params = {
            "slope": fit["slope"], "intercept": fit["intercept"], "r_squared": fit["r_squared"],
            "n": fit["n"], "interval_method": "normal_approximation_z95",
        }
        x_end = aggregates[-1].day_offset
        span_days = (aggregates[-1].day - aggregates[0].day).days + 1
        confidence = _compute_confidence(quality.status, trend_result.classification, len(aggregates),
                                          fit, policy, span_days, x_end)
        horizons = {}
        for key, months in HORIZON_MONTHS.items():
            target_date = add_calendar_months(aggregates[-1].day, months)
            x0 = x_end + (target_date - aggregates[-1].day).days
            if trend_result.classification == "UNKNOWN":
                horizons[key] = HorizonResult(target_date.isoformat(), None, None, None, "NOT_ESTIMABLE").to_dict()
            else:
                horizons[key] = _horizon_result(fit, x_end, x0, target_date, total_capacity, is_percent).to_dict()

    util_fit = None
    util_trend = trend_result
    if fit is not None:
        util_trend, util_fit = fit_trend(aggregates, outlier_mad_threshold=outlier_threshold,
                                          value_fn=lambda a: a.utilization_mean)

    current_utilization = aggregates[-1].utilization_mean if aggregates else None
    x_end_for_threshold = aggregates[-1].day_offset if aggregates else 0
    threshold_results = [
        evaluate_threshold(
            resource_type, name, pct, util_fit,
            util_trend.classification if util_fit else "UNKNOWN",
            current_utilization, x_end_for_threshold, aggregates[-1].day if aggregates else None,
            quality.status, confidence,
        )
        for name, pct in thresholds.items()
    ]

    diagnostics = {
        "data_quality": quality.to_dict(),
        "trend": trend_result.to_dict(),
        "utilization_trend": util_trend.to_dict() if fit is not None else None,
        "segment_span_days": (aggregates[-1].day - aggregates[0].day).days + 1 if aggregates else 0,
        "regression_note": "OLS on daily mean aggregate; x = integer day offset from segment start.",
        "interval_note": "prediction interval uses a normal approximation (z=1.96) to the "
                          "Student-t distribution, not an exact t-quantile (no scipy dependency).",
    }

    return ForecastResult(
        contract_version=CONTRACT_VERSION, algorithm_version=ALGORITHM_VERSION,
        target_id=target_id, metric=metric_name, unit=unit, input_evidence_ids=evidence_ids,
        source_id=source_id, history_start=history_start, history_end=history_end,
        sample_count=len(segment), daily_aggregate_count=len(aggregates),
        data_quality=quality.status, exclusions=[i.to_dict() for i in issues],
        capacity_events=[e.to_dict() for e in events],
        method=method, method_parameters=method_params, diagnostics=diagnostics,
        horizons=horizons, thresholds=[t.to_dict() for t in threshold_results],
        confidence=confidence, limitations=limitations, generated_at=generated_at,
    )
