"""
capacity_engine.common — shared enums, dataclasses and the ForecastResult contract.

Field names mirror docs/CAPACITY_FORECASTING_MODEL.md and the forecast_result schema in
PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING_PROMPT.md #8, so the engine's JSON
output is a direct implementation of the already-published contract, not a parallel one.

Python 3 standard library only.
"""
from __future__ import annotations

from dataclasses import dataclass, field, asdict
from datetime import date, datetime
from enum import Enum
from typing import Any, Optional

CONTRACT_VERSION = "1.0.0"
ALGORITHM_VERSION = "capacity_engine.forecast.linear_ols/1.0.0"

# Canonical storage/memory unit: bytes. CPU keeps its own unit (cores or percentage — the two are
# not convertible into each other without an allocated-cores basis, see normalization.py).
CANONICAL_BYTES_UNIT = "bytes"

_BYTE_UNIT_FACTORS = {
    "b": 1, "byte": 1, "bytes": 1,
    "kb": 1_000, "kib": 1024,
    "mb": 1_000_000, "mib": 1024 ** 2,
    "gb": 1_000_000_000, "gib": 1024 ** 3,
    "tb": 1_000_000_000_000, "tib": 1024 ** 4,
}


class DataQualityStatus(str, Enum):
    GOOD = "GOOD"
    ACCEPTABLE = "ACCEPTABLE"
    DEGRADED = "DEGRADED"
    INSUFFICIENT = "INSUFFICIENT"
    INVALID = "INVALID"


class TrendClassification(str, Enum):
    INCREASING = "INCREASING"
    DECREASING = "DECREASING"
    STABLE = "STABLE"
    VOLATILE = "VOLATILE"
    UNKNOWN = "UNKNOWN"


class ConfidenceLevel(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INSUFFICIENT = "INSUFFICIENT"


class ThresholdStatus(str, Enum):
    ALREADY_EXCEEDED = "ALREADY_EXCEEDED"
    DATE_ESTIMATED = "DATE_ESTIMATED"
    NOT_EXPECTED_WITHIN_HORIZON = "NOT_EXPECTED_WITHIN_HORIZON"
    NON_MONOTONIC = "NON_MONOTONIC"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"
    INVALID_THRESHOLD = "INVALID_THRESHOLD"


class HorizonStatus(str, Enum):
    OK = "OK"
    OK_NO_INTERVAL = "OK_NO_INTERVAL"      # point estimate valid, interval NOT_ESTIMABLE
    NOT_ESTIMABLE = "NOT_ESTIMABLE"
    OUT_OF_PHYSICAL_RANGE = "OUT_OF_PHYSICAL_RANGE"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"


class ValidationErrorType(str, Enum):
    INVALID_CAPACITY_INPUT = "INVALID_CAPACITY_INPUT"     # total_capacity <= 0 or non-finite
    NON_FINITE_VALUE = "NON_FINITE_VALUE"
    NEGATIVE_USED = "NEGATIVE_USED"
    INVALID_TIMESTAMP = "INVALID_TIMESTAMP"
    DUPLICATE_TIMESTAMP = "DUPLICATE_TIMESTAMP"
    UNIT_MISMATCH = "UNIT_MISMATCH"
    USED_EXCEEDS_TOTAL = "USED_EXCEEDS_TOTAL"
    MISSING_REQUIRED_FIELD = "MISSING_REQUIRED_FIELD"


@dataclass
class ValidationIssue:
    error_type: str
    index: Optional[int]
    timestamp: Optional[str]
    detail: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class NormalizedSample:
    target_id: str
    technology: str
    resource_type: str
    metric_name: str
    timestamp: datetime           # tz-aware, normalized to UTC
    total_capacity: Optional[float]
    used_capacity: Optional[float]
    utilization_percent: Optional[float]
    unit: str
    source_id: str
    evidence_id: str
    raw_index: int


@dataclass
class CapacityEvent:
    timestamp: str
    resource: str
    event_type: str               # capacity_resize
    old_total: Optional[float]
    new_total: Optional[float]
    source: str
    evidence_id: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class DailyAggregate:
    day: date
    day_offset: int                # integer days since the segment's first day (clean x-axis)
    mean: float
    p95: float
    peak: float
    utilization_mean: Optional[float]
    n_samples: int


@dataclass
class DataQualityResult:
    status: str
    coverage: Optional[float]
    freshness_hours: Optional[float]
    missingness_pct: Optional[float]
    duplicate_count: int
    gap_count: int
    independent_observations: int
    outlier_days: list
    reasons: list

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class TrendResult:
    classification: str
    slope: Optional[float]
    intercept: Optional[float]
    slope_stderr: Optional[float]
    r_squared: Optional[float]
    n: int
    excluded_days: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class HorizonResult:
    date: Optional[str]
    expected: Optional[float]
    lower: Optional[float]
    upper: Optional[float]
    status: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class ThresholdResult:
    resource: str
    threshold_name: str
    threshold_percent: Optional[float]
    status: str
    estimated_date: Optional[str]
    confidence: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class ForecastResult:
    contract_version: str
    algorithm_version: str
    target_id: str
    metric: str
    unit: str
    input_evidence_ids: list
    source_id: str
    history_start: Optional[str]
    history_end: Optional[str]
    sample_count: int
    daily_aggregate_count: int
    data_quality: str
    exclusions: list
    capacity_events: list
    method: str
    method_parameters: dict
    diagnostics: dict
    horizons: dict
    thresholds: list
    confidence: str
    limitations: list
    generated_at: str

    def to_dict(self) -> dict:
        return asdict(self)


def convert_to_bytes(value: float, unit: str) -> Optional[float]:
    """Convert a storage/memory value to canonical bytes. Returns None for an unknown unit —
    never guesses a conversion factor (# 54 del prompt: distinción GB decimal vs GiB binaria)."""
    factor = _BYTE_UNIT_FACTORS.get(unit.strip().lower())
    if factor is None:
        return None
    return value * factor
