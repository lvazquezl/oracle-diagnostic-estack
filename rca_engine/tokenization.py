"""
rca_engine.tokenization — stable, opaque, per-incident tokens for identifiers that must never be
propagated raw into any output surface (`target_id`, `source_id`, and — since the PHASE 11 RCA
SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING — any non-certified `signature`).

Design (PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 3):
  - Deterministic within an incident: the same (incident_id, raw_value) pair always yields the
    same token, so JSON/Markdown correlation (same target/source referenced by multiple events)
    is preserved without ever re-exposing the raw identifier.
  - Namespaced per incident_id: the same raw_value under a DIFFERENT incident_id yields a
    DIFFERENT token — cross-incident correlation is never possible unless a future, explicitly
    authorized policy adds it deliberately (none exists today; see Known limitations in
    docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md).
  - NOT a confidentiality mechanism on its own: `_TOKEN_PEPPER` is a fixed, public, in-source
    namespacing constant, not a secret key. This is deliberately NOT "a simple low-entropy hash of
    the secret" used AS the protection (the raw value is never hashed alone into the token space
    reachable by brute force from a small guess-list without also knowing/guessing incident_id) —
    but it is still guessable given enough of both incident_id and raw_value candidates. Treat
    tokens as opaque, non-reversible identifiers for correlation, not as a cryptographic secret.
    A local, protected token map (never embedded in --out/--markdown/--manifest) is the only way
    to resolve a token back to its raw value — see cli.py's --token-map option.

Python 3 standard library only.
"""
from __future__ import annotations

import hashlib
from typing import Optional

_TOKEN_PEPPER = b"rca_engine.tokenization/1.0.0"


def _derive(namespace: str, incident_id: str, raw_value: str) -> str:
    material = _TOKEN_PEPPER + b"|" + namespace.encode("utf-8") + b"|" + \
        incident_id.encode("utf-8") + b"|" + raw_value.encode("utf-8")
    return hashlib.sha256(material).hexdigest()[:16]


def derive_target_token(incident_id: str, raw_target_id: Optional[str]) -> Optional[str]:
    if raw_target_id is None:
        return None
    return f"TGT-{_derive('target_id', incident_id, raw_target_id)}"


def derive_source_token(incident_id: str, raw_source_id: Optional[str]) -> Optional[str]:
    if raw_source_id is None:
        return None
    return f"SRC-{_derive('source_id', incident_id, raw_source_id)}"


def derive_signature_token(incident_id: str, raw_signature: Optional[str]) -> Optional[str]:
    """PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING: for an
    UNRECOGNIZED (non-certified) signature, this is the ONLY form in which it may ever correlate
    across evidence items — never the raw text, never a prefix/suffix/substring of it, never its
    length (the token is always the same fixed 16-hex-char shape regardless of input length or
    content). Same incident_id + same raw_signature -> same token (correlation preserved); same
    raw_signature under a different incident_id -> a different token (no cross-incident
    correlation for unrecognized signatures — see module docstring's tokenization limitations,
    which apply identically here: this is namespacing/stability, not a cryptographic secret, since
    no externally-keyed HMAC solution is certified in this repository today)."""
    if raw_signature is None:
        return None
    return f"SIG-{_derive('signature', incident_id, raw_signature)}"
