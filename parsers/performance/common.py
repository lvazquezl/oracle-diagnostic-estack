"""
Common envelope, error states, size-limit policy, sanitization and hashing
utilities shared by every parser under parsers/performance/.

READ-ONLY ALWAYS. This module never executes, evals, or interprets content
extracted from a report file as instructions — every value pulled from a
report is treated strictly as data (see `# PARSER SECURITY` in
docs/PHASE_3_COMPLETION_HARDENING.md).

Python 3 standard library only — no external dependencies (see
docs/PHASE_3_COMPLETION_HARDENING.md#python-portability).
"""

from __future__ import annotations

import hashlib
import re
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


PARSER_FRAMEWORK_VERSION = "1.0.0"


class ReportSourceType(str, Enum):
    AWR_HTML = "AWR_HTML"
    AWR_TEXT = "AWR_TEXT"
    STATSPACK_TEXT = "STATSPACK_TEXT"
    ADDM_TEXT = "ADDM_TEXT"
    EXECUTION_PLAN_TEXT = "EXECUTION_PLAN_TEXT"
    UNKNOWN = "UNKNOWN"


class ParseStatus(str, Enum):
    """Normalized parser error states — # 21 PARSER ERROR STATES.
    Never inferred/fabricated: a parser sets exactly one of these, never a
    value not in this set."""

    SUCCESS = "SUCCESS"
    PARTIAL = "PARTIAL"
    UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT"
    UNKNOWN_REPORT_TYPE = "UNKNOWN_REPORT_TYPE"
    MALFORMED_REPORT = "MALFORMED_REPORT"
    EMPTY_REPORT = "EMPTY_REPORT"
    SANITIZATION_FAILED = "SANITIZATION_FAILED"


@dataclass
class SizeLimitPolicy:
    """# 23 REPORT SIZE LIMITS — configurable, never hardcoded silently."""

    max_report_size_bytes: int = 20 * 1024 * 1024   # 20 MB
    max_section_size_bytes: int = 2 * 1024 * 1024    # 2 MB
    max_sql_entries: int = 200
    max_wait_entries: int = 100
    max_plan_rows: int = 500


DEFAULT_SIZE_LIMITS = SizeLimitPolicy()


@dataclass
class ParsedReport:
    """Common parser output envelope — # 20 PARSER OUTPUT CONTRACT.
    Every parser under parsers/performance/ returns exactly this shape."""

    source_type: str
    parser_version: str
    detection_confidence: str            # HIGH|MEDIUM|LOW
    status: str                          # one of ParseStatus
    metadata: dict[str, Any] = field(default_factory=dict)
    sections: dict[str, Any] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)
    completeness: dict[str, str] = field(default_factory=dict)   # section -> SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED
    sensitivity: str = "MEDIUM"
    sanitization_status: str = "NOT_APPLIED"
    evidence_refs: list[str] = field(default_factory=list)
    report_id: str = field(default_factory=lambda: f"RPT-{uuid.uuid4().hex[:12]}")
    # # 50 EXTERNAL FILE EVIDENCE TRACEABILITY
    source_file_hash: str | None = None
    parse_timestamp: str | None = None
    sections_extracted: list[str] = field(default_factory=list)
    sections_missing: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "report": {
                "report_id": self.report_id,
                "source_type": self.source_type,
                "parser_version": self.parser_version,
                "detection_confidence": self.detection_confidence,
                "status": self.status,
                "metadata": self.metadata,
                "sections": self.sections,
                "warnings": self.warnings,
                "completeness": self.completeness,
                "sensitivity": self.sensitivity,
                "sanitization_status": self.sanitization_status,
                "evidence_refs": self.evidence_refs,
                "source_file_hash": self.source_file_hash,
                "parse_timestamp": self.parse_timestamp,
                "sections_extracted": self.sections_extracted,
                "sections_missing": self.sections_missing,
            }
        }


def sha256_of_text(text: str) -> str:
    """# 51 HASHING — SHA-256 for evidence integrity/traceability only.
    Never a substitute for secret sanitization — the hash is of the
    (already-read) report content, not a claim that it contains no secrets."""
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def truncate_to_limit(text: str, max_bytes: int) -> tuple[str, bool]:
    """Return (possibly-truncated text, was_truncated). Never silently drops
    data without recording the truncation — callers must add a warning."""
    encoded = text.encode("utf-8", errors="replace")
    if len(encoded) <= max_bytes:
        return text, False
    return encoded[:max_bytes].decode("utf-8", errors="ignore"), True


# ---------------------------------------------------------------------------
# Sanitization — # 24 REPORT SANITIZATION
#
# Minimal, deterministic tokenization consistent with
# sanitizers/data-classification-policy.md's KEEP/MASK/HASH/TOKENIZE/DROP
# model, applied locally before any section is exposed as Evidence. This is
# NOT a general PII scrubber — it targets the specific fields the policy
# names for this domain (hostnames, database names, service names, schemas,
# object names, IP addresses, SQL text). Tokenization is consistent within
# one parse (the same raw value always maps to the same token) so
# correlation across sections of the same report remains possible.
# ---------------------------------------------------------------------------

_IPV4_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


class Sanitizer:
    def __init__(self) -> None:
        self._token_map: dict[str, str] = {}
        self._counters: dict[str, int] = {}

    def _tokenize(self, kind: str, value: str) -> str:
        if not value:
            return value
        key = f"{kind}:{value}"
        if key not in self._token_map:
            n = self._counters.get(kind, 0) + 1
            self._counters[kind] = n
            self._token_map[key] = f"{kind.upper()}_TOKEN_{n:03d}"
        return self._token_map[key]

    def hostname(self, value: str) -> str:
        return self._tokenize("host", value)

    def db_name(self, value: str) -> str:
        return self._tokenize("db", value)

    def service_name(self, value: str) -> str:
        return self._tokenize("service", value)

    def schema(self, value: str) -> str:
        return self._tokenize("schema", value)

    def object_name(self, value: str) -> str:
        return self._tokenize("object", value)

    def scrub_ip_addresses(self, text: str) -> str:
        return _IPV4_RE.sub(lambda m: self._tokenize("ip", m.group(0)), text)

    def drop_sql_text(self, _sql_text: str) -> None:
        """SQL text is DROP by policy, never KEEP/MASK/HASH — never stored,
        never returned, never sent. See # 9 STATSPACK SQL PRIVACY, # 19
        EXECUTION PLAN PARSER. Callers must not retain the argument."""
        return None


def apply_size_limits(sections: dict[str, list], limits: SizeLimitPolicy) -> list[str]:
    """Trim list-shaped sections (waits, sql rows, plan rows) to the
    configured caps, returning warnings for anything trimmed."""
    warnings: list[str] = []
    caps = {
        "waits": limits.max_wait_entries,
        "sql": limits.max_sql_entries,
        "plan_operations": limits.max_plan_rows,
    }
    for key, cap in caps.items():
        rows = sections.get(key)
        if isinstance(rows, list) and len(rows) > cap:
            warnings.append(f"section '{key}' truncated to {cap} entries (was {len(rows)})")
            sections[key] = rows[:cap]
    return warnings
