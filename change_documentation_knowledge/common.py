"""
change_documentation_knowledge.common — shared constants, enums, stable error codes and digest
helpers for Phase 12 (Change Advisory, Documentation & Knowledge Lifecycle).

This package CONSUMES the Phase 11 `rca_engine` public API (sanitizer, tokenizer, rules loader,
RcaResult JSON contract). It never re-implements RCA, sanitization or tokenization.

Invariants enforced by the code in this package (and asserted by tests/test_p12_*.sh):
  * READ-ONLY / HUMAN-EXECUTED REMEDIATION ONLY — no module here imports subprocess/socket/
    urllib/http/ctypes/os.system/os.popen; nothing ever runs a command, SQL, MCP action or RMAN.
  * `execution_status` of every change artifact is the immutable constant NOT_EXECUTED_BY_ESTACK.
  * No approval / publication path exists inside the engine other than verifying an EXTERNALLY
    provided human authorization record (see knowledge.verify_authorization). There is no
    `--approve`, `--auto-publish`, `--force-publish` flag, and no environment-variable approval.
  * The engine never runs git and never creates a tag, merge, push or commit.

Python 3 standard library only.
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone

SCHEMA_VERSION = "1.0.0"
ENGINE_VERSION = "change_documentation_knowledge/1.0.0"
GENERATOR_VERSION = ENGINE_VERSION
SUPPORTED_RCA_CONTRACT_VERSIONS = frozenset({"1.0.0"})

EXECUTION_STATUS_NOT_EXECUTED = "NOT_EXECUTED_BY_ESTACK"
EXECUTION_STATUS_HUMAN_REPORTED = "HUMAN_REPORTED_UNVERIFIED"


class Epistemic:
    OBSERVED = "observed"
    INFERRED = "inferred"
    PROPOSED = "proposed"
    UNKNOWN = "unknown"
    NOT_APPLICABLE = "not_applicable"
    NOT_VERIFIED = "not_verified"
    HUMAN_REPORTED = "human_reported"

    ALL = frozenset({OBSERVED, INFERRED, PROPOSED, UNKNOWN, NOT_APPLICABLE, NOT_VERIFIED, HUMAN_REPORTED})


class ChangeType:
    OPERATIONAL_MANUAL = "OPERATIONAL_MANUAL"
    ESTACK_DEVELOPMENT = "ESTACK_DEVELOPMENT"
    ALL = frozenset({OPERATIONAL_MANUAL, ESTACK_DEVELOPMENT})


class ChangeStatus:
    DRAFT = "DRAFT"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    APPROVED_BY_HUMAN = "APPROVED_BY_HUMAN"   # only from a verifiable EXTERNAL declaration
    REJECTED = "REJECTED"
    SUPERSEDED = "SUPERSEDED"
    ALL = frozenset({DRAFT, REVIEW_REQUIRED, APPROVED_BY_HUMAN, REJECTED, SUPERSEDED})


class GateStatus:
    """UNKNOWN is never NOT_APPLICABLE: an unconfirmed gate blocks readiness, a truly
    not-applicable one does not."""
    PASS = "PASS"
    FAIL = "FAIL"
    UNKNOWN = "UNKNOWN"
    NOT_APPLICABLE = "NOT_APPLICABLE"
    NOT_VERIFIED = "NOT_VERIFIED"
    ALL = frozenset({PASS, FAIL, UNKNOWN, NOT_APPLICABLE, NOT_VERIFIED})
    NON_BLOCKING = frozenset({PASS, NOT_APPLICABLE})


class Readiness:
    BLOCKED = "BLOCKED"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    READY_FOR_HUMAN_REVIEW = "READY_FOR_HUMAN_REVIEW"


class KbState:
    CANDIDATE = "CANDIDATE"
    DRAFT = "DRAFT"
    PENDING_HUMAN_REVIEW = "PENDING_HUMAN_REVIEW"
    APPROVED_BY_HUMAN = "APPROVED_BY_HUMAN"
    PUBLISHED = "PUBLISHED"
    REJECTED = "REJECTED"
    REVIEW_DUE = "REVIEW_DUE"
    DEPRECATED = "DEPRECATED"
    RETIRED = "RETIRED"
    SUPERSEDED = "SUPERSEDED"
    ALL = frozenset({CANDIDATE, DRAFT, PENDING_HUMAN_REVIEW, APPROVED_BY_HUMAN, PUBLISHED, REJECTED,
                     REVIEW_DUE, DEPRECATED, RETIRED, SUPERSEDED})
    # Only these are ever surfaced as *current guidance* by retrieval (default).
    CURRENT_GUIDANCE = frozenset({PUBLISHED, REVIEW_DUE})


# Allowed lifecycle transitions. Anything not listed is an illegal transition (E_TRANSITION_DENIED).
# Transitions in HUMAN_DECISION_TRANSITIONS additionally require a matching external authorization
# record (decision + artifact_digest + version) — see knowledge.verify_authorization.
KB_TRANSITIONS = {
    KbState.CANDIDATE: frozenset({KbState.DRAFT, KbState.REJECTED}),
    KbState.DRAFT: frozenset({KbState.PENDING_HUMAN_REVIEW, KbState.REJECTED}),
    KbState.PENDING_HUMAN_REVIEW: frozenset({KbState.APPROVED_BY_HUMAN, KbState.REJECTED, KbState.DRAFT}),
    KbState.APPROVED_BY_HUMAN: frozenset({KbState.PUBLISHED, KbState.REJECTED}),
    KbState.PUBLISHED: frozenset({KbState.REVIEW_DUE, KbState.DEPRECATED, KbState.SUPERSEDED}),
    KbState.REVIEW_DUE: frozenset({KbState.PUBLISHED, KbState.DEPRECATED, KbState.SUPERSEDED}),
    KbState.DEPRECATED: frozenset({KbState.RETIRED}),
    KbState.RETIRED: frozenset(),
    KbState.REJECTED: frozenset(),
    KbState.SUPERSEDED: frozenset({KbState.RETIRED}),
}
HUMAN_DECISION_TRANSITIONS = frozenset({
    (KbState.PENDING_HUMAN_REVIEW, KbState.APPROVED_BY_HUMAN),
    (KbState.APPROVED_BY_HUMAN, KbState.PUBLISHED),
    (KbState.REVIEW_DUE, KbState.PUBLISHED),
    (KbState.PUBLISHED, KbState.DEPRECATED),
    (KbState.REVIEW_DUE, KbState.DEPRECATED),
    (KbState.PUBLISHED, KbState.SUPERSEDED),
    (KbState.REVIEW_DUE, KbState.SUPERSEDED),
    (KbState.DEPRECATED, KbState.RETIRED),
    (KbState.SUPERSEDED, KbState.RETIRED),
})


class ReviewStatus:
    NOT_REVIEWED = "NOT_REVIEWED"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    PENDING_HUMAN_REVIEW = "PENDING_HUMAN_REVIEW"
    APPROVED_BY_HUMAN = "APPROVED_BY_HUMAN"
    REJECTED = "REJECTED"


class SanitizationStatus:
    SANITIZED = "SANITIZED"


# Stable error codes. The message for each code is a FIXED string — it is never built from input, so
# a payload/secret can never be reflected through an error (Phase 12 prompt, sections 10 and 11).
ERROR_MESSAGES = {
    "E_USAGE": "invalid command line usage",
    "E_INPUT_UNREADABLE": "input file could not be read",
    "E_INPUT_TOO_LARGE": "input exceeds the ingestion size limit",
    "E_INPUT_INVALID": "input violates the expected schema",
    "E_UNSUPPORTED_SCHEMA_VERSION": "schema/contract version is not supported (no silent migration)",
    "E_RCA_CONTRACT": "RCA result does not satisfy the Phase 11 contract",
    "E_REFERENCE": "artifact references an unknown or inconsistent id",
    "E_SANITIZATION": "structure could not be sanitized safely",
    "E_UNSAFE_CONTENT": "content contains an executable or otherwise disallowed construct",
    "E_PATH_ESCAPE": "path resolves outside the allowed directory",
    "E_OUTPUT_EXISTS": "output already exists and will not be overwritten",
    "E_OUTPUT_TOO_LARGE": "generated output exceeds the size limit",
    "E_AUTH_MISSING": "external human authorization record is required",
    "E_AUTH_INVALID": "authorization record is malformed or not an approval",
    "E_AUTH_DIGEST_MISMATCH": "authorization does not match the current artifact digest/version",
    "E_AUTH_SELF_APPROVAL": "proposer cannot act as the human reviewer of its own artifact",
    "E_TRANSITION_DENIED": "lifecycle transition is not allowed",
    "E_QUALITY_GATE": "knowledge quality gate failed",
    "E_CONFLICT": "duplicate or conflicting knowledge entry blocks this operation",
    "E_KB_NOT_FOUND": "knowledge entry or version not found",
    "E_KB_INTEGRITY": "knowledge base integrity check failed",
    "E_IO": "output could not be written",
    "E_INTERNAL": "unexpected internal error (details suppressed)",
}


class AdvisoryError(Exception):
    """Fail-closed error carrying ONLY a stable code (and optional static field label taken from
    this package's own schema constants — never from input). str(e) is always a fixed message."""

    def __init__(self, code: str, field: str = None):
        self.code = code if code in ERROR_MESSAGES else "E_INPUT_INVALID"
        self.field = field
        super().__init__(ERROR_MESSAGES[self.code])

    def render(self) -> str:
        suffix = f" [field={self.field}]" if self.field else ""
        return f"{self.code}: {ERROR_MESSAGES[self.code]}{suffix}"


# --- deterministic helpers -----------------------------------------------------------------------

def canonical_json(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


DIGEST_EXCLUDED_FIELDS = frozenset({
    "content_digest", "generated_at_utc", "status", "review_status", "approval_declaration",
    "lifecycle_state", "lifecycle_history", "warnings_runtime", "external_execution_report",
})


def content_digest(artifact: dict) -> str:
    """SHA-256 of the canonical JSON of the SANITIZED artifact content, excluding volatile and
    workflow-state fields (DIGEST_EXCLUDED_FIELDS): approving or transitioning an artifact must not
    change the digest the approval is bound to, while ANY content change does. Used for
    integrity/approval binding only — it is computed over already-sanitized content, so it never
    becomes a hash of a sensitive value."""
    body = {k: v for k, v in artifact.items() if k not in DIGEST_EXCLUDED_FIELDS}
    return hashlib.sha256(canonical_json(body).encode("utf-8")).hexdigest()


_UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$")


def is_utc_timestamp(value) -> bool:
    if not isinstance(value, str) or not _UTC_RE.match(value):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def resolve_generated_at(override: str = None) -> str:
    """Clock injection point: a fixed, validated UTC timestamp makes outputs reproducible."""
    if override is None:
        return now_utc()
    if not is_utc_timestamp(override):
        raise AdvisoryError("E_USAGE", "generated_at")
    return override
