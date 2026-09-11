"""Parser for `RESTORE ... PREVIEW` output — ANALYTICAL_PREVIEW, visibility only.

The e-stack never executes `RESTORE`, including `PREVIEW` — this parser only ingests text the DBA
already produced and pasted in after running the preview manually (# 13, # 14, # 25 del prompt de
Fase 7). Classified `ANALYTICAL_PREVIEW` in docs/RMAN_COMMAND_SAFETY_MODEL.md — modeled/parsed,
never invoked by the e-stack.
"""
from __future__ import annotations

import re

from .common import ParsedCollectorOutput, ParseStatus, Sanitizer, now_iso, sha256_of_text, truncate_rows, DEFAULT_SIZE_LIMITS

PARSER_VERSION = "1.0.0"

_PIECE_HANDLE_RE = re.compile(r"handle=(\S+)", re.IGNORECASE)
_MEDIA_RE = re.compile(r"media=(\S+)", re.IGNORECASE)
_DATAFILE_RE = re.compile(r"restoring datafile\s+(\d+)", re.IGNORECASE)
_MEDIA_RECOVERY_OK_RE = re.compile(r"media recovery start", re.IGNORECASE)
_NO_BACKUP_RE = re.compile(r"no backup (of|pieces?) .*found|cannot restore", re.IGNORECASE)


def parse_restore_preview(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_restore_preview",
            source_command="RESTORE ... PREVIEW",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    warnings: list[str] = []
    pieces = []
    datafiles = set()
    for line in text.splitlines():
        hm = _PIECE_HANDLE_RE.search(line)
        entry = {}
        if hm:
            entry["handle"] = hm.group(1)
        mm = _MEDIA_RE.search(line)
        if mm:
            entry["media"] = mm.group(1)
        if entry:
            pieces.append(entry)
        dm = _DATAFILE_RE.search(line)
        if dm:
            datafiles.add(dm.group(1))

    pieces = truncate_rows(pieces, DEFAULT_SIZE_LIMITS.max_piece_rows, warnings, "preview_pieces")

    blocked = bool(_NO_BACKUP_RE.search(text))
    media_recovery_expected = bool(_MEDIA_RECOVERY_OK_RE.search(text))

    if sanitize:
        s = Sanitizer()
        for p in pieces:
            if "handle" in p:
                p["handle"] = s.handle(p["handle"])
            if "media" in p:
                p["media"] = s.path(p["media"])

    status = ParseStatus.SUCCESS if (pieces or datafiles or blocked) else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_restore_preview",
        source_command="RESTORE ... PREVIEW",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "pieces_required": pieces,
            "datafiles_covered": sorted(datafiles),
            "restore_blocked": blocked,
            "media_recovery_expected": media_recovery_expected,
        },
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
