"""Parser for `SHOW ALL` output — RMAN persistent configuration, visibility only.

The e-stack never executes `SHOW ALL` — this parser only ingests text the DBA already produced
and pasted in (# 13 del prompt de Fase 7).
"""
from __future__ import annotations

import re

from .common import ParsedCollectorOutput, ParseStatus, Sanitizer, now_iso, sha256_of_text

PARSER_VERSION = "1.0.0"

_CONFIG_LINE_RE = re.compile(r"^CONFIGURE\s+(.+?)\s*;\s*(?:#.*)?$", re.IGNORECASE)
_DEFAULT_MARK_RE = re.compile(r"#\s*default", re.IGNORECASE)


def parse_show_all(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_rman_configuration",
            source_command="SHOW ALL",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    entries = []
    for line in text.splitlines():
        m = _CONFIG_LINE_RE.match(line.strip())
        if not m:
            continue
        raw = m.group(1)
        is_default = bool(_DEFAULT_MARK_RE.search(line))
        entries.append({"config": raw.strip(), "is_default": is_default})

    if sanitize:
        s = Sanitizer()
        for e in entries:
            if re.search(r"(SNAPSHOT CONTROLFILE NAME|FORMAT)", e["config"], re.IGNORECASE):
                parts = e["config"].split(" TO ", 1)
                if len(parts) == 2:
                    e["config"] = f"{parts[0]} TO {s.path(parts[1])}"
            elif re.search(r"\bPARMS\b", e["config"], re.IGNORECASE):
                parts = re.split(r"(\bPARMS\b)", e["config"], maxsplit=1, flags=re.IGNORECASE)
                if len(parts) == 3:
                    e["config"] = f"{parts[0]}{parts[1]} {s.path(parts[2].strip())}"

    status = ParseStatus.SUCCESS if entries else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_rman_configuration",
        source_command="SHOW ALL",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"configuration": entries},
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
