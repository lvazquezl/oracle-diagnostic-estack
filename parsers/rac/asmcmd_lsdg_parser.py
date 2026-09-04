"""Parser for `asmcmd lsdg` — used only as a discovery/fallback collector for
asm/topology; routine capacity monitoring uses V$ASM_DISKGROUP_STAT via SQL
(Q-ASM-TOPOLOGY-001), not this collector.
"""
from __future__ import annotations

import re

from .common import (
    ParsedCollectorOutput,
    ParseStatus,
    Sanitizer,
    now_iso,
    sha256_of_text,
)

PARSER_VERSION = "1.0.0"

_HEADER_TOKENS = [
    "state", "type", "rebal", "sector", "logical_sector", "block", "au",
    "total_mb", "free_mb", "req_mir_free_mb", "usable_file_mb",
    "offline_disks", "voting_files", "name",
]


def parse_asmcmd_lsdg(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_diskgroup_listing",
            source_command="asmcmd lsdg",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    lines = [l for l in text.splitlines() if l.strip()]
    if not lines or "state" not in lines[0].lower():
        return ParsedCollectorOutput(
            collector_id="get_diskgroup_listing",
            source_command="asmcmd lsdg",
            parser_version=PARSER_VERSION,
            status=ParseStatus.UNSUPPORTED_FORMAT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    diskgroups = []
    for line in lines[1:]:
        cols = [c for c in re.split(r"\s+", line.strip()) if c]
        if len(cols) < len(_HEADER_TOKENS):
            continue
        row = dict(zip(_HEADER_TOKENS, cols))
        diskgroups.append(
            {
                "name": row["name"].rstrip("/"),
                "state": row["state"],
                "type": row["type"],
                "total_mb": int(row["total_mb"]),
                "free_mb": int(row["free_mb"]),
                "usable_file_mb": int(row["usable_file_mb"]),
                "required_mirror_free_mb": int(row["req_mir_free_mb"]),
            }
        )

    if sanitize:
        s = Sanitizer()
        for dg in diskgroups:
            dg["name"] = s.path(dg["name"])

    status = ParseStatus.SUCCESS if diskgroups else ParseStatus.PARTIAL
    return ParsedCollectorOutput(
        collector_id="get_diskgroup_listing",
        source_command="asmcmd lsdg",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"diskgroups": diskgroups},
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
