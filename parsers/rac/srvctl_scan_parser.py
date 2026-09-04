"""Parser for `srvctl config scan`, `srvctl status scan`, `srvctl config vip`.

Same free-text `key: value` / narrative-line style used across several srvctl
config/status subcommands — handled with one tolerant line-oriented parser.
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

_SCAN_NAME_RE = re.compile(r"^SCAN name:\s*(\S+?),", re.IGNORECASE)
_SCAN_VIP_RE = re.compile(r"^SCAN \d+ IPv4 VIP:\s*([\d.]+)", re.IGNORECASE)
_SCAN_STATUS_RE = re.compile(
    r"^SCAN VIP (scan\d+) is (running on node (\S+)|not running)", re.IGNORECASE
)


def parse_srvctl_scan_config(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_scan_configuration",
            source_command="srvctl config scan",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )
    scan_name = None
    ips: list[str] = []
    for line in text.splitlines():
        m = _SCAN_NAME_RE.match(line.strip())
        if m:
            scan_name = m.group(1)
        m2 = _SCAN_VIP_RE.match(line.strip())
        if m2:
            ips.append(m2.group(1))

    if sanitize:
        s = Sanitizer()
        if scan_name:
            scan_name = s.scan_name(scan_name)
        ips = [s.scrub_ip_addresses(ip) for ip in ips]

    status = ParseStatus.SUCCESS if scan_name else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_scan_configuration",
        source_command="srvctl config scan",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"scan_name": scan_name, "configured_ips": ips},
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )


def parse_srvctl_scan_status(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_scan_configuration",
            source_command="srvctl status scan",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )
    listeners = []
    for line in text.splitlines():
        m = _SCAN_STATUS_RE.match(line.strip())
        if not m:
            continue
        listener_id, detail, node = m.group(1), m.group(2), m.group(3)
        listeners.append(
            {
                "listener": listener_id,
                "status": "ONLINE" if node else "OFFLINE",
                "node": node,
            }
        )
    if sanitize:
        s = Sanitizer()
        for l in listeners:
            if l["node"]:
                l["node"] = s.node(l["node"])
    status = ParseStatus.SUCCESS if listeners else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_scan_configuration",
        source_command="srvctl status scan",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"scan_listeners": listeners},
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
