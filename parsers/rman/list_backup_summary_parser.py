"""Parser for `LIST BACKUP SUMMARY` output — condensed backup inventory, visibility only.

The e-stack never executes `LIST BACKUP SUMMARY` — this parser only ingests text the DBA already
produced and pasted in (# 13 del prompt de Fase 7).
"""
from __future__ import annotations

import re

from .common import ParsedCollectorOutput, ParseStatus, Sanitizer, now_iso, sha256_of_text, truncate_rows, DEFAULT_SIZE_LIMITS

PARSER_VERSION = "1.0.0"

# Typical columns: Key TY LV S Device Type Completion Time #Piece #Copy Compressed Tag
_SUMMARY_ROW_RE = re.compile(
    r"^(\d+)\s+(B|B_INCR|B_ARCHIVELOG)\s+([AF0-9])\s+([AX])\s+(DISK|SBT_TAPE)\s+"
    r"(\d{2}-[A-Z]{3}-\d{2,4})\s+(\d+)\s+(\d+)\s+(YES|NO)(?:\s+(\S+))?",
    re.IGNORECASE,
)


def parse_list_backup_summary(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_backup_summary",
            source_command="LIST BACKUP SUMMARY",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    warnings: list[str] = []
    rows = []
    for line in text.splitlines():
        m = _SUMMARY_ROW_RE.match(line.strip())
        if not m:
            continue
        rows.append({
            "key": m.group(1),
            "backup_type": m.group(2).upper(),
            "level": m.group(3),
            "status": "AVAILABLE" if m.group(4).upper() == "A" else "EXPIRED",
            "device_type": m.group(5).upper(),
            "completion_time": m.group(6),
            "pieces": m.group(7),
            "copies": m.group(8),
            "compressed": m.group(9).upper() == "YES",
            "tag": m.group(10),
        })

    rows = truncate_rows(rows, DEFAULT_SIZE_LIMITS.max_backup_rows, warnings, "summary_rows")

    if sanitize:
        s = Sanitizer()
        for r in rows:
            if r.get("tag"):
                r["tag"] = s.tag(r["tag"])

    status = ParseStatus.SUCCESS if rows else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_backup_summary",
        source_command="LIST BACKUP SUMMARY",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"summary": rows},
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
