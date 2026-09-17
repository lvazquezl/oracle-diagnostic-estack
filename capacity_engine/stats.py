"""
capacity_engine.stats — pure-stdlib statistics: OLS regression, prediction intervals, calendar
month arithmetic and robust outlier detection. No numpy/scipy (# 18 del prompt de Fase 10
hardening: preferir stdlib).

Interval method note (# 76, #8 del prompt): prediction intervals use the NORMAL approximation to
the Student-t distribution (z=1.96 for ~95%), not an exact Student-t quantile — there is no
scipy/statistics.NormalDist-free t-table in the stdlib. This is documented explicitly wherever an
interval is produced, and callers must treat small-n intervals (n<=2: not estimable at all) with
the corresponding limitation. This is a conscious, disclosed simplification, never presented as an
exact statistical guarantee.
"""
from __future__ import annotations

import math
import statistics
from datetime import date, timedelta
from typing import Optional

# ~95% two-sided normal quantile — see module docstring for why this is an approximation.
Z_95 = 1.959963985


def ols_fit(xs: list, ys: list) -> dict:
    """Ordinary least squares fit y = intercept + slope * x.

    Raises ValueError if fewer than 2 points, or if x has zero variance (cannot fit a line
    through a single x value) — never silently returns a fabricated fit.
    """
    n = len(xs)
    if n != len(ys):
        raise ValueError("xs and ys length mismatch")
    if n < 2:
        raise ValueError("at least 2 points required for OLS")

    x_mean = sum(xs) / n
    y_mean = sum(ys) / n
    sxx = sum((x - x_mean) ** 2 for x in xs)
    sxy = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, ys))
    if sxx == 0:
        raise ValueError("no variance in x — cannot fit a trend line")

    slope = sxy / sxx
    intercept = y_mean - slope * x_mean
    ss_tot = sum((y - y_mean) ** 2 for y in ys)
    ss_res = sum((y - (intercept + slope * x)) ** 2 for x, y in zip(xs, ys))
    r_squared = 1.0 if ss_tot == 0 else max(0.0, 1.0 - ss_res / ss_tot)

    if n > 2:
        residual_var = ss_res / (n - 2)
        residual_std = math.sqrt(max(0.0, residual_var))
        slope_stderr = math.sqrt(residual_var / sxx) if sxx > 0 else None
    else:
        residual_std = 0.0
        slope_stderr = None

    return {
        "slope": slope,
        "intercept": intercept,
        "r_squared": r_squared,
        "ss_res": ss_res,
        "ss_tot": ss_tot,
        "n": n,
        "x_mean": x_mean,
        "sxx": sxx,
        "slope_stderr": slope_stderr,
        "residual_std": residual_std,
    }


def predict(fit: dict, x0: float) -> float:
    return fit["intercept"] + fit["slope"] * x0


def prediction_interval(fit: dict, x0: float, z: float = Z_95) -> Optional[tuple]:
    """95% prediction interval for a NEW observation at x0 (normal approximation — see module
    docstring). Returns None when not mathematically estimable (n <= 2, no residual d.o.f.)."""
    n = fit["n"]
    if n <= 2 or fit["slope_stderr"] is None:
        return None
    residual_std = fit["residual_std"]
    sxx = fit["sxx"]
    x_mean = fit["x_mean"]
    se_pred = residual_std * math.sqrt(1.0 + 1.0 / n + ((x0 - x_mean) ** 2) / sxx)
    expected = predict(fit, x0)
    return expected - z * se_pred, expected + z * se_pred


def add_calendar_months(d: date, months: int) -> date:
    """Add `months` calendar months to date d, clamping the day to the last valid day of the
    target month (Jan 31 + 1 month -> Feb 28, or Feb 29 in a leap year) — # 148 del prompt
    (sección 5, "Calendar" test case)."""
    month_index = d.month - 1 + months
    year = d.year + month_index // 12
    month = month_index % 12 + 1
    last_day = _last_day_of_month(year, month)
    day = min(d.day, last_day)
    return date(year, month, day)


def _last_day_of_month(year: int, month: int) -> int:
    if month == 12:
        next_month_first = date(year + 1, 1, 1)
    else:
        next_month_first = date(year, month + 1, 1)
    return (next_month_first - timedelta(days=1)).day


def robust_outliers(values: list, threshold: float = 3.5) -> list:
    """Median-Absolute-Deviation based robust outlier detection (Iglewicz & Hoaglin modified
    z-score, a standard robust rule — never a simple stdev z-score, which is itself skewed by the
    outliers it's trying to detect). Returns the list of indices flagged as outliers.

    threshold=3.5 is the commonly used default for this rule; callers may override via policy —
    never a silently hardcoded universal value (# 65 del prompt: "sin valores universales
    implícitos" se documenta explícitamente aquí como default configurable, no forzado).
    """
    n = len(values)
    if n < 4:
        return []
    med = statistics.median(values)
    abs_devs = [abs(v - med) for v in values]
    mad = statistics.median(abs_devs)
    if mad == 0:
        # Fall back to mean absolute deviation when MAD collapses to zero (e.g. a series with
        # more than half identical values) — never divide by zero, never silently skip detection.
        mad = sum(abs_devs) / n
        if mad == 0:
            return []
    modified_z = [0.6745 * d / mad for d in abs_devs]
    return [i for i, z in enumerate(modified_z) if z > threshold]
