"""Parser for `lsnrctl status` — endpoints and registered services/handlers."""
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

_ALIAS_RE = re.compile(r"^Alias\s+(\S+)")
_ENDPOINT_RE = re.compile(
    r"PROTOCOL=(\w+)\)\(HOST=([\w.\-]+)\)\(PORT=(\d+)\)", re.IGNORECASE
)
_SERVICE_RE = re.compile(r'^Service "([^"]+)" has (\d+) instance')
_HANDLER_RE = re.compile(r'has (\d+) handler\(s\)')


def parse_lsnrctl_status(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_listener_configuration",
            source_command="lsnrctl status",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    alias = None
    endpoints = []
    services: dict[str, dict] = {}
    current_service = None

    for line in text.splitlines():
        m = _ALIAS_RE.match(line.strip())
        if m:
            alias = m.group(1)
            continue
        for em in _ENDPOINT_RE.finditer(line):
            proto, host, port = em.groups()
            endpoints.append({"protocol": proto, "host": host, "port": int(port)})
        sm = _SERVICE_RE.match(line.strip())
        if sm:
            current_service = sm.group(1)
            services[current_service] = {"service": current_service, "handlers": 0}
            continue
        hm = _HANDLER_RE.search(line)
        if hm and current_service:
            services[current_service]["handlers"] += int(hm.group(1))

    if sanitize:
        s = Sanitizer()
        for ep in endpoints:
            ep["host"] = s.node(ep["host"])
        for svc in services.values():
            svc["service"] = s.service(svc["service"])

    status = ParseStatus.SUCCESS if alias else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_listener_configuration",
        source_command="lsnrctl status",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "listener": alias,
            "endpoints": endpoints,
            "services_registered": list(services.values()),
        },
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
