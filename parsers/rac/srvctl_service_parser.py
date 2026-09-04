"""Parser for `srvctl config service` (per-service `key: value` block)."""
from __future__ import annotations

from .common import (
    ParsedCollectorOutput,
    ParseStatus,
    Sanitizer,
    now_iso,
    sha256_of_text,
)

PARSER_VERSION = "1.0.0"

_FIELD_MAP = {
    "Service name": "service_name",
    "Connection Load Balancing Goal": "clb_goal",
    "Runtime Load Balancing Goal": "rlb_goal",
    "Failover type": "failover_type",
    "Failover method": "failover_method",
    "Preferred instances": "preferred_instances",
    "Available instances": "available_instances",
    "Service role": "service_role",
}

_LIST_FIELDS = {"preferred_instances", "available_instances"}


def parse_srvctl_service_config(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_service_configuration",
            source_command="srvctl config service",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    fields: dict = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        target = _FIELD_MAP.get(key)
        if not target:
            continue
        fields[target] = value.split(",") if target in _LIST_FIELDS and value else (
            [value] if target in _LIST_FIELDS else value
        )

    if sanitize:
        s = Sanitizer()
        if fields.get("service_name"):
            fields["service_name"] = s.service(fields["service_name"])
        for key in ("preferred_instances", "available_instances"):
            if fields.get(key):
                fields[key] = [s.instance(v) for v in fields[key]]

    status = ParseStatus.SUCCESS if fields.get("service_name") else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_service_configuration",
        source_command="srvctl config service",
        parser_version=PARSER_VERSION,
        status=status,
        sections=fields,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
