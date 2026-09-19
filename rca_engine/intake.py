"""
rca_engine.intake — schema validation, deep field-by-field sanitization, tokenization and the
evidence manifest.

PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING: every field is
sanitized here, BEFORE timeline construction, hypothesis evaluation or any output serialization —
this is the single point through which all incident/evidence data passes on its way into the
engine. Implements docs/INCIDENT_INTAKE_MODEL.md / docs/INCIDENT_EVIDENCE_MODEL.md /
docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md in executable form.

Error messages never echo a raw offending value — only the field name/path and, where useful, a
description of the violated constraint (e.g. "not in allowed set {...}" for a fixed enum, which is
safe because the enum values themselves are not secrets). Rejects malformed input with a clear
IntakeError/SanitizationError — never proceeds with a partially-valid input silently (section 2 del
prompt: "rechaza inputs malformados con error claro y código distinto de cero").

Python 3 standard library only.
"""
from __future__ import annotations

from .common import ALL_EVENT_TYPES, ALLOWED_DOMAINS, SAFE_IDENTIFIER_SHAPE, EvidenceManifest, EvidenceManifestCompleteness, SignatureStatus
from .sanitize import (
    SanitizationError, classify_signature, contains_secret_pattern, sanitize_attributes,
    sanitize_text, substitute_literal,
)
from .tokenization import derive_source_token, derive_target_token

_REQUIRED_INCIDENT_FIELDS = ("id", "target_id", "symptom_description")
_REQUIRED_EVIDENCE_FIELDS = ("evidence_id", "domain", "source_id", "timestamp", "event_type")


class IntakeError(ValueError):
    """Raised for malformed incident/evidence input. Always carries a human-readable detail that
    never echoes a raw field VALUE — only field names, paths, and fixed/known-safe enum members."""


def _require_safe_identifier(value: str, path: str) -> str:
    if not isinstance(value, str) or not SAFE_IDENTIFIER_SHAPE.match(value):
        raise IntakeError(f"{path} does not match the required safe identifier shape (never echoed)")
    return value


def validate_and_sanitize(fixture: dict, rules_catalog: dict) -> dict:
    """fixture: {"incident": {...}, "evidence": [...]}. rules_catalog: already-loaded rules (needed
    up front so the `attributes` allowlist is known before any evidence is processed — see
    engine.run_rca for the call order). Returns a new dict:
    {"incident": {...sanitized, target_id replaced by an opaque per-incident token...},
     "evidence": [...sanitized, source_id replaced by an opaque per-incident token, signature
     classified into signature_status/canonical_signature/signature_token (never a raw echo —
     PHASE 11 RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING), attributes
     reduced to the allowlisted+typed subset...]}.
    Raises IntakeError/SanitizationError on any structural problem — never proceeds partially."""
    if not isinstance(fixture, dict):
        raise IntakeError("fixture root must be a JSON object")
    if "incident" not in fixture or not isinstance(fixture["incident"], dict):
        raise IntakeError("fixture missing required object 'incident'")
    if "evidence" not in fixture or not isinstance(fixture["evidence"], list):
        raise IntakeError("fixture missing required array 'evidence'")

    raw_incident = fixture["incident"]
    for f in _REQUIRED_INCIDENT_FIELDS:
        if not raw_incident.get(f):
            raise IntakeError(f"incident missing required field '{f}'")

    incident_id = _require_safe_identifier(raw_incident["id"], "incident.id")
    raw_target_id = raw_incident["target_id"]
    if not isinstance(raw_target_id, str) or not raw_target_id.strip():
        raise IntakeError("incident.target_id must be a non-empty string")
    target_token = derive_target_token(incident_id, raw_target_id)
    token_map = {target_token: raw_target_id}

    symptom_description = sanitize_text(raw_incident["symptom_description"])
    symptom_description = substitute_literal(symptom_description, raw_target_id, target_token)

    declared_refs = []
    for i, ref in enumerate(raw_incident.get("declared_evidence_refs", [])):
        if isinstance(ref, str) and SAFE_IDENTIFIER_SHAPE.match(ref) and not contains_secret_pattern(ref):
            declared_refs.append(ref)
        # a malformed/secret-shaped declared ref is silently excluded from declared_refs — it can
        # never match a real (equally shape-validated) evidence_id anyway, so it degrades safely
        # to "missing" rather than being echoed anywhere.

    allowed_attribute_keys = None
    certified_signatures = None
    try:
        from .rules import collect_allowed_attribute_keys, collect_certified_signatures
        allowed_attribute_keys = collect_allowed_attribute_keys(rules_catalog)
        certified_signatures = collect_certified_signatures(rules_catalog)
    except Exception as exc:  # pragma: no cover — defensive: a broken catalog must fail closed here too
        raise IntakeError(f"could not derive attribute/signature allowlists from rules catalog: {type(exc).__name__}") from exc

    seen_ids = set()
    evidence = []
    for idx, item in enumerate(fixture["evidence"]):
        if not isinstance(item, dict):
            raise IntakeError(f"evidence[{idx}] must be a JSON object")
        for f in _REQUIRED_EVIDENCE_FIELDS:
            if not item.get(f):
                raise IntakeError(f"evidence[{idx}] missing required field '{f}'")
        if item["event_type"] not in ALL_EVENT_TYPES:
            raise IntakeError(
                f"evidence[{idx}].event_type is not one of the allowed values {sorted(ALL_EVENT_TYPES)} "
                f"(offending value not echoed)"
            )
        if item["domain"] not in ALLOWED_DOMAINS:
            raise IntakeError(
                f"evidence[{idx}].domain is not one of the allowed values {sorted(ALLOWED_DOMAINS)} "
                f"(offending value not echoed)"
            )
        evidence_id = _require_safe_identifier(item["evidence_id"], f"evidence[{idx}].evidence_id")
        if contains_secret_pattern(evidence_id):
            raise IntakeError(f"evidence[{idx}].evidence_id rejected: fails secret-shape check (not echoed)")
        if evidence_id in seen_ids:
            raise IntakeError(f"evidence[{idx}] duplicate evidence_id at index {idx} (value not echoed)")
        seen_ids.add(evidence_id)

        raw_source_id = item["source_id"]
        if not isinstance(raw_source_id, str) or not raw_source_id.strip():
            raise IntakeError(f"evidence[{idx}].source_id must be a non-empty string")
        source_token = derive_source_token(incident_id, raw_source_id)
        token_map.setdefault(source_token, raw_source_id)

        signature_status, canonical_signature, signature_token = classify_signature(
            item.get("signature"), incident_id, certified_signatures
        )
        if signature_status == SignatureStatus.UNRECOGNIZED_SIGNATURE:
            # the ONLY place the raw signature is ever retained — in the local, operator-only
            # token map, gated behind the CLI's explicit --token-map flag, never merged into
            # --out/--markdown/--manifest (same isolation as target_id/source_id tokens above).
            token_map.setdefault(signature_token, item["signature"])

        summary = sanitize_text(item.get("summary"))
        summary = substitute_literal(summary, raw_target_id, target_token)
        summary = substitute_literal(summary, raw_source_id, source_token)

        try:
            attributes = sanitize_attributes(item.get("attributes", {}), allowed_attribute_keys)
        except SanitizationError as exc:
            raise IntakeError(f"evidence[{idx}].attributes rejected: {exc}") from exc

        evidence.append({
            "evidence_id": evidence_id, "domain": item["domain"], "source_id": source_token,
            "event_type": item["event_type"], "timestamp": item["timestamp"],
            "signature_status": signature_status, "canonical_signature": canonical_signature,
            "signature_token": signature_token,
            "summary": summary, "attributes": attributes,
        })

    sanitized_incident = {
        "id": incident_id, "target_id": target_token, "symptom_description": symptom_description,
        "declared_evidence_refs": declared_refs,
    }
    # token_map is returned ONLY for an explicit, separate --token-map output (cli.py) — it must
    # never be merged into the sanitized incident/evidence returned here, and the caller (engine.py)
    # must never embed it in RcaResult (the model-facing JSON/Markdown/manifest artifacts).
    return {"incident": sanitized_incident, "evidence": evidence, "token_map": token_map}


def build_evidence_manifest(incident: dict, evidence: list) -> EvidenceManifest:
    """A `declared_evidence_refs` list on the incident represents evidence the intake claims exists
    (already shape-validated and de-secreted by validate_and_sanitize()). Any declared ref not
    actually present in `evidence` is a broken/missing reference — consulted later by causality.py
    to block CONFIRMED whenever completeness is INCOMPLETE_REFS."""
    declared = list(incident.get("declared_evidence_refs", []))
    present = sorted({e["evidence_id"] for e in evidence})
    missing = sorted(set(declared) - set(present))
    completeness = (
        EvidenceManifestCompleteness.INCOMPLETE_REFS if missing
        else EvidenceManifestCompleteness.COMPLETE
    )
    return EvidenceManifest(
        declared_refs=sorted(declared), present_refs=present, missing_refs=missing,
        completeness=completeness,
    )
