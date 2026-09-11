"""Parser for `REPORT NEED BACKUP` output — visibility only.

The e-stack never executes `REPORT NEED BACKUP` — this parser only ingests text the DBA already
produced and pasted in (# 13 del prompt de Fase 7).
"""
from __future__ import annotations

import re

from .common import ParsedCollectorOutput, ParseStatus, Sanitizer, now_iso, sha256_of_text, truncate_rows, DEFAULT_SIZE_LIMITS

PARSER_VERSION = "1.0.0"

_NEED_BACKUP_ROW_RE = re.compile(r"^File\s+#?(\d+)\s+.*?(\d+)\s+days?\s+", re.IGNORECASE)
_NONE_FOUND_RE = re.compile(r"no.*(datafiles|archived logs).*found", re.IGNORECASE)


def parse_report_need_backup(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_archivelog_backup_summary",
            source_command="REPORT NEED BACKUP",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    warnings: list[str] = []
    if _NONE_FOUND_RE.search(text):
        return ParsedCollectorOutput(
            collector_id="get_archivelog_backup_summary",
            source_command="REPORT NEED BACKUP",
            parser_version=PARSER_VERSION,
            status=ParseStatus.SUCCESS,
            sections={"need_backup": []},
            sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    rows = []
    for line in text.splitlines():
        m = _NEED_BACKUP_ROW_RE.match(line.strip())
        if not m:
            continue
        rows.append({"file_number": m.group(1), "days_without_backup": m.group(2)})

    rows = truncate_rows(rows, DEFAULT_SIZE_LIMITS.max_line_rows, warnings, "need_backup_rows")

    status = ParseStatus.SUCCESS if rows else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_archivelog_backup_summary",
        source_command="REPORT NEED BACKUP",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"need_backup": rows},
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
