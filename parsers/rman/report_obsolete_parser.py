"""Parser for `REPORT OBSOLETE` output — visibility only.

The e-stack never executes `REPORT OBSOLETE` (nor `DELETE OBSOLETE`) — this parser only ingests
text the DBA already produced and pasted in (# 13, # 19 del prompt de Fase 7).
"""
from __future__ import annotations

import re

from .common import ParsedCollectorOutput, ParseStatus, Sanitizer, now_iso, sha256_of_text, truncate_rows, DEFAULT_SIZE_LIMITS

PARSER_VERSION = "1.0.0"

# Typical rows: "Backup Set    12   14-JAN-24" / "Archive Log   45   14-JAN-24"
_OBSOLETE_ROW_RE = re.compile(
    r"^(Backup Set|Backup Piece|Archive Log|Control File|Datafile Copy)\s+(\d+)\s+(\d{2}-[A-Z]{3}-\d{2,4})",
    re.IGNORECASE,
)
_NO_OBSOLETE_RE = re.compile(r"no obsolete backups found", re.IGNORECASE)


def parse_report_obsolete(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_backup_summary",
            source_command="REPORT OBSOLETE",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    warnings: list[str] = []
    if _NO_OBSOLETE_RE.search(text):
        return ParsedCollectorOutput(
            collector_id="get_backup_summary",
            source_command="REPORT OBSOLETE",
            parser_version=PARSER_VERSION,
            status=ParseStatus.SUCCESS,
            sections={"obsolete": [], "obsolete_count": 0},
            sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    rows = []
    for line in text.splitlines():
        m = _OBSOLETE_ROW_RE.match(line.strip())
        if not m:
            continue
        rows.append({"object_type": m.group(1), "key": m.group(2), "completion_time": m.group(3)})

    rows = truncate_rows(rows, DEFAULT_SIZE_LIMITS.max_backup_rows, warnings, "obsolete_rows")

    status = ParseStatus.SUCCESS if rows else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_backup_summary",
        source_command="REPORT OBSOLETE",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"obsolete": rows, "obsolete_count": len(rows)},
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
