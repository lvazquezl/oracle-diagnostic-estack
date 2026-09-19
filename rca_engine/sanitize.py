"""
rca_engine.sanitize — deep, recursive, schema-aware redaction of every structured/free-text field
before it reaches causal reasoning, any JSON/Markdown/manifest output, or a log/error message.

PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING. Rewrites the
narrower Phase-1 sanitizer (which only pattern-matched `summary`/`symptom_description` text and
explicitly left `attributes` untouched — a real, reproduced leak vector: an `attributes` dict key
or value, or a `signature`/`target_id`/`source_id`, could carry a secret straight through to JSON/
Markdown/stderr with zero redaction). No equivalent Python sanitizer module existed elsewhere in
the repository to reuse (only the Markdown policy in sanitizers/data-classification-policy.md) —
this remains the single, non-duplicated local implementation for this engine.

Design:
  - `sanitize_text()` — pattern-based redaction of key=value-shaped secrets, AWS keys, PEM blocks,
    long hex hashes, Bearer tokens and connection strings, PLUS a bare-token heuristic that flags
    any long, unbroken alnum/`_+/=-`-shaped word (>=20 chars) as suspicious and redacts it. This is
    deliberately broad (documented, not exhaustive — see module-level NOTE) so that a marker/secret
    shaped like an opaque token is caught even without a recognizable `key=` prefix.
  - `deep_sanitize()` — recursively walks dict/list/tuple/scalar structures with hard limits on
    depth, key count, list length, string length and total node budget; rejects (fails closed,
    never echoes) cyclic references, non-string keys and unsupported types; drops any key whose
    name itself looks secret-shaped, never just its value.
  - `classify_signature()` — PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION
    MICRO-HARDENING: a signature is CERTIFIED only along one of two independently-bounded paths —
    (1) a TYPED numeric code (`^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\\d{3,6}$`), where the fixed prefix
    vocabulary and the bounded 3-6 digit code space carry no free-text payload chosen by the
    evidence source, so grammar validation alone is sufficient; or (2) an exact, versioned
    allowlist membership for template-shaped names (e.g. `HIGH_DB_FILE_SEQUENTIAL_READ`), derived
    from the loaded rules catalog itself (rules.collect_certified_signatures()) — matching the
    generic UPPER_SNAKE_CASE *shape* is explicitly NOT sufficient on its own, because that shape is
    free text chosen by whatever produced the evidence, not a bounded/typed value (this is exactly
    the defect this micro-hardening fixes — the prior `_SAFE_TEMPLATE_SIGNATURE` blanket-accepted
    any such shape). Anything not CERTIFIED becomes `UNRECOGNIZED_SIGNATURE` with an opaque,
    non-reversible `signature_token` for same-incident correlation — never the raw text, never a
    prefix/suffix/length-preserving transform of it.
  - `sanitize_attributes()` — enforces a caller-supplied key allowlist (derived from the loaded
    rules catalog, see rules.collect_allowed_attribute_keys) on top of deep_sanitize(): an unknown
    key is dropped entirely (key name AND value never appear anywhere downstream); an allowlisted
    key whose value is not the expected typed scalar (bool/int/float) is dropped as an invalid,
    unlogged value — never coerced to string, never echoed (fail-closed for typed causal fields).

NOTE — heuristic limits: no regex/heuristic set can prove the absence of every possible secret
shape. This module combines field-level policy (allowlists, structural transforms) with pattern/
heuristic text redaction as defense in depth — it does not claim, and must never be represented as
claiming, exhaustive secret detection. See docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md
for documented coverage and residual risk.

Python 3 standard library only.
"""
from __future__ import annotations

import math
import re
from typing import Optional

from .common import SignatureStatus
from .tokenization import derive_signature_token

_REDACTED = "[REDACTED]"

MAX_DEPTH = 6
MAX_STRING_LEN = 2000
MAX_LIST_LEN = 200
MAX_DICT_KEYS = 200
MAX_TOTAL_NODES = 5000

_CERTIFIED_CODE_PATTERN = re.compile(r'^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\d{3,6}$')

_KEY_VALUE_SECRET = re.compile(
    r'(?i)\b(password|pwd|passwd|secret|api[_-]?key|apikey|token|authorization)\s*[:=]\s*(\S+)'
)
_BEARER_TOKEN = re.compile(r'(?i)\bBearer\s+\S+')
_AWS_ACCESS_KEY = re.compile(r'\bAKIA[0-9A-Z]{16}\b')
_PEM_PRIVATE_KEY = re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----', re.DOTALL)
_LONG_HEX_HASH = re.compile(r'\b[0-9a-fA-F]{32,}\b')
_CONNECTION_STRING_CREDENTIALS = re.compile(r'[A-Za-z][\w+.-]*://[^/\s:@]+:[^/\s:@]+@')
_BARE_TOKEN_WORD = re.compile(r'[A-Za-z0-9_+/=-]{20,}')

_STRUCTURED_PATTERNS = [_KEY_VALUE_SECRET, _BEARER_TOKEN, _AWS_ACCESS_KEY, _PEM_PRIVATE_KEY, _LONG_HEX_HASH]


class SanitizationError(ValueError):
    """Raised for a structural violation (depth/size/cycle/type) — always fails closed, the
    caller must never echo the rejected value in the resulting error."""


def _looks_like_bare_secret(word: str) -> bool:
    """Heuristic fallback for a long, unbroken token-shaped word with no recognizable key= prefix
    — e.g. a bare API token, hash, or test marker pasted without context. Documented as broad and
    non-exhaustive (NOTE above): intentionally biased toward over-redaction, the safer failure
    mode for a security control, at the cost of occasionally redacting a long benign identifier."""
    return bool(re.fullmatch(r'[A-Za-z0-9_+/=-]{20,}', word))


def sanitize_text(value: Optional[str]) -> Optional[str]:
    """Redact secret-shaped substrings from a free-text field. Returns the value unchanged if it
    is None/empty. Deterministic: same input always yields same output."""
    if not value:
        return value
    out = value
    for pattern in _STRUCTURED_PATTERNS:
        if pattern is _KEY_VALUE_SECRET:
            out = pattern.sub(lambda m: f"{m.group(1)}={_REDACTED}", out)
        else:
            out = pattern.sub(_REDACTED, out)
    out = _BARE_TOKEN_WORD.sub(lambda m: _REDACTED if _looks_like_bare_secret(m.group(0)) else m.group(0), out)
    return out


def _key_contains_narrow_secret_pattern(key: str) -> bool:
    """Narrow check used ONLY for dict KEYS in deep_sanitize(): the structured, prefix-anchored
    patterns (password=, AKIA, PEM block, long hex hash, Bearer, connection-string credentials)
    only — deliberately WITHOUT the broad bare-token-word heuristic used for free-text VALUES.
    A legitimate structural attribute name (e.g. `nproc_utilization_percent`,
    `fork_failures_stopped_after_limit_increase`) is routinely >=20 characters of readable
    snake_case and would be false-positived by the bare-token heuristic if that heuristic were
    applied to keys — the real threat this guards against is a key that IS itself credential-
    shaped (e.g. an AWS access key id or a `password=...`-shaped string used as a key), which the
    narrow patterns below still catch precisely."""
    if not key:
        return False
    if any(p.search(key) for p in _STRUCTURED_PATTERNS):
        return True
    return bool(_CONNECTION_STRING_CREDENTIALS.search(key))


def contains_secret_pattern(value: Optional[str]) -> bool:
    """True if `value` still matches a secret-shaped pattern after (or without) sanitization —
    used by tests to assert an output artifact is genuinely clean, not merely that sanitize_text()
    was called somewhere in the pipeline."""
    if not value:
        return False
    if any(p.search(value) for p in _STRUCTURED_PATTERNS):
        return True
    if _CONNECTION_STRING_CREDENTIALS.search(value):
        return True
    return any(_looks_like_bare_secret(w) for w in _BARE_TOKEN_WORD.findall(value))


def substitute_literal(text: Optional[str], raw_value: Optional[str], replacement: str) -> Optional[str]:
    """Replaces every exact occurrence of `raw_value` inside `text` with `replacement`. Used to
    scrub a known raw identifier (e.g. the incident's raw target_id) out of free-text fields that
    happen to repeat it verbatim — a targeted, provable substitution, never a generic/undecidable
    'detect any hostname' heuristic."""
    if not text or not raw_value:
        return text
    return text.replace(raw_value, replacement)


def classify_signature(raw_signature: Optional[str], incident_id: str, certified_template_signatures: frozenset):
    """Classifies `raw_signature` into (signature_status, canonical_signature, signature_token).

    IMPORTANT: matching a generic shape/regex is never, by itself, sufficient proof that a value
    is safe to report (PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING
    — see module docstring). Two independently-bounded certification paths only:

      1. A TYPED numeric code for a fixed, known prefix family
         (`^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\\d{3,6}$`) — CERTIFIED, canonical_signature = raw value
         verbatim (safe: the value space is a bounded digit code under a fixed prefix vocabulary,
         not free text chosen by the evidence source).
      2. Exact membership in `certified_template_signatures` (the literal, versioned set of
         template-shaped signature names the LOADED rules catalog actually declares via
         `symptom_match.signature_any`) — CERTIFIED, canonical_signature = raw value verbatim.
         Matching the generic UPPER_SNAKE_CASE *shape* alone is explicitly NOT accepted — that
         shape can be chosen freely by whatever produced the evidence.

    Anything else -> UNRECOGNIZED_SIGNATURE, canonical_signature=None, signature_token=an opaque,
    non-reversible, incident-scoped token (tokenization.derive_signature_token) — never the raw
    text, never a prefix/suffix/length-preserving transform of it. `raw_signature` itself is never
    returned, stored, or embedded in this function's result in the UNRECOGNIZED case."""
    if raw_signature is None:
        return SignatureStatus.INSUFFICIENT_EVIDENCE, None, None
    if _CERTIFIED_CODE_PATTERN.match(raw_signature):
        return SignatureStatus.CERTIFIED, raw_signature, None
    if raw_signature in certified_template_signatures:
        return SignatureStatus.CERTIFIED, raw_signature, None
    return (
        SignatureStatus.UNRECOGNIZED_SIGNATURE, None,
        derive_signature_token(incident_id, raw_signature),
    )


def deep_sanitize(value, *, depth: int = 0, _seen: frozenset = frozenset(), _budget: list = None):
    """Recursively sanitizes an arbitrary JSON-shaped (or raw Python) value. Fails closed
    (SanitizationError) on excessive depth/size, cyclic references, non-string dict keys, or an
    unsupported scalar type — never silently truncates a violation into a 'best effort' result.
    A dict key that itself looks secret-shaped drops the entire key/value pair."""
    if _budget is None:
        _budget = [MAX_TOTAL_NODES]
    if depth > MAX_DEPTH:
        raise SanitizationError(f"structure exceeds max depth {MAX_DEPTH}")
    _budget[0] -= 1
    if _budget[0] < 0:
        raise SanitizationError(f"structure exceeds max total node budget {MAX_TOTAL_NODES}")

    if isinstance(value, dict):
        vid = id(value)
        if vid in _seen:
            raise SanitizationError("cyclic structure detected")
        seen_here = _seen | {vid}
        if len(value) > MAX_DICT_KEYS:
            raise SanitizationError(f"object exceeds max key count {MAX_DICT_KEYS}")
        out = {}
        for k, v in value.items():
            if not isinstance(k, str):
                raise SanitizationError("non-string key rejected")
            if _key_contains_narrow_secret_pattern(k):
                continue  # drop the whole pair — the key name itself is never echoed. Deliberately
                # narrow (not the bare-token-word heuristic): a legitimate structural attribute
                # name is routinely >=20 chars of readable snake_case and would false-positive
                # against that heuristic. An UNKNOWN key (including a marker/secret-shaped one) is
                # additionally dropped by the caller's own allowlist policy where one applies
                # (see sanitize_attributes()) — this generic guard only catches a key that is
                # itself precisely credential-shaped (AKIA/PEM/password=/hash/bearer/conn-string).
            safe_key = k[:200]
            out[safe_key] = deep_sanitize(v, depth=depth + 1, _seen=seen_here, _budget=_budget)
        return out

    if isinstance(value, (list, tuple)):
        vid = id(value)
        if vid in _seen:
            raise SanitizationError("cyclic structure detected")
        seen_here = _seen | {vid}
        items = list(value)[:MAX_LIST_LEN]
        return [deep_sanitize(v, depth=depth + 1, _seen=seen_here, _budget=_budget) for v in items]

    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if isinstance(value, str):
        return sanitize_text(value)[:MAX_STRING_LEN]

    raise SanitizationError(f"unsupported value type rejected: {type(value).__name__}")


def sanitize_attributes(raw_attributes, allowed_keys: frozenset) -> dict:
    """Applies deep_sanitize() first (structural/text safety), then drops any key not in
    `allowed_keys` (the rules catalog's known causal-attribute vocabulary) and any allowlisted key
    whose value is not the expected typed scalar (bool/int/float) — dropped silently, never
    coerced to string, never echoed. Returns the safe subset only."""
    if not isinstance(raw_attributes, dict):
        raise SanitizationError("attributes must be an object")
    safe = deep_sanitize(raw_attributes)
    out = {}
    for k, v in safe.items():
        if k not in allowed_keys:
            continue
        if isinstance(v, bool) or isinstance(v, (int, float)):
            out[k] = v
        # anything else (dict/list/string/None survived deep_sanitize but isn't a typed scalar for
        # a known causal attribute) is dropped — INVALID_INPUT for that single field, fail-closed.
    return out
