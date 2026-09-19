"""
rca_engine.timeline — timestamp normalization, event ordering and deduplication.

Implements docs/INCIDENT_TIMELINE_MODEL.md in executable form:
  - timestamps with an explicit offset are normalized to UTC; `source_timestamp` (the original
    string) is always preserved.
  - a timestamp with no explicit offset is never silently assumed to be UTC with full confidence —
    it is normalized as UTC but the evidence item (and the whole timeline) is marked
    TIMELINE_CONFIDENCE_DEGRADED, never presented as equally reliable to an offset-aware timestamp.
  - an unparseable timestamp is never guessed — the item is excluded from ordering/dedup and
    surfaced as a validation issue (INVALID_TIMESTAMP), consistent with intake rejecting malformed
    input rather than inventing a time.
  - an explicit per-source clock_skew_seconds beyond policy['clock_skew_threshold_seconds'] flags
    every evidence item from that source as degraded — clock skew is detected and reported, never
    silently "corrected" (docs/INCIDENT_TIMELINE_MODEL.md#clock-skew).
  - deduplication groups evidence by (source_id, domain, event_type, signature-group-key, timestamp
    rounded to policy['dedup_window_seconds']) and preserves count/first_seen/last_seen/
    evidence_ids — provenance is never discarded. The signature-group-key is NEVER the raw text
    (see _signature_group_key(): canonical_signature when CERTIFIED, else the opaque
    signature_token — PHASE 11 RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING).

Python 3 standard library only.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from .common import NormalizedEvidence, SignatureStatus, TimelineEvent, ValidationIssue

DEFAULT_DEDUP_WINDOW_SECONDS = 1
DEFAULT_CLOCK_SKEW_THRESHOLD_SECONDS = 5


def _parse_timestamp(raw: str):
    """Returns (utc_datetime_or_None, had_explicit_offset: bool). Never guesses a timezone for a
    naive timestamp — the caller decides how to flag that (TIMELINE_CONFIDENCE_DEGRADED)."""
    if not raw or not isinstance(raw, str):
        return None, False
    text = raw.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None, False
    had_offset = dt.tzinfo is not None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc), had_offset


def normalize_evidence(raw_evidence: list, policy: dict) -> dict:
    """raw_evidence: list of already-sanitized, schema-validated evidence dicts (see intake.py).
    Returns {"evidence": [NormalizedEvidence...], "issues": [ValidationIssue...]}.
    """
    clock_skew_threshold = policy.get("clock_skew_threshold_seconds", DEFAULT_CLOCK_SKEW_THRESHOLD_SECONDS)

    # Pass 1: determine which source_ids exceed the clock-skew threshold — every evidence item
    # from that source is degraded, regardless of its own individual timestamp quality.
    skewed_sources = set()
    for item in raw_evidence:
        skew = item.get("attributes", {}).get("source_clock_offset_seconds")
        if isinstance(skew, (int, float)) and abs(skew) > clock_skew_threshold:
            skewed_sources.add(item["source_id"])

    normalized = []
    issues = []
    for idx, item in enumerate(raw_evidence):
        utc_dt, had_offset = _parse_timestamp(item["timestamp"])
        degraded = False
        reason = None
        if utc_dt is None:
            issues.append(ValidationIssue(
                error_type="INVALID_TIMESTAMP", path=f"evidence[{idx}].timestamp",
                detail=f"unparseable timestamp: {item['timestamp']!r}",
            ))
        else:
            if not had_offset:
                degraded = True
                reason = "naive timestamp without explicit UTC offset — normalized as UTC but degraded"
            if item["source_id"] in skewed_sources:
                degraded = True
                reason = ("clock skew detected for this source beyond threshold — timeline confidence "
                          "degraded, timestamp never silently corrected"
                          if reason is None else reason + "; source clock skew also detected")

        normalized.append(NormalizedEvidence(
            evidence_id=item["evidence_id"], domain=item["domain"], source_id=item["source_id"],
            event_type=item["event_type"],
            timestamp_utc=utc_dt.isoformat() if utc_dt is not None else None,
            source_timestamp=item["timestamp"],
            signature_status=item.get("signature_status", SignatureStatus.INSUFFICIENT_EVIDENCE),
            canonical_signature=item.get("canonical_signature"),
            signature_token=item.get("signature_token"),
            summary=item.get("summary"), attributes=item.get("attributes", {}),
            timeline_degraded=degraded, degradation_reason=reason, raw_index=idx,
        ))

    return {"evidence": normalized, "issues": issues}


def _signature_group_key(e: NormalizedEvidence) -> Optional[str]:
    """Grouping/dedup key for signature — NEVER the raw text. A CERTIFIED signature groups by its
    canonical_signature (safe, known-safe value); an UNRECOGNIZED one groups by its opaque
    signature_token (same raw text -> same token -> still groups together, without ever exposing
    the raw text as — or within — a serializable key). PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT
    LEAK PREVENTION MICRO-HARDENING."""
    if e.signature_status == SignatureStatus.CERTIFIED:
        return e.canonical_signature
    return e.signature_token


def _dedup_key(e: NormalizedEvidence, window_seconds: int) -> Optional[tuple]:
    if e.timestamp_utc is None:
        return None
    dt = datetime.fromisoformat(e.timestamp_utc)
    bucket = int(dt.timestamp() // window_seconds) if window_seconds > 0 else int(dt.timestamp())
    return (e.source_id, e.domain, e.event_type, _signature_group_key(e), bucket)


def build_timeline(evidence: list, policy: dict) -> dict:
    """Orders evidence chronologically (stable: ties broken by original raw_index) and deduplicates
    events sharing the same (source, domain, event_type, signature) within `dedup_window_seconds`.
    Evidence with no parseable timestamp is excluded from the ordered timeline but never discarded
    from evidence_manifest — the caller keeps the full evidence list separately.

    Returns {"events": [TimelineEvent...], "degraded": bool, "degradation_reasons": [str, ...]}.
    """
    window = policy.get("dedup_window_seconds", DEFAULT_DEDUP_WINDOW_SECONDS)
    timed = [e for e in evidence if e.timestamp_utc is not None]
    # Stable sort: Python's sort is guaranteed stable, and raw_index is the tie-break for equal
    # timestamps — deterministic ordering for the same input, every run.
    timed.sort(key=lambda e: (e.timestamp_utc, e.raw_index))

    groups: dict = {}
    order: list = []
    for e in timed:
        key = _dedup_key(e, window)
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(e)

    events = []
    for key in order:
        members = groups[key]
        first = members[0]
        timestamps = [m.timestamp_utc for m in members]
        events.append(TimelineEvent(
            event_key="|".join(str(k) for k in key),
            domain=first.domain, event_type=first.event_type,
            signature_status=first.signature_status, canonical_signature=first.canonical_signature,
            signature_token=first.signature_token,
            timestamp_utc=first.timestamp_utc, count=len(members),
            first_seen=min(timestamps), last_seen=max(timestamps),
            evidence_ids=sorted({m.evidence_id for m in members}),
            source_ids=sorted({m.source_id for m in members}),
            timeline_degraded=any(m.timeline_degraded for m in members),
        ))

    degraded = any(e.timeline_degraded for e in evidence)
    reasons = sorted({e.degradation_reason for e in evidence if e.degradation_reason})
    return {"events": events, "degraded": degraded, "degradation_reasons": reasons}
