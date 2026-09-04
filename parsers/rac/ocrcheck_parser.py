"""Parser for `ocrcheck` — integrity status and copy locations, visibility only."""
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

_DEVICE_RE = re.compile(r"Device/File Name\s*:\s*(\S+)")
_INTEGRITY_OK_RE = re.compile(r"Device/File integrity check succeeded")
_CLUSTER_INTEGRITY_RE = re.compile(r"Cluster registry integrity check (succeeded|failed)")


def parse_ocrcheck(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_ocr_status",
            source_command="ocrcheck",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    lines = text.splitlines()
    copies = []
    pending_location = None
    for line in lines:
        dm = _DEVICE_RE.search(line)
        if dm:
            pending_location = dm.group(1)
            continue
        if pending_location and _INTEGRITY_OK_RE.search(line):
            copies.append({"location": pending_location, "status": "OK"})
            pending_location = None

    cm = _CLUSTER_INTEGRITY_RE.search(text)
    integrity_check = cm.group(1).upper() if cm else None

    if sanitize:
        s = Sanitizer()
        for c in copies:
            c["location"] = s.path(c["location"])

    status = ParseStatus.SUCCESS if integrity_check else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_ocr_status",
        source_command="ocrcheck",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "ocr_status": "KNOWN" if integrity_check else "UNKNOWN",
            "integrity_check": integrity_check,
            "copies": copies,
        },
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
