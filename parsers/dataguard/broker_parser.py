"""Parser for Data Guard Broker DGMGRL `SHOW` output — allowlisted, read-only
subcommands only (`SHOW CONFIGURATION`, `SHOW DATABASE [VERBOSE]`,
`SHOW FAST_START FAILOVER`). Never executes DGMGRL — parses captured text only.
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

# ---------------------------------------------------------------------------
# SHOW CONFIGURATION
# ---------------------------------------------------------------------------

_CONFIG_NAME_RE = re.compile(r"^Configuration - (\S+)")
_PROTECTION_MODE_RE = re.compile(r"^\s*Protection Mode:\s*(\S+)")
_MEMBER_RE = re.compile(r"^\s*(\S+)\s*-\s*(Primary database|Physical standby database|Logical standby database|Snapshot standby database)", re.IGNORECASE)
_FSFO_RE = re.compile(r"^Fast-Start Failover:\s*(\S+)")
_CONFIG_STATUS_RE = re.compile(r"^(SUCCESS|WARNING|ERROR|DISABLED)\b")


def parse_show_configuration(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_dataguard_configuration",
            source_command="SHOW CONFIGURATION",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    lines = text.splitlines()
    config_name = None
    protection_mode = None
    fsfo_enabled = None
    members: list[dict] = []
    config_status = None
    after_status_marker = False

    for line in lines:
        m = _CONFIG_NAME_RE.match(line)
        if m:
            config_name = m.group(1)
            continue
        m = _PROTECTION_MODE_RE.match(line)
        if m:
            protection_mode = m.group(1)
            continue
        m = _MEMBER_RE.match(line)
        if m:
            role = "PRIMARY" if "primary" in m.group(2).lower() else "PHYSICAL_STANDBY"
            members.append({"db_unique_name": m.group(1), "role": role})
            continue
        m = _FSFO_RE.match(line)
        if m:
            fsfo_enabled = m.group(1).upper() == "ENABLED"
            continue
        if line.strip() == "Configuration Status:":
            after_status_marker = True
            continue
        if after_status_marker:
            m = _CONFIG_STATUS_RE.match(line.strip())
            if m:
                config_status = m.group(1)
                after_status_marker = False

    if sanitize:
        s = Sanitizer()
        if config_name:
            config_name = s.db_unique_name(config_name)
        for mem in members:
            mem["db_unique_name"] = s.db_unique_name(mem["db_unique_name"])

    status = ParseStatus.SUCCESS if config_status else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_dataguard_configuration",
        source_command="SHOW CONFIGURATION",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "configuration_name": config_name,
            "protection_mode": protection_mode,
            "fsfo_enabled": fsfo_enabled,
            "members": members,
            "configuration_status": config_status,
        },
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )


# ---------------------------------------------------------------------------
# SHOW DATABASE (non-verbose)
# ---------------------------------------------------------------------------

_DB_NAME_RE = re.compile(r"^Database - (\S+)")
_ROLE_RE = re.compile(r"^\s*Role:\s*(.+?)\s*$")
_INTENDED_STATE_RE = re.compile(r"^\s*Intended State:\s*(\S+)")
_TRANSPORT_LAG_RE = re.compile(r"^\s*Transport Lag:\s*(.+?)\s*\(")
_APPLY_LAG_RE = re.compile(r"^\s*Apply Lag:\s*(.+?)\s*\(")
_WARNING_RE = re.compile(r"^\s*(ORA-\d+):\s*(.+)$")
_DB_STATUS_MARKER_RE = re.compile(r"^Database (Status|Warning\(s\)|Error\(s\)):")


def _parse_lag_to_seconds(text: str) -> int:
    """'2 minutes 15 seconds' / '0 seconds' -> seconds (int)."""
    total = 0
    for value, unit in re.findall(r"(\d+)\s*(second|minute|hour|day)s?", text):
        n = int(value)
        if unit == "second":
            total += n
        elif unit == "minute":
            total += n * 60
        elif unit == "hour":
            total += n * 3600
        elif unit == "day":
            total += n * 86400
    return total


def parse_show_database(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_dataguard_database_status",
            source_command="SHOW DATABASE <tokenized-db>",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    db_name = None
    role = None
    intended_state = None
    transport_lag_seconds = None
    apply_lag_seconds = None
    warnings_dg: list[dict] = []
    errors_dg: list[dict] = []
    db_status = None
    section = None

    for line in text.splitlines():
        m = _DB_NAME_RE.match(line)
        if m:
            db_name = m.group(1)
            continue
        m = _ROLE_RE.match(line)
        if m:
            role = m.group(1).strip()
            continue
        m = _INTENDED_STATE_RE.match(line)
        if m:
            intended_state = m.group(1)
            continue
        m = _TRANSPORT_LAG_RE.match(line)
        if m:
            transport_lag_seconds = _parse_lag_to_seconds(m.group(1))
            continue
        m = _APPLY_LAG_RE.match(line)
        if m:
            apply_lag_seconds = _parse_lag_to_seconds(m.group(1))
            continue
        m = _DB_STATUS_MARKER_RE.match(line)
        if m:
            section = m.group(1)
            continue
        if section in ("Warning(s)", "Error(s)"):
            wm = _WARNING_RE.match(line)
            if wm:
                target = warnings_dg if section == "Warning(s)" else errors_dg
                target.append({"code": wm.group(1), "message": wm.group(2)})
                continue
        if section == "Status":
            stripped = line.strip()
            if stripped in ("SUCCESS", "WARNING", "ERROR"):
                db_status = stripped
                section = None

    if sanitize:
        s = Sanitizer()
        if db_name:
            db_name = s.db_unique_name(db_name)

    status = ParseStatus.SUCCESS if db_status else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_dataguard_database_status",
        source_command="SHOW DATABASE <tokenized-db>",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "db_unique_name": db_name,
            "role": role,
            "intended_state": intended_state,
            "transport_lag_seconds": transport_lag_seconds,
            "apply_lag_seconds": apply_lag_seconds,
            "warnings": warnings_dg,
            "errors": errors_dg,
            "database_status": db_status,
        },
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )


# ---------------------------------------------------------------------------
# SHOW DATABASE VERBOSE
# ---------------------------------------------------------------------------

_PROPERTY_RE = re.compile(r"^\s{4}(\w+)\s+=\s+'([^']*)'")


def parse_show_database_verbose(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    base = parse_show_database(text, sanitize=False)
    src_hash = sha256_of_text(text)

    properties: dict[str, str] = {}
    for line in text.splitlines():
        m = _PROPERTY_RE.match(line)
        if m:
            properties[m.group(1)] = m.group(2)

    sections = dict(base.sections)
    sections["properties"] = properties

    if sanitize:
        s = Sanitizer()
        if sections.get("db_unique_name"):
            sections["db_unique_name"] = s.db_unique_name(sections["db_unique_name"])
        if "DGConnectIdentifier" in properties:
            properties["DGConnectIdentifier"] = s.db_unique_name(properties["DGConnectIdentifier"])

    return ParsedCollectorOutput(
        collector_id="get_dataguard_verbose_status",
        source_command="SHOW DATABASE VERBOSE <tokenized-db>",
        parser_version=PARSER_VERSION,
        status=base.status,
        sections=sections,
        warnings=base.warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )


# ---------------------------------------------------------------------------
# SHOW FAST_START FAILOVER
# ---------------------------------------------------------------------------

_FSFO_ENABLED_RE = re.compile(r"^Fast-Start Failover:\s*(\S+)")
_THRESHOLD_RE = re.compile(r"^\s*Threshold:\s*(\d+)\s*seconds")
_TARGET_RE = re.compile(r"^\s*Target:\s*(\S+)")
_OBSERVER_HOST_RE = re.compile(r"^\s*Observer:\s*(\S+)")
_OBSERVER_REGISTERED_RE = re.compile(r"^\s*Registered:\s*(\d+)")


def parse_show_fsfo(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_fsfo_status",
            source_command="SHOW FAST_START FAILOVER",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    enabled = None
    threshold_seconds = None
    target = None
    observer_host = None
    observer_registered = None

    for line in text.splitlines():
        m = _FSFO_ENABLED_RE.match(line)
        if m:
            enabled = m.group(1).upper() == "ENABLED"
            continue
        m = _THRESHOLD_RE.match(line)
        if m:
            threshold_seconds = int(m.group(1))
            continue
        m = _TARGET_RE.match(line)
        if m:
            target = m.group(1)
            continue
        m = _OBSERVER_HOST_RE.match(line)
        if m:
            observer_host = m.group(1)
            continue
        m = _OBSERVER_REGISTERED_RE.match(line)
        if m:
            observer_registered = int(m.group(1))
            continue

    if observer_registered is not None and observer_registered > 0:
        observer_status = "CONNECTED"
    elif observer_host:
        observer_status = "CONFIGURED"
    else:
        observer_status = "DISCONNECTED" if enabled else "UNKNOWN"

    if sanitize:
        s = Sanitizer()
        if target:
            target = s.db_unique_name(target)
        if observer_host:
            observer_host = s.host(observer_host)

    status = ParseStatus.SUCCESS if enabled is not None else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_fsfo_status",
        source_command="SHOW FAST_START FAILOVER",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "enabled": enabled,
            "threshold_seconds": threshold_seconds,
            "target": target,
            "observer_host": observer_host,
            "observer_status": observer_status,
        },
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
