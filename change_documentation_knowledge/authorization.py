"""
change_documentation_knowledge.authorization — verification of an EXTERNALLY provided human
authorization record.

IMPORTANT LIMITATION (documented, not hidden): this module verifies the STRUCTURE of the record and
its exact correspondence with the current artifact (id, digest, version). It cannot prove WHO wrote
the record: there is no authentication/signature mechanism in this repository, so a locally supplied
approval is a declaration, not cryptographic proof of identity or of external authorization.
`verification` is therefore always STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED. Publication must remain a
manual action, verifiable in the repository under review.

The engine never creates an authorization record, never reads one from an environment variable,
and there is no CLI flag that approves anything.
"""
from __future__ import annotations

import re

from .common import AdvisoryError, is_utc_timestamp
from .safety import clean_text, has_instruction_markers, require_id
from .schema import req_dict, strict_keys

_DIGEST = re.compile(r'^[0-9a-f]{64}$')
_VERSION = re.compile(r'^[0-9]{1,4}$')
VERIFICATION_LEVEL = "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"
_REQUIRED = {"authorization_id", "artifact_id", "decision", "reviewer_id", "decision_at_utc",
             "artifact_digest", "version", "review_notes_sanitized"}


def parse_authorization(record) -> dict:
    """Strict structural validation of one record. Returns a sanitized copy."""
    rec = req_dict(record, "authorization")
    strict_keys(rec, _REQUIRED, set(), "authorization")
    decision = rec["decision"]
    if decision not in ("APPROVED", "REJECTED"):
        raise AdvisoryError("E_AUTH_INVALID", "authorization.decision")
    if not is_utc_timestamp(rec["decision_at_utc"]):
        raise AdvisoryError("E_AUTH_INVALID", "authorization.decision_at_utc")
    if not (isinstance(rec["artifact_digest"], str) and _DIGEST.match(rec["artifact_digest"])):
        raise AdvisoryError("E_AUTH_INVALID", "authorization.artifact_digest")
    if not (isinstance(rec["version"], str) and _VERSION.match(rec["version"])):
        raise AdvisoryError("E_AUTH_INVALID", "authorization.version")
    try:
        auth_id = require_id(rec["authorization_id"], ("AUTH",), "authorization.authorization_id")
        artifact_id = require_id(rec["artifact_id"], ("CHG", "KB", "KBV", "KBC"), "authorization.artifact_id")
        reviewer = require_id(rec["reviewer_id"], ("REV",), "authorization.reviewer_id")
    except AdvisoryError:
        raise AdvisoryError("E_AUTH_INVALID", "authorization.ids")
    notes = clean_text(rec["review_notes_sanitized"], 300, "authorization.review_notes_sanitized")
    return {"authorization_id": auth_id, "artifact_id": artifact_id, "decision": decision,
            "reviewer_id": reviewer, "decision_at_utc": rec["decision_at_utc"],
            "artifact_digest": rec["artifact_digest"], "version": rec["version"],
            "review_notes_sanitized": notes,
            "notes_flagged_instruction_like": has_instruction_markers(rec["review_notes_sanitized"])}


def verify_authorization(record, *, artifact_id: str, artifact_digest: str, version: str,
                         proposer_ids=(), require_decision: str = "APPROVED") -> dict:
    """Return the approval declaration to embed in the artifact, or raise:
       E_AUTH_INVALID / E_AUTH_DIGEST_MISMATCH (stale digest, other version, other artifact) /
       E_AUTH_SELF_APPROVAL (proposer == reviewer — no circular self-approval)."""
    if record is None:
        raise AdvisoryError("E_AUTH_MISSING")
    rec = parse_authorization(record)
    if rec["decision"] != require_decision:
        raise AdvisoryError("E_AUTH_INVALID", "authorization.decision")
    if rec["artifact_id"] != artifact_id or rec["artifact_digest"] != artifact_digest or rec["version"] != str(version):
        raise AdvisoryError("E_AUTH_DIGEST_MISMATCH")
    if rec["reviewer_id"] in set(proposer_ids or ()):
        raise AdvisoryError("E_AUTH_SELF_APPROVAL")
    return {"authorization_id": rec["authorization_id"], "reviewer_id": rec["reviewer_id"],
            "decision": rec["decision"], "decision_at_utc": rec["decision_at_utc"],
            "artifact_digest": rec["artifact_digest"], "version": rec["version"],
            "review_notes_sanitized": rec["review_notes_sanitized"],
            "verification": VERIFICATION_LEVEL}
