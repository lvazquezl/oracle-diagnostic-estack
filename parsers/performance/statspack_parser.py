"""
Statspack text report parser — # 7/8/9 of docs/PHASE_3_COMPLETION_HARDENING.md.

Extracts, when present in the report, each of: snapshot metadata, Load
Profile, Instance Efficiency, Top Wait Events, SQL ordered by {executions,
CPU, elapsed, gets, reads}, Instance Activity, Library Cache, Latch,
Enqueue, I/O (file/tablespace), Redo/Commit, Parsing, Memory (Cache Sizes).

Never fabricates a section: `completeness[section]` is SUPPORTED only when
the section heading and at least one data row were actually matched;
PARTIALLY_SUPPORTED when the heading matched but rows were sparse/irregular;
UNSUPPORTED when the heading was not found in this specific report at all.

SQL sections never retain SQL text — only SQL_ID/hash, executions, CPU,
elapsed, gets, reads, rows (# 9 STATSPACK SQL PRIVACY).
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from .common import (
    DEFAULT_SIZE_LIMITS,
    ParsedReport,
    ParseStatus,
    Sanitizer,
    apply_size_limits,
    sha256_of_text,
    truncate_to_limit,
)

PARSER_VERSION = "1.0.0"

# --- Section anchors -------------------------------------------------------
# Statspack section headers are stable strings across 10g-19g+ even though
# the table columns beneath them vary — anchor on the header, tolerate
# whatever whitespace/underline style follows it.

_SECTION_HEADERS = {
    "load_profile": r"^Load Profile\s*$",
    "instance_efficiency": r"^Instance Efficiency Percentages",
    "top_waits": r"^Top 5 Timed Events|^Top \d+ Timed Events|^Top Timed Events",
    "sql_cpu": r"^SQL ordered by CPU",
    "sql_elapsed": r"^SQL ordered by Elapsed Time|^SQL ordered by Gets.*Elapsed",
    "sql_executions": r"^SQL ordered by Executions",
    "sql_gets": r"^SQL ordered by Gets",
    "sql_reads": r"^SQL ordered by Reads|^SQL ordered by Disk Reads",
    "instance_activity": r"^Instance Activity Stats",
    "library_cache": r"^Library Cache Activity",
    "latch_activity": r"^Latch Activity",
    "enqueue_activity": r"^Enqueue [Aa]ctivity",
    "file_io": r"^File IO Stats|^Tablespace IO Stats",
    "cache_sizes": r"^Cache Sizes",
}


def _split_sections(text: str) -> dict[str, str]:
    """Slice the report into {section_key: raw_block_text} using the header
    anchors above; a section's block runs until the next recognized header
    or a Statspack '---' rule-of-3-or-more-dashes divider repeated (a
    reasonably reliable end-of-table marker in these reports)."""
    lines = text.splitlines()
    header_positions: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        for key, pattern in _SECTION_HEADERS.items():
            if re.match(pattern, stripped):
                header_positions.append((i, key))
                break
    blocks: dict[str, str] = {}
    for idx, (line_no, key) in enumerate(header_positions):
        end = header_positions[idx + 1][0] if idx + 1 < len(header_positions) else len(lines)
        # cap a single section's scan window so one malformed report can't
        # make a later section bleed into an earlier one indefinitely
        end = min(end, line_no + 400)
        blocks.setdefault(key, "\n".join(lines[line_no:end]))
    return blocks


def _extract_metadata(text: str) -> dict[str, str | None]:
    meta: dict[str, str | None] = {
        "source_type": "STATSPACK",
        "db_name": None,
        "instance_name": None,
        "dbid": None,
        "oracle_version": None,
        "snap_begin": None,
        "snap_end": None,
        "elapsed_minutes": None,
        "db_time_minutes": None,
    }
    m = re.search(r"^\s*(\S+)\s+(\d{6,12})\s+(\S+)\s+(\d+)\s+.*?\s+([\d.]+\.[\d.]+\.[\d.]+\.[\d.]+)", text, re.MULTILINE)
    if m:
        meta["db_name"], meta["dbid"], meta["instance_name"] = m.group(1), m.group(2), m.group(3)
        meta["oracle_version"] = m.group(5)
    m = re.search(r"Begin Snap:\s*\d+\s+(.+?)\s{2,}", text)
    if m:
        meta["snap_begin"] = m.group(1).strip()
    m = re.search(r"End Snap:\s*\d+\s+(.+?)\s{2,}", text)
    if m:
        meta["snap_end"] = m.group(1).strip()
    m = re.search(r"Elapsed:\s*([\d.]+)\s*\(mins\)", text)
    if m:
        meta["elapsed_minutes"] = m.group(1)
    m = re.search(r"DB Time:\s*([\d.]+)\s*\(mins\)", text)
    if m:
        meta["db_time_minutes"] = m.group(1)
    return meta


def _extract_load_profile(block: str) -> list[dict[str, str]]:
    rows = []
    for line in block.splitlines():
        m = re.match(r"^\s*([A-Za-z][A-Za-z0-9 /%]*?):\s+([\d,.]+)\s*(?:([\d,.]+))?\s*$", line)
        if m:
            rows.append({
                "metric": m.group(1).strip(),
                "per_second": m.group(2).replace(",", ""),
                "per_transaction": (m.group(3) or "").replace(",", "") or None,
            })
    return rows


def _extract_efficiency(block: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for m in re.finditer(r"([A-Za-z][A-Za-z0-9 /\-]*?%):\s*([\d.]+)", block):
        result[m.group(1).strip()] = m.group(2)
    return result


def _extract_waits(block: str, limits) -> list[dict[str, str]]:
    rows = []
    for line in block.splitlines():
        m = re.match(
            r"^([A-Za-z][A-Za-z0-9 /\-\.\(\)]*?)\s{2,}([\d,]+)?\s{0,}([\d,]+)\s+(\d+)\s+([\d.]+)\s*$",
            line.rstrip(),
        )
        if m and not line.strip().startswith("-"):
            rows.append({
                "event": m.group(1).strip(),
                "waits": (m.group(2) or "").replace(",", "") or None,
                "time_s": m.group(3).replace(",", ""),
                "avg_wait_ms": m.group(4),
                "pct_total_time": m.group(5),
            })
    # No trim here — apply_size_limits() is the single enforcement point so
    # a cap that's actually hit produces a recorded warning instead of a
    # silent truncation (see # 23 REPORT SIZE LIMITS).
    return rows


def _extract_sql(block: str, limits) -> list[dict[str, str]]:
    """SQL_ID + numeric metrics only — never SQL text (# 9 privacy)."""
    rows = []
    sql_id_re = re.compile(r"\b([0-9a-z]{13})\b", re.IGNORECASE)
    for line in block.splitlines():
        idm = sql_id_re.search(line)
        if not idm:
            continue
        nums = re.findall(r"[\d,]+\.\d+|\d[\d,]*", line[: idm.start()])
        if len(nums) < 2:
            continue
        rows.append({
            "sql_id": idm.group(1),
            "metrics": [n.replace(",", "") for n in nums],
        })
    return rows[: limits.max_sql_entries]


def _extract_generic_table(block: str) -> list[dict[str, str]]:
    """Best-effort key/numeric-columns extraction for sections whose exact
    column layout varies by version (Library Cache, Latch, Enqueue,
    File/Tablespace IO, Instance Activity Stats). Tolerates ASM-style
    filenames ('+DATA/...') as a row name, not only alphabetic names."""
    rows = []
    for line in block.splitlines():
        line = line.rstrip()
        if not line or set(line.strip()) <= {"-", "~"}:
            continue
        m = re.match(r"^([A-Za-z+][A-Za-z0-9 _/%\.\-\(\)#+]*?)\s{2,}([\d,.\s]+)$", line)
        if m:
            nums = re.findall(r"[\d,]+\.\d+|\d[\d,]*", m.group(2))
            if nums:
                rows.append({"name": m.group(1).strip(), "values": [n.replace(",", "") for n in nums]})
    return rows


def _extract_cache_sizes(block: str) -> list[dict[str, str]]:
    """'Cache Sizes' packs two 'Label:  value' pairs per line (e.g.
    'Buffer Cache: 4096M   Std Block Size: 8K') — a shape the generic
    name+numbers table extractor can't handle, so it gets its own pass."""
    rows = []
    for line in block.splitlines():
        for pm in re.finditer(r"([A-Za-z][A-Za-z0-9 ]*?):\s+([\d,.]+[KMGkmg]?)", line):
            rows.append({"name": pm.group(1).strip(), "values": [pm.group(2)]})
    return rows


def _completeness_for(section_key: str, blocks: dict[str, str], rows) -> str:
    if section_key not in blocks:
        return "UNSUPPORTED"
    if not rows:
        return "PARTIALLY_SUPPORTED"
    return "SUPPORTED"


def parse_statspack_text(
    text: str,
    limits=DEFAULT_SIZE_LIMITS,
    sanitize: bool = True,
) -> ParsedReport:
    parse_ts = datetime.now(timezone.utc).isoformat()

    if text is None or text.strip() == "":
        return ParsedReport(
            source_type="STATSPACK_TEXT",
            parser_version=PARSER_VERSION,
            detection_confidence="LOW",
            status=ParseStatus.EMPTY_REPORT.value,
            parse_timestamp=parse_ts,
        )

    truncated_text, was_truncated = truncate_to_limit(text, limits.max_report_size_bytes)
    warnings: list[str] = []
    if was_truncated:
        warnings.append(f"report truncated at {limits.max_report_size_bytes} bytes")

    source_hash = sha256_of_text(text)

    blocks = _split_sections(truncated_text)
    if not blocks:
        return ParsedReport(
            source_type="STATSPACK_TEXT",
            parser_version=PARSER_VERSION,
            detection_confidence="LOW",
            status=ParseStatus.MALFORMED_REPORT.value,
            warnings=warnings + ["no recognized Statspack section headers found"],
            source_file_hash=source_hash,
            parse_timestamp=parse_ts,
        )

    metadata = _extract_metadata(truncated_text)

    sections: dict[str, object] = {}
    completeness: dict[str, str] = {}

    load_profile = _extract_load_profile(blocks.get("load_profile", ""))
    sections["load_profile"] = load_profile
    completeness["load_profile"] = _completeness_for("load_profile", blocks, load_profile)

    efficiency = _extract_efficiency(blocks.get("instance_efficiency", ""))
    sections["instance_efficiency"] = efficiency
    completeness["instance_efficiency"] = _completeness_for("instance_efficiency", blocks, efficiency)

    waits = _extract_waits(blocks.get("top_waits", ""), limits)
    sections["waits"] = waits
    completeness["waits"] = _completeness_for("top_waits", blocks, waits)

    sql_sections = {
        "sql_by_cpu": "sql_cpu",
        "sql_by_elapsed": "sql_elapsed",
        "sql_by_executions": "sql_executions",
        "sql_by_gets": "sql_gets",
        "sql_by_reads": "sql_reads",
    }
    any_sql = []
    for out_key, block_key in sql_sections.items():
        rows = _extract_sql(blocks.get(block_key, ""), limits)
        sections[out_key] = rows
        completeness[out_key] = _completeness_for(block_key, blocks, rows)
        any_sql.extend(rows)
    sections["sql"] = any_sql   # convenience alias used by skill/tests; capped by apply_size_limits() below

    instance_activity = _extract_generic_table(blocks.get("instance_activity", ""))
    sections["instance_activity"] = instance_activity
    completeness["instance_activity"] = _completeness_for("instance_activity", blocks, instance_activity)

    library_cache = _extract_generic_table(blocks.get("library_cache", ""))
    sections["library_cache"] = library_cache
    completeness["library_cache"] = _completeness_for("library_cache", blocks, library_cache)

    latch = _extract_generic_table(blocks.get("latch_activity", ""))
    sections["latch"] = latch
    completeness["latch"] = _completeness_for("latch_activity", blocks, latch)

    enqueue = _extract_generic_table(blocks.get("enqueue_activity", ""))
    sections["enqueue"] = enqueue
    completeness["enqueue"] = _completeness_for("enqueue_activity", blocks, enqueue)

    io = _extract_generic_table(blocks.get("file_io", ""))
    sections["io"] = io
    completeness["io"] = _completeness_for("file_io", blocks, io)

    cache_sizes = _extract_cache_sizes(blocks.get("cache_sizes", ""))
    sections["memory"] = cache_sizes
    completeness["memory"] = _completeness_for("cache_sizes", blocks, cache_sizes)

    # Redo/commit and Parsing are DERIVED from Load Profile + Instance
    # Efficiency rather than their own dedicated section — Statspack does
    # not have a standalone "Redo/Commit" or "Parsing" heading.
    redo_commit = {
        row["metric"]: row["per_second"]
        for row in load_profile
        if row["metric"].lower() in ("redo size", "user calls", "transactions")
    }
    sections["redo_commit"] = redo_commit
    completeness["redo_commit"] = "SUPPORTED" if redo_commit else "PARTIALLY_SUPPORTED"

    parsing = {
        row["metric"]: row["per_second"]
        for row in load_profile
        if row["metric"].lower() in ("parses", "hard parses")
    }
    if "Soft Parse %" in efficiency:
        parsing["Soft Parse %"] = efficiency["Soft Parse %"]
    sections["parsing"] = parsing
    completeness["parsing"] = "SUPPORTED" if parsing else "PARTIALLY_SUPPORTED"

    size_warnings = apply_size_limits(sections, limits)
    warnings.extend(size_warnings)

    if sanitize:
        sanitizer = Sanitizer()
        if metadata.get("db_name"):
            metadata["db_name"] = sanitizer.db_name(metadata["db_name"])
        if metadata.get("instance_name"):
            metadata["instance_name"] = sanitizer.hostname(metadata["instance_name"])
        sanitization_status = "APPLIED"
    else:
        sanitization_status = "NOT_APPLIED"

    sections_extracted = [k for k, v in completeness.items() if v != "UNSUPPORTED"]
    sections_missing = [k for k, v in completeness.items() if v == "UNSUPPORTED"]

    any_supported = any(v == "SUPPORTED" for v in completeness.values())
    status = ParseStatus.SUCCESS.value if (any_supported and not sections_missing) else ParseStatus.PARTIAL.value

    return ParsedReport(
        source_type="STATSPACK_TEXT",
        parser_version=PARSER_VERSION,
        detection_confidence="HIGH",
        status=status,
        metadata=metadata,
        sections=sections,
        warnings=warnings,
        completeness=completeness,
        sensitivity="MEDIUM",
        sanitization_status=sanitization_status,
        source_file_hash=source_hash,
        parse_timestamp=parse_ts,
        sections_extracted=sections_extracted,
        sections_missing=sections_missing,
    )
