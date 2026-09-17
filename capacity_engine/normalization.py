"""
capacity_engine.normalization — input validation and normalization to the Common Metric Model
(# 4, # 54 del prompt de Fase 10 hardening).

Never silently repairs a physically impossible input (negative used, total<=0, used>total beyond
tolerance) — every such sample is EXCLUDED with a typed ValidationIssue, never clamped or guessed.
"""
from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any, Optional

from .common import (
    NormalizedSample,
    ValidationIssue,
    ValidationErrorType,
    convert_to_bytes,
)

REQUIRED_FIELDS = (
    "target_id", "technology", "resource_type", "metric_name",
    "timestamp", "unit", "source_id", "evidence_id",
)

# Relative tolerance for used > total (floating point evidence noise), never for a genuine
# contradiction — anything beyond this is excluded, never silently clamped to total.
USED_EXCEEDS_TOTAL_TOLERANCE = 0.01

# Relative tolerance between a directly-supplied utilization_percent and one derived from
# used/total, when a sample supplies both — beyond this, both are kept but the sample is not
# treated as fully cross-validated (documented via the returned issue, not an exclusion).
CROSS_CHECK_TOLERANCE = 0.02


def _parse_timestamp(raw: Any) -> Optional[datetime]:
    if not isinstance(raw, str) or not raw:
        return None
    text = raw.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        # Never assume a timezone for a naive timestamp (# 52 del prompt: "timestamp con offset o
        # UTC") — treated as invalid, not silently coerced to UTC.
        return None
    return dt.astimezone(timezone.utc)


def _is_finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def normalize_samples(raw_samples: list, resource_type_hint: Optional[str] = None) -> dict:
    """Validate and normalize a list of raw metric-sample dicts into NormalizedSample objects.

    Returns {"samples": list[NormalizedSample], "issues": list[ValidationIssue],
             "excluded_count": int, "duplicate_count": int}.

    Deduplication policy: exact (target_id, metric_name, timestamp) collisions keep the FIRST
    occurrence in input order — deterministic, documented, never "last wins" silently.
    """
    samples: list = []
    issues: list = []
    seen_keys: dict = {}
    canonical_unit: Optional[str] = None
    canonical_kind: Optional[str] = None  # "bytes" | "cores" | "percentage"

    for idx, raw in enumerate(raw_samples):
        ts_raw = raw.get("timestamp") if isinstance(raw, dict) else None

        missing = [f for f in REQUIRED_FIELDS if not isinstance(raw, dict) or raw.get(f) in (None, "")]
        if missing:
            issues.append(ValidationIssue(
                ValidationErrorType.MISSING_REQUIRED_FIELD.value, idx, ts_raw,
                f"missing required field(s): {', '.join(missing)}",
            ))
            continue

        ts = _parse_timestamp(raw["timestamp"])
        if ts is None:
            issues.append(ValidationIssue(
                ValidationErrorType.INVALID_TIMESTAMP.value, idx, str(raw.get("timestamp")),
                "timestamp missing/unparseable or lacks a UTC offset",
            ))
            continue

        dedup_key = (raw["target_id"], raw["metric_name"], ts.isoformat())
        if dedup_key in seen_keys:
            issues.append(ValidationIssue(
                ValidationErrorType.DUPLICATE_TIMESTAMP.value, idx, ts.isoformat(),
                f"duplicate of sample index {seen_keys[dedup_key]} — kept first occurrence",
            ))
            continue
        seen_keys[dedup_key] = idx

        total = raw.get("total_capacity")
        used = raw.get("used_capacity")
        util_pct = raw.get("utilization_percent")

        if total is None or not _is_finite_number(total) or total <= 0:
            issues.append(ValidationIssue(
                ValidationErrorType.INVALID_CAPACITY_INPUT.value, idx, ts.isoformat(),
                f"total_capacity must be a finite number > 0 (got {total!r})",
            ))
            continue

        if used is None and util_pct is not None:
            if not _is_finite_number(util_pct):
                issues.append(ValidationIssue(
                    ValidationErrorType.NON_FINITE_VALUE.value, idx, ts.isoformat(),
                    "utilization_percent is not a finite number",
                ))
                continue
            used = util_pct / 100.0 * total
        elif used is not None and not _is_finite_number(used):
            issues.append(ValidationIssue(
                ValidationErrorType.NON_FINITE_VALUE.value, idx, ts.isoformat(),
                "used_capacity is not a finite number",
            ))
            continue

        if used is None:
            issues.append(ValidationIssue(
                ValidationErrorType.MISSING_REQUIRED_FIELD.value, idx, ts.isoformat(),
                "neither used_capacity nor utilization_percent provided",
            ))
            continue

        if used < 0:
            issues.append(ValidationIssue(
                ValidationErrorType.NEGATIVE_USED.value, idx, ts.isoformat(),
                f"used_capacity/utilization_percent implies a negative value ({used!r})",
            ))
            continue

        if used > total * (1 + USED_EXCEEDS_TOTAL_TOLERANCE):
            issues.append(ValidationIssue(
                ValidationErrorType.USED_EXCEEDS_TOTAL.value, idx, ts.isoformat(),
                f"used ({used}) exceeds total ({total}) beyond tolerance — never clamped",
            ))
            continue

        unit = str(raw["unit"]).strip()
        rtype = str(raw["resource_type"])
        is_cpu = (resource_type_hint or rtype).lower() == "cpu"

        if is_cpu:
            kind = "percentage" if unit.lower() in ("percentage", "percent", "%") else "cores"
            norm_total, norm_used = total, used
        else:
            kind = "bytes"
            norm_total = convert_to_bytes(total, unit)
            norm_used = convert_to_bytes(used, unit)
            if norm_total is None or norm_used is None:
                issues.append(ValidationIssue(
                    ValidationErrorType.UNIT_MISMATCH.value, idx, ts.isoformat(),
                    f"unknown unit '{unit}' for resource_type '{rtype}' — no conversion factor "
                    "guessed (GB decimal vs GiB binary must be explicit)",
                ))
                continue

        if canonical_kind is None:
            canonical_kind = kind
            canonical_unit = unit
        elif kind != canonical_kind:
            issues.append(ValidationIssue(
                ValidationErrorType.UNIT_MISMATCH.value, idx, ts.isoformat(),
                f"unit kind '{kind}' inconsistent with series canonical kind '{canonical_kind}' "
                f"(established by an earlier sample) — excluded rather than mixed",
            ))
            continue

        computed_util = (norm_used / norm_total * 100.0) if norm_total else None
        if util_pct is not None and used is not None and raw.get("used_capacity") is not None:
            # Both were supplied directly — cross-check, but never fail the sample over it; only
            # exclusion-worthy contradictions already triggered above (used > total).
            if computed_util is not None and _is_finite_number(util_pct):
                rel_diff = abs(computed_util - util_pct) / max(computed_util, util_pct, 1e-9)
                if rel_diff > CROSS_CHECK_TOLERANCE:
                    issues.append(ValidationIssue(
                        "UTILIZATION_CROSS_CHECK_MISMATCH", idx, ts.isoformat(),
                        f"declared utilization_percent ({util_pct}) diverges from used/total "
                        f"({computed_util:.4f}) beyond tolerance — sample kept, flagged",
                    ))

        samples.append(NormalizedSample(
            target_id=raw["target_id"],
            technology=raw["technology"],
            resource_type=rtype,
            metric_name=raw["metric_name"],
            timestamp=ts,
            total_capacity=norm_total,
            used_capacity=norm_used,
            utilization_percent=computed_util,
            unit=CANONICAL_UNIT_LABEL.get(canonical_kind, unit),
            source_id=raw["source_id"],
            evidence_id=raw["evidence_id"],
            raw_index=idx,
        ))

    samples.sort(key=lambda s: s.timestamp)
    duplicate_count = sum(1 for i in issues if i.error_type == ValidationErrorType.DUPLICATE_TIMESTAMP.value)
    return {
        "samples": samples,
        "issues": issues,
        "excluded_count": len(raw_samples) - len(samples),
        "duplicate_count": duplicate_count,
    }


CANONICAL_UNIT_LABEL = {"bytes": "bytes", "cores": "cores", "percentage": "percentage"}
