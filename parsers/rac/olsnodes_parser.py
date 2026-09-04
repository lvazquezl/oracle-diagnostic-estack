"""Parser for `olsnodes -s -t` (node membership + active/pinned state)."""
from __future__ import annotations

import re

from .common import (
    DEFAULT_SIZE_LIMITS,
    ParsedCollectorOutput,
    ParseStatus,
    Sanitizer,
    SizeLimitPolicy,
    now_iso,
    sha256_of_text,
    truncate_rows,
)

PARSER_VERSION = "1.0.0"


def parse_olsnodes(
    text: str,
    limits: SizeLimitPolicy = DEFAULT_SIZE_LIMITS,
    sanitize: bool = True,
) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_cluster_nodes",
            source_command="olsnodes -s -t",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    nodes = []
    warnings: list[str] = []
    for line in text.splitlines():
        cols = [c for c in re.split(r"\t+|\s{2,}", line.strip()) if c]
        if not cols:
            continue
        node = cols[0]
        membership_status = cols[1] if len(cols) > 1 else "UNKNOWN"
        pinned = cols[2] if len(cols) > 2 else None
        nodes.append({"node": node, "membership_status": membership_status, "pinned": pinned})

    nodes = truncate_rows(nodes, limits.max_node_rows, warnings, "nodes")

    if sanitize:
        s = Sanitizer()
        for n in nodes:
            n["node"] = s.node(n["node"])

    status = ParseStatus.SUCCESS if nodes else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_cluster_nodes",
        source_command="olsnodes -s -t",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"nodes": nodes},
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
