"""Parser for `crsctl stat res -t` (resource status), `crsctl query crs
activeversion`/`softwareversion` (GI version), and `oifcfg getif` (network
interfaces) — all thin, allowlisted, read-only Clusterware commands.

Never executes crsctl — parses captured text output only.
"""
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

_RESOURCE_NAME_RE = re.compile(r"^(ora\.\S+)\s*$")
_SEPARATOR_RE = re.compile(r"^-{5,}$")
_HEADER_RE = re.compile(r"^NAME\s+TARGET\s+STATE\s+SERVER", re.IGNORECASE)


def _split_columns(line: str) -> list[str]:
    return [c for c in re.split(r"\s{2,}", line.strip()) if c]


def parse_crsctl_resources(
    text: str,
    limits: SizeLimitPolicy = DEFAULT_SIZE_LIMITS,
    sanitize: bool = True,
) -> ParsedCollectorOutput:
    warnings: list[str] = []
    src_hash = sha256_of_text(text)

    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_cluster_resources",
            source_command="crsctl stat res -t",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    if len(text.encode("utf-8")) > limits.max_output_bytes:
        text = text[: limits.max_output_bytes]
        warnings.append("salida truncada por max_output_bytes antes de parsear")

    lines = text.splitlines()
    resources: list[dict] = []
    current_name: str | None = None

    for raw in lines:
        if not raw.strip() or _SEPARATOR_RE.match(raw.strip()) or _HEADER_RE.match(raw) \
           or raw.strip() in ("Local Resources", "Cluster Resources"):
            continue
        m = _RESOURCE_NAME_RE.match(raw)
        if m:
            current_name = m.group(1)
            continue
        if current_name is None:
            continue
        cols = _split_columns(raw)
        if not cols:
            continue
        # Cluster Resources rows start with an instance number; Local Resources rows don't.
        if cols[0].isdigit() and len(cols) >= 3:
            instance, target, state = cols[0], cols[1], cols[2]
            server = cols[3] if len(cols) > 3 else None
            state_details = cols[4] if len(cols) > 4 else None
        elif len(cols) >= 2:
            instance = None
            target, state = cols[0], cols[1]
            server = cols[2] if len(cols) > 2 else None
            state_details = cols[3] if len(cols) > 3 else None
        else:
            continue
        resources.append(
            {
                "resource": current_name,
                "instance": instance,
                "target": target,
                "state": state,
                "server": server,
                "state_details": state_details,
            }
        )

    resources = truncate_rows(resources, limits.max_resource_rows, warnings, "resources")

    if sanitize:
        s = Sanitizer()
        for r in resources:
            if r["server"]:
                r["server"] = s.node(r["server"])

    online = sum(1 for r in resources if r["state"] == "ONLINE")
    offline = sum(1 for r in resources if r["state"] == "OFFLINE")
    intermediate = sum(1 for r in resources if r["state"] == "INTERMEDIATE")
    unknown = sum(1 for r in resources if r["state"] not in ("ONLINE", "OFFLINE", "INTERMEDIATE"))

    anomalous = [r for r in resources if r["state"] != r["target"] and r["target"] == "ONLINE"]

    status = ParseStatus.SUCCESS if resources else ParseStatus.PARTIAL
    if not resources:
        warnings.append("no se encontraron recursos reconocibles en la salida")

    return ParsedCollectorOutput(
        collector_id="get_cluster_resources",
        source_command="crsctl stat res -t",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "total_resources": len(resources),
            "online": online,
            "offline": offline,
            "intermediate": intermediate,
            "unknown": unknown,
            "anomalous_resources": anomalous,
            "all_resources": resources,
        },
        warnings=warnings,
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )


_ACTIVE_VERSION_RE = re.compile(r"CRS active version on the cluster is \[([\d.]+)\]")
_SOFTWARE_VERSION_RE = re.compile(r"CRS software version on node \S+ is \[([\d.]+)\]")


def parse_crsctl_version(text: str) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_cluster_version",
            source_command="crsctl query crs activeversion/softwareversion",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )
    active = _ACTIVE_VERSION_RE.search(text)
    software = _SOFTWARE_VERSION_RE.search(text)
    status = ParseStatus.SUCCESS if (active or software) else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_cluster_version",
        source_command="crsctl query crs activeversion/softwareversion",
        parser_version=PARSER_VERSION,
        status=status,
        sections={
            "active_version": active.group(1) if active else None,
            "software_version": software.group(1) if software else None,
        },
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )


_OIFCFG_LINE_RE = re.compile(r"^(\S+)\s+(\S+)\s+(public|cluster_interconnect|asm)\s*$", re.IGNORECASE)


def parse_oifcfg(text: str, sanitize: bool = True) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_network_configuration",
            source_command="oifcfg getif",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )
    interfaces = []
    for line in text.splitlines():
        m = _OIFCFG_LINE_RE.match(line.strip())
        if m:
            interfaces.append(
                {"interface": m.group(1), "subnet": m.group(2), "classification": m.group(3).lower()}
            )
    if sanitize:
        s = Sanitizer()
        for iface in interfaces:
            iface["subnet"] = s.scrub_ip_addresses(iface["subnet"])
    status = ParseStatus.SUCCESS if interfaces else ParseStatus.UNSUPPORTED_FORMAT
    return ParsedCollectorOutput(
        collector_id="get_network_configuration",
        source_command="oifcfg getif",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"interfaces": interfaces},
        sanitization_status="APPLIED" if sanitize else "NOT_APPLIED",
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
