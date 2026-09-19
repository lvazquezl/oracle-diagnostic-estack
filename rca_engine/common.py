"""
rca_engine.common — shared enums, dataclasses and version constants.

Field names mirror docs/INCIDENT_ROOT_CAUSE_MODEL.md, docs/INCIDENT_HYPOTHESIS_MODEL.md and
docs/INCIDENT_TIMELINE_MODEL.md, so the engine's JSON output is a direct implementation of the
already-published declarative contracts (skills/incident/*), not a parallel one. Same pattern as
capacity_engine.common for capacity/*.

Python 3 standard library only.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field, asdict
from typing import Any, Optional

CONTRACT_VERSION = "1.0.0"
ENGINE_VERSION = "rca_engine.rules_engine/1.0.0"


class HypothesisStatus:
    OPEN = "OPEN"
    SUPPORTED = "SUPPORTED"
    WEAKENED = "WEAKENED"
    REJECTED = "REJECTED"
    CONFIRMED = "CONFIRMED"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"


class RootCauseCompleteness:
    CONFIRMED = "CONFIRMED"
    PROBABLE = "PROBABLE"
    INCONCLUSIVE = "INCONCLUSIVE"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"


class ConfidenceLevel:
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INSUFFICIENT = "INSUFFICIENT"


class TimelineConfidence:
    NORMAL = "NORMAL"
    DEGRADED = "TIMELINE_CONFIDENCE_DEGRADED"


class EvidenceManifestCompleteness:
    COMPLETE = "COMPLETE"
    INCOMPLETE_REFS = "INCOMPLETE_REFS"


class SignatureStatus:
    """PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING: a signature
    matching a generic shape (uppercase/digits/underscores) is NEVER, by itself, proof that its
    content is safe to report — see sanitize.classify_signature(). Only CERTIFIED signatures ever
    surface a literal value (`canonical_signature`); everything else correlates via an opaque,
    non-reversible `signature_token`, never the raw text."""
    CERTIFIED = "CERTIFIED"
    UNRECOGNIZED_SIGNATURE = "UNRECOGNIZED_SIGNATURE"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"


# Event types that are eligible to satisfy a rule's supporting/contradicting conditions. RECOVERY
# events are deliberately excluded — a mitigation/recovery action restoring service must never by
# itself become evidence that confirms the cause it mitigated (docs/INCIDENT_CAUSALITY_MODEL.md
# #recovery-action--root-cause, section 4.6/4.8 del prompt de hardening). RECOVERY events are still
# parsed, timestamped, deduped and reported in the timeline — only excluded from causal matching.
CAUSAL_ELIGIBLE_EVENT_TYPES = frozenset({
    "SYMPTOM_OBSERVED", "ALERT_TRIGGERED", "CONFIG_CHANGE", "CAPACITY_EVENT", "INVESTIGATION_STEP",
})
ALL_EVENT_TYPES = CAUSAL_ELIGIBLE_EVENT_TYPES | {"RECOVERY"}

# Fixed, known domain vocabulary — the same 11 domains the declarative incident/* skills correlate
# against (skills/incident/*-correlation). `domain` is a controlled structural field, never free
# text: any value outside this set is rejected (fail-closed), never redacted-and-kept, because rule
# matching itself keys off this exact value (rules.py compares `evidence.domain == cond["domain"]`).
ALLOWED_DOMAINS = frozenset({
    "oracle", "os", "rac", "asm", "dataguard", "multitenant", "rman", "network", "security",
    "capacity", "performance",
})

# Safe shape for evidence_id/incident.id — a structural traceability identifier, never tokenized
# (tokenizing would break literal EVD-.../INC-... references throughout the declarative contracts
# and the INC->EVD->FND->HYP->RCA->REC->CHG chain) but validated against a safe identifier shape —
# rejected (fail-closed, no echo) if it doesn't match, so a secret-shaped value can never be
# accepted as an identifier even though it is not tokenized.
SAFE_IDENTIFIER_SHAPE = re.compile(r'^[A-Za-z][A-Za-z0-9._-]{0,63}$')


@dataclass
class ValidationIssue:
    error_type: str
    path: str
    detail: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class NormalizedEvidence:
    evidence_id: str
    domain: str
    source_id: str
    event_type: str
    timestamp_utc: Optional[str]          # ISO-8601 UTC, None if unparseable
    source_timestamp: str                  # original string, always preserved verbatim
    signature_status: str                  # CERTIFIED | UNRECOGNIZED_SIGNATURE | INSUFFICIENT_EVIDENCE
    canonical_signature: Optional[str]     # set ONLY when signature_status == CERTIFIED — safe to report
    signature_token: Optional[str]         # opaque, non-reversible, incident-scoped — set when NOT CERTIFIED
    summary: Optional[str]                 # sanitized before this point
    attributes: dict
    timeline_degraded: bool
    degradation_reason: Optional[str]
    raw_index: int
    # NOTE: the raw signature string is deliberately NOT a field here — it is transient, local to
    # intake.py's ingestion perimeter only, and is discarded immediately after classification (see
    # sanitize.classify_signature()). It must never reach this (or any other serializable) object.

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class TimelineEvent:
    event_key: str                         # stable dedup key, deterministic
    domain: str
    event_type: str
    signature_status: str
    canonical_signature: Optional[str]
    signature_token: Optional[str]
    timestamp_utc: Optional[str]
    count: int
    first_seen: Optional[str]
    last_seen: Optional[str]
    evidence_ids: list
    source_ids: list
    timeline_degraded: bool

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class EvidenceManifest:
    declared_refs: list
    present_refs: list
    missing_refs: list
    completeness: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Hypothesis:
    hypothesis_id: str
    rule_id: str
    domain: str
    statement: str
    causal_chain: list
    status: str
    supporting_evidence_ids: list
    contradicting_evidence_ids: list
    unresolved_critical_contradiction: bool
    missing_evidence: list
    independent_source_count: int
    temporal_proof: bool
    confidence: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class RootCauseResult:
    rca_id: str
    completeness: str
    confirmed_hypothesis_ids: list
    competing_hypothesis_ids: list
    reasoning: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Recommendation:
    rec_id: str
    linked_to: str
    action_summary: str
    precheck: str
    risk: str
    postcheck: str
    requires_change: bool
    execution_status: str = field(default="NOT_EXECUTED")

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class RcaResult:
    contract_version: str
    engine_version: str
    rules_version: str
    incident_id: str
    target_id: str
    analysis_origin: str                    # deterministic anchor (max evidence ts used), never wall-clock
    timeline: dict
    evidence_manifest: dict
    hypotheses: list
    root_cause: dict
    recommendations: list
    cross_domain_domains_involved: list
    validation_issues: list
    limitations: list
    generated_at: str                       # wall-clock audit metadata only — excluded from reproducibility diff

    def to_dict(self) -> dict:
        return asdict(self)
