"""
capacity_engine.trend — OLS fit over the daily aggregate series and heuristic trend
classification (INCREASING/DECREASING/STABLE/VOLATILE/UNKNOWN).

Classification rule (documented, not a formal hypothesis test — # 32, # 80 del prompt: "no
equipares confianza directamente a R2 o a una probabilidad de acierto"):
  n < 2                          -> UNKNOWN (cannot fit a line)
  n == 2                         -> sign of slope alone (no residual d.o.f. to test significance);
                                     flagged as low-reliability via TrendResult.n == 2 downstream
  n > 2, |slope| > 2*SE(slope)   -> INCREASING or DECREASING depending on sign
  n > 2, |slope| <= 2*SE(slope)  -> STABLE, unless residual noise is large relative to the
                                     series' own range, in which case -> VOLATILE
2*SE is a fixed ~95%-ish two-sided heuristic multiplier, not a claim of exact statistical
significance at any particular p-value.
"""
from __future__ import annotations

from typing import Optional

from .common import TrendResult
from .stats import ols_fit, robust_outliers

VOLATILITY_RESIDUAL_RATIO = 0.15  # residual_std / series_range beyond which a flat slope reads as
                                    # noisy (VOLATILE) rather than genuinely STABLE.


def fit_trend(aggregates: list, exclude_outliers: bool = True, outlier_mad_threshold: float = 3.5,
              value_fn=lambda a: a.mean) -> tuple:
    """Fit a daily series (by default the daily mean, `value_fn` lets callers fit e.g. the
    utilization_percent series for threshold-crossing instead) and classify its trend.

    Returns (TrendResult, fit_dict_or_None). fit_dict is the raw capacity_engine.stats.ols_fit()
    output (needed by forecast.py to compute horizon predictions/intervals), or None when a fit
    could not be produced (n < 2).
    """
    n_total = len(aggregates)
    if n_total < 2:
        return TrendResult(
            classification="UNKNOWN", slope=None, intercept=None, slope_stderr=None,
            r_squared=None, n=n_total, excluded_days=[],
        ), None

    ys_all = [value_fn(a) for a in aggregates]
    excluded_days: list = []
    if exclude_outliers:
        outlier_idx = set(robust_outliers(ys_all, threshold=outlier_mad_threshold))
    else:
        outlier_idx = set()

    fit_aggregates = [a for i, a in enumerate(aggregates) if i not in outlier_idx]
    excluded_days = [aggregates[i].day.isoformat() for i in sorted(outlier_idx)]

    # Never fit on fewer than 2 points even after exclusion — if excluding outliers would leave
    # too little to fit, fall back to fitting on the full series and only REPORT the outliers,
    # never silently drop below the minimum viable fit.
    if len(fit_aggregates) < 2:
        fit_aggregates = aggregates
        excluded_days = []

    xs = [a.day_offset for a in fit_aggregates]
    ys = [value_fn(a) for a in fit_aggregates]
    fit = ols_fit(xs, ys)
    n = fit["n"]

    if n == 2:
        eps = 1e-12
        if fit["slope"] > eps:
            classification = "INCREASING"
        elif fit["slope"] < -eps:
            classification = "DECREASING"
        else:
            classification = "STABLE"
    else:
        se = fit["slope_stderr"] or 0.0
        significant = abs(fit["slope"]) > 2 * se
        if significant:
            classification = "INCREASING" if fit["slope"] > 0 else "DECREASING"
        else:
            y_range = max(ys) - min(ys)
            residual_std = fit["residual_std"]
            if y_range > 0 and (residual_std / y_range) > VOLATILITY_RESIDUAL_RATIO:
                classification = "VOLATILE"
            else:
                classification = "STABLE"

    result = TrendResult(
        classification=classification,
        slope=fit["slope"],
        intercept=fit["intercept"],
        slope_stderr=fit["slope_stderr"],
        r_squared=fit["r_squared"],
        n=n,
        excluded_days=excluded_days,
    )
    return result, fit
