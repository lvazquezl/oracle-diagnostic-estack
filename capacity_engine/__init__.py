"""
capacity_engine — local, deterministic capacity forecasting engine.

PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING. Closes the gap between the
declarative contracts of skills/capacity/* (Common Metric Model, forecasting, threshold-crossing,
data-quality) and a real, testable statistical engine.

READ-ONLY ALWAYS. This package never connects to Oracle/OS/VMware/SQL Server/any network resource
and never executes SQL/shell. It operates exclusively on metric samples already collected by
another specialist (evidence_by_reference — see agents/capacity-analyst/manifest.yaml) or on local
fixtures for testing. All math is local/deterministic; no LLM, no MCP, no clock read implicitly
(the forecast origin is the last valid sample timestamp, never wall-clock "now" — see
run_capacity_forecast()).

Python 3 standard library only — no external dependencies (numpy/scipy/pandas not used), matching
the existing convention of parsers/*/common.py.
"""
from __future__ import annotations

from .common import CONTRACT_VERSION, ALGORITHM_VERSION, ForecastResult
from .engine import run_capacity_forecast
from .reconciliation import reconcile_daily_series

__all__ = [
    "CONTRACT_VERSION", "ALGORITHM_VERSION", "ForecastResult", "run_capacity_forecast",
    "reconcile_daily_series",
]
