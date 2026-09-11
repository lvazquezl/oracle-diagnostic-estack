"""Shared envelope/utilities for parsers/rman/* (Fase 7 — Backup & Recovery/RMAN).

Mirrors parsers/rac/common.py and parsers/dataguard/common.py — a separate,
self-contained package by design.

Security model (# 13, # 36 PROMPT INJECTION, Fase 7 prompt): output captured from RMAN commands
already executed manually by the DBA (SHOW ALL, LIST BACKUP, LIST BACKUP SUMMARY, REPORT OBSOLETE,
REPORT NEED BACKUP, RESTORE ... PREVIEW) is always DATA, never interpreted as instructions. No
module in this package calls eval/exec/subprocess/os.system/compile() on captured text, and no
module in this package executes RMAN — parsing only, never invocation (# 15 del prompt: no
execute_rman()/run_rman()/rman_shell()).
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class ParseStatus(str, Enum):
    SUCCESS = "SUCCESS"
    PARTIAL = "PARTIAL"
    UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT"
    UNKNOWN_OUTPUT_TYPE = "UNKNOWN_OUTPUT_TYPE"
    MALFORMED_OUTPUT = "MALFORMED_OUTPUT"
    EMPTY_OUTPUT = "EMPTY_OUTPUT"
    SANITIZATION_FAILED = "SANITIZATION_FAILED"


@dataclass
class SizeLimitPolicy:
    max_output_bytes: int = 5 * 1024 * 1024   # 5MB
    max_backup_rows: int = 2000
    max_piece_rows: int = 2000
    max_line_rows: int = 5000


DEFAULT_SIZE_LIMITS = SizeLimitPolicy()


@dataclass
class ParsedCollectorOutput:
    collector_id: str
    source_command: str
    parser_version: str
    status: ParseStatus
    sections: dict[str, Any] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)
    sanitization_status: str = "NOT_APPLIED"
    source_output_hash: str = ""
    parse_timestamp: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "collector_output": {
                "collector_id": self.collector_id,
                "source_command": self.source_command,
                "parser_version": self.parser_version,
                "status": self.status.value,
                "sections": self.sections,
                "warnings": self.warnings,
                "sanitization_status": self.sanitization_status,
                "source_output_hash": self.source_output_hash,
                "parse_timestamp": self.parse_timestamp,
            }
        }


def sha256_of_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def truncate_rows(rows: list, limit: int, warnings: list[str], what: str) -> list:
    if len(rows) > limit:
        warnings.append(f"{what}: truncado a {limit} filas (de {len(rows)})")
        return rows[:limit]
    return rows


class Sanitizer:
    """Deterministic, session-consistent tokenization — mirrors parsers/rac/common.py.Sanitizer,
    scoped to RMAN fields (piece handles, filesystem/ASM/SBT paths, tags, vendor job IDs).
    """

    def __init__(self) -> None:
        self._tokens: dict[str, str] = {}
        self._counters: dict[str, int] = {}

    def _tokenize(self, value: str, prefix: str) -> str:
        if not value:
            return value
        key = f"{prefix}:{value}"
        if key not in self._tokens:
            self._counters[prefix] = self._counters.get(prefix, 0) + 1
            self._tokens[key] = f"{prefix}_TOKEN_{self._counters[prefix]:03d}"
        return self._tokens[key]

    def handle(self, value: str) -> str:
        return self._tokenize(value, "HANDLE")

    def path(self, value: str) -> str:
        return self._tokenize(value, "PATH")

    def tag(self, value: str) -> str:
        return self._tokenize(value, "TAG")

    def vendor_job_id(self, value: str) -> str:
        return self._tokenize(value, "VENDORJOB")

    def db_unique_name(self, value: str) -> str:
        return self._tokenize(value, "DBUNIQUENAME")

    def scrub_ip_addresses(self, text: str) -> str:
        return re.sub(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "IP_TOKEN", text)
