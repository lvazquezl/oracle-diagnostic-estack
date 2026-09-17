"""
capacity_engine.reconciliation — multi-source conflict detection (# 5, # 10 del prompt: "dos
fuentes discrepantes; prohibir promedio ciego").

This module never averages two sources together. It pairs same-day readings from two already-
normalized series and reports, per day, whether they agree within tolerance or conflict — the
caller (capacity_engine.engine / a capacity/* skill) decides which source to prefer, this module
only detects and reports the discrepancy.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Optional


@dataclass
class SourceConflict:
    day: str
    source_a: str
    value_a: float
    source_b: str
    value_b: float
    relative_diff: float
    status: str   # RECONCILED | SOURCE_CONFLICT

    def to_dict(self) -> dict:
        return asdict(self)


def reconcile_daily_series(aggregates_a: list, source_a: str, aggregates_b: list, source_b: str,
                            tolerance: float = 0.05, preferred_source: Optional[str] = None) -> dict:
    """Pair DailyAggregate entries (by calendar day) from two sources and flag conflicts —
    NEVER computes or returns a blended/averaged value.

    Returns {"conflicts": list[SourceConflict.to_dict()], "reconciled_days": int,
             "conflict_days": int, "preferred_source": preferred_source or source_a,
             "blind_average_used": False}.
    """
    by_day_a = {a.day: a.mean for a in aggregates_a}
    by_day_b = {b.day: b.mean for b in aggregates_b}
    common_days = sorted(set(by_day_a) & set(by_day_b))

    results = []
    conflict_days = 0
    for day in common_days:
        va, vb = by_day_a[day], by_day_b[day]
        denom = max(abs(va), abs(vb), 1e-9)
        rel_diff = abs(va - vb) / denom
        status = "SOURCE_CONFLICT" if rel_diff > tolerance else "RECONCILED"
        if status == "SOURCE_CONFLICT":
            conflict_days += 1
        results.append(SourceConflict(day.isoformat(), source_a, va, source_b, vb, rel_diff, status).to_dict())

    return {
        "conflicts": results,
        "reconciled_days": len(common_days) - conflict_days,
        "conflict_days": conflict_days,
        "preferred_source": preferred_source or source_a,
        "blind_average_used": False,
    }
