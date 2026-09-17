"""
capacity_engine.segmentation — capacity change (resize) detection and time-series segmentation
(# 5, # 67 del prompt: "eventos de resize/cambio de denominador: crear segmentos y evaluar ventana
posterior; si el segmento es insuficiente, emitir INSUFFICIENT_HISTORY, no mezclar a ciegas épocas
incompatibles").

Detection only — this module never executes or recommends a resize, it only recognizes that one
already happened in the evidence (a `total_capacity` step change) and segments around it.
"""
from __future__ import annotations

from typing import Optional

from .common import CapacityEvent, NormalizedSample

# Relative change in total_capacity between consecutive samples of the same series considered a
# genuine capacity_resize event, not floating point/collector noise — configurable in spirit
# (# 65 del prompt: "sin valores universales implícitos"), documented default here.
RESIZE_RELATIVE_EPSILON = 0.005


def detect_capacity_events(samples: list, source: str = "capacity_engine") -> list:
    """Detect total_capacity step changes across a chronologically sorted sample list of ONE
    series (same target_id/metric_name). Returns a list[CapacityEvent]."""
    events: list = []
    if not samples:
        return events
    prev = samples[0]
    for cur in samples[1:]:
        if prev.total_capacity and cur.total_capacity:
            rel_change = abs(cur.total_capacity - prev.total_capacity) / prev.total_capacity
            if rel_change > RESIZE_RELATIVE_EPSILON:
                events.append(CapacityEvent(
                    timestamp=cur.timestamp.isoformat(),
                    resource=cur.resource_type,
                    event_type="capacity_resize",
                    old_total=prev.total_capacity,
                    new_total=cur.total_capacity,
                    source=source,
                    evidence_id=cur.evidence_id,
                ))
        prev = cur
    return events


def segment_after_last_event(samples: list, events: list) -> list:
    """Return only the samples at/after the LAST detected capacity_event — # 51/67 del prompt:
    "usar preferentemente los datos posteriores al último cambio estructural", never blending
    pre/post-resize totals as one continuous series. With no events, returns all samples
    unchanged."""
    if not events:
        return list(samples)
    last_event_ts = events[-1].timestamp
    return [s for s in samples if s.timestamp.isoformat() >= last_event_ts]
