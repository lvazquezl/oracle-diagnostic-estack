"""Parser for `LIST BACKUP` output — detailed backup set/piece inventory, visibility only.

The e-stack never executes `LIST BACKUP` — this parser only ingests text the DBA already produced
and pasted in (# 13 del prompt de Fase 7).
"""
from __future__ import annotations

import re

from .common import ParsedCollectorOutput, ParseStatus, Sanitizer, now_iso, sha256_of_text, truncate_rows, DEFAULT_SIZE_LIMITS

PARSER_VERSION = "1.0.0"

_BS_HEADER_RE = re.compile(
    r"^BS Key\s+Type\s+LV\s+Size", re.IGNORECASE
)
_BS_ROW_RE = re.compile(
    r"^(\d+)\s+(Full|Incr)\s+(\d*)\s+(\S+)"
)
_PIECE_NAME_RE = re.compile(r"Piece Name:\s*(\S+)", re.IGNORECASE)
_TAG_RE = re.compile(r"Tag:\s*(\S+)", re.IGNORECASE)


def parse_list_backup(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_backup_inventory",
            source_command="LIST BACKUP",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    warnings: list[str] = []
    backup_sets = []
    pieces = []
    for line in text.splitlines():
        line = line.rstrip()
        m = _BS_ROW_RE.match(line.strip())
        if m:
            backup_sets.append({
                "bs_key": m.group(1),
                "type": m.group(2).upper(),
                "level": m.group(3) or None,
                "size": m.group(4),
            })
            continue
        pm = _PIECE_NAME_RE.search(line)
        if pm:
            pieces.append({"piece_name": pm.group(1)})
            continue
        tm = _TAG_RE.search(line)
        if tm and pieces:
            pieces[-1]["tag"] = tm.group(1)

    backup_sets = truncate_rows(backup_sets, DEFAULT_SIZE_LIMITS.max_backup_rows, warnings, "backup_sets")
    pieces = truncate_rows(pieces, DEFAULT_SIZE_LIMITS.max_piece_rows, warnings, "pieces")

    if sanitize:
        s = Sanitizer()
        for p in pieces:
            p["piece_name"] = s.handle(p["piece_name"])
            if "tag" in p:
                p["tag"] = s.tag(p["tag"])

    status = ParseStatus.SUCCESS if (backup_sets or pieces) else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_backup_inventory",
        source_command="LIST BACKUP",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"backup_sets": backup_sets, "pieces": pieces},
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
