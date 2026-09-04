"""Parser for `crsctl query css votedisk` — visibility only, never modifies."""
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

_ROW_RE = re.compile(r"^\s*\d+\.\s+(\S+)\s+\S+\s+\(([^)]+)\)\s+\[([^\]]+)\]")
_COUNT_RE = re.compile(r"Located (\d+) voting disk")

# Minimum voting disks for quorum to be considered NOT at risk (odd number, >=3 typical).
_MIN_QUORUM_DISKS = 3


def parse_voting(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_voting_status",
            source_command="crsctl query css votedisk",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    disks = []
    for line in text.splitlines():
        m = _ROW_RE.match(line)
        if m:
            state, location, diskgroup = m.groups()
            disks.append({"location": location, "diskgroup": diskgroup, "status": state})

    cm = _COUNT_RE.search(text)
    located_count = int(cm.group(1)) if cm else len(disks)

    if sanitize:
        s = Sanitizer()
        for d in disks:
            d["location"] = s.path(d["location"])

    quorum_at_risk = located_count < _MIN_QUORUM_DISKS
    status = ParseStatus.SUCCESS if disks else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_voting_status",
        source_command="crsctl query css votedisk",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "voting_status": "KNOWN" if disks else "UNKNOWN",
            "voting_disks": disks,
            "located_count": located_count,
            "quorum_at_risk": quorum_at_risk,
        },
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
