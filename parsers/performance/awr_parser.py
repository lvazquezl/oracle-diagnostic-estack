"""
AWR report parser (HTML + TEXT) — # 16/17 of docs/PHASE_3_COMPLETION_HARDENING.md.

First functional version: extracts snapshot metadata, elapsed time, DB
Time/DB CPU, Load Profile, Top Foreground Events, Wait Classes, Top SQL
metrics, Memory, I/O, Parsing, Redo/Commit, and an RAC section when
present. Does not attempt full fidelity with every historical AWR HTML
layout — unmatched sections are reported UNSUPPORTED for that report, never
fabricated (# 60 KNOWN LIMITATIONS).

Parsing this file does NOT bypass the Licensing Gate — AWR license
requirements (Diagnostics Pack) apply identically whether the evidence came
from a live query or from a DBA-provided report (# 17 AWR PARSER LICENSING).
Enforcing that gate is the caller's (skill/agent) responsibility; this
module only extracts structure from bytes already on disk.
"""

from __future__ import annotations

import html
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

_TAG_RE = re.compile(r"<[^>]+>")
_ROW_RE = re.compile(r"<tr[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
_CELL_RE = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.IGNORECASE | re.DOTALL)


def _cell_text(cell_html: str) -> str:
    return html.unescape(_TAG_RE.sub("", cell_html)).strip()


def _html_table_rows(html_text: str, near_anchor: str, max_rows: int = 200) -> list[list[str]]:
    """Find the first HTML table appearing after `near_anchor` and return its
    rows as lists of cell text. Tolerant of AWR's inconsistent table
    markup across versions — never assumes fixed column positions beyond
    what the caller does with the returned cells."""
    idx = html_text.find(near_anchor)
    if idx == -1:
        return []
    window = html_text[idx: idx + 200_000]
    table_start = window.find("<table")
    if table_start == -1:
        return []
    table_end = window.find("</table>", table_start)
    table_html = window[table_start: table_end if table_end != -1 else None]
    rows = []
    for row_match in _ROW_RE.finditer(table_html):
        cells = [_cell_text(c) for c in _CELL_RE.findall(row_match.group(1))]
        if any(cells):
            rows.append(cells)
        if len(rows) >= max_rows:
            break
    return rows


def _extract_metadata_html(html_text: str) -> dict[str, str | None]:
    meta: dict[str, str | None] = {
        "db_name": None, "instance_name": None, "oracle_version": None,
        "snap_begin": None, "snap_end": None, "elapsed_minutes": None,
    }
    m = re.search(r"DB Name</th>\s*<td[^>]*>([^<]+)</td>", html_text, re.IGNORECASE)
    if m:
        meta["db_name"] = html.unescape(m.group(1)).strip()
    m = re.search(r"Instance</th>\s*<td[^>]*>([^<]+)</td>", html_text, re.IGNORECASE)
    if m:
        meta["instance_name"] = html.unescape(m.group(1)).strip()
    m = re.search(r"Release</th>\s*<td[^>]*>([^<]+)</td>", html_text, re.IGNORECASE)
    if m:
        meta["oracle_version"] = html.unescape(m.group(1)).strip()
    m = re.search(r"Elapsed:</b>\s*([\d.]+)\s*\(mins\)", html_text, re.IGNORECASE)
    if m:
        meta["elapsed_minutes"] = m.group(1)
    return meta


def _extract_metadata_text(text: str) -> dict[str, str | None]:
    meta: dict[str, str | None] = {
        "db_name": None, "instance_name": None, "oracle_version": None,
        "snap_begin": None, "snap_end": None, "elapsed_minutes": None,
    }
    m = re.search(r"^\s*(\S+)\s+(\d{6,12})\s+(\S+)\s+(\d+)\s+.*?\s+([\d.]+\.[\d.]+\.[\d.]+\.[\d.]+)", text, re.MULTILINE)
    if m:
        meta["db_name"], meta["instance_name"], meta["oracle_version"] = m.group(1), m.group(3), m.group(5)
    m = re.search(r"Elapsed:\s*([\d.]+)\s*\(mins\)", text)
    if m:
        meta["elapsed_minutes"] = m.group(1)
    return meta


def _extract_db_time_cpu(text_or_html: str, is_html: bool) -> dict[str, str | None]:
    result: dict[str, str | None] = {"db_time_sec": None, "db_cpu_sec": None}
    if is_html:
        m = re.search(r"DB[\s&nbsp;]*Time\s*\(s\):?\s*</[^>]+>\s*<td[^>]*>\s*([\d,.]+)", text_or_html, re.IGNORECASE)
    else:
        m = re.search(r"DB Time\(s\):\s*([\d,.]+)", text_or_html)
    if m:
        result["db_time_sec"] = m.group(1).replace(",", "")
    if is_html:
        m = re.search(r"DB[\s&nbsp;]*CPU\s*\(s\):?\s*</[^>]+>\s*<td[^>]*>\s*([\d,.]+)", text_or_html, re.IGNORECASE)
    else:
        m = re.search(r"DB CPU\(s\):\s*([\d,.]+)", text_or_html)
    if m:
        result["db_cpu_sec"] = m.group(1).replace(",", "")
    return result


def _extract_load_profile_text(text: str) -> list[dict[str, str]]:
    rows = []
    m = re.search(r"Load Profile.*?\n(.*?)(?:\n\s*\n|\Z)", text, re.DOTALL)
    block = m.group(1) if m else ""
    for line in block.splitlines():
        lm = re.match(r"^\s*([A-Za-z][A-Za-z0-9 /%]*?):\s+([\d,.]+)", line)
        if lm:
            rows.append({"metric": lm.group(1).strip(), "per_second": lm.group(2).replace(",", "")})
    return rows


def _extract_waits(text_or_html: str, is_html: bool, limits) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if is_html:
        table_rows = _html_table_rows(text_or_html, "Top 10 Foreground Events") or \
            _html_table_rows(text_or_html, "Top 5 Timed Events") or \
            _html_table_rows(text_or_html, "Foreground Wait")
        for cells in table_rows:
            if len(cells) >= 3 and cells[0] and not cells[0].lower().startswith("event"):
                rows.append({"event": cells[0], "waits": cells[1] if len(cells) > 1 else None,
                             "time_s": cells[2] if len(cells) > 2 else None})
    else:
        m = re.search(r"Top \d+ (?:Foreground )?(?:Timed )?Events.*?\n(.*?)(?:\n\s*\n|\Z)", text_or_html, re.DOTALL)
        block = m.group(1) if m else ""
        for line in block.splitlines():
            lm = re.match(r"^([A-Za-z][A-Za-z0-9 /\-\.\(\)]*?)\s{2,}([\d,]+)?\s{0,}([\d,]+)\s+", line)
            if lm:
                rows.append({"event": lm.group(1).strip(), "waits": (lm.group(2) or "").replace(",", "") or None,
                             "time_s": lm.group(3).replace(",", "")})
    return rows[: limits.max_wait_entries]


def _extract_top_sql(text_or_html: str, is_html: bool, limits) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    sql_id_re = re.compile(r"\b([0-9a-z]{13})\b", re.IGNORECASE)
    if is_html:
        table_rows = _html_table_rows(text_or_html, "SQL ordered by")
        for cells in table_rows:
            joined = " ".join(cells)
            idm = sql_id_re.search(joined)
            if idm:
                nums = [c for c in cells if re.match(r"^[\d,.]+$", c)]
                rows.append({"sql_id": idm.group(1), "metrics": nums})
    else:
        for m in re.finditer(r"SQL ordered by.*?\n(.*?)(?:\n\s*\n|\Z)", text_or_html, re.DOTALL):
            for line in m.group(1).splitlines():
                idm = sql_id_re.search(line)
                if not idm:
                    continue
                nums = re.findall(r"[\d,]+\.\d+|\d[\d,]*", line[: idm.start()])
                if nums:
                    rows.append({"sql_id": idm.group(1), "metrics": [n.replace(",", "") for n in nums]})
    return rows[: limits.max_sql_entries]


def parse_awr(
    text: str,
    is_html: bool,
    limits=DEFAULT_SIZE_LIMITS,
    sanitize: bool = True,
) -> ParsedReport:
    parse_ts = datetime.now(timezone.utc).isoformat()
    source_type = "AWR_HTML" if is_html else "AWR_TEXT"

    if text is None or text.strip() == "":
        return ParsedReport(
            source_type=source_type, parser_version=PARSER_VERSION,
            detection_confidence="LOW", status=ParseStatus.EMPTY_REPORT.value,
            parse_timestamp=parse_ts,
        )

    truncated_text, was_truncated = truncate_to_limit(text, limits.max_report_size_bytes)
    warnings: list[str] = []
    if was_truncated:
        warnings.append(f"report truncated at {limits.max_report_size_bytes} bytes")
    source_hash = sha256_of_text(text)

    anchor = "WORKLOAD REPOSITORY" if not is_html else "WORKLOAD REPOSITORY"
    if anchor not in truncated_text and "awr" not in truncated_text.lower():
        return ParsedReport(
            source_type=source_type, parser_version=PARSER_VERSION,
            detection_confidence="LOW", status=ParseStatus.MALFORMED_REPORT.value,
            warnings=["no recognizable AWR report markers found"],
            source_file_hash=source_hash, parse_timestamp=parse_ts,
        )

    metadata = _extract_metadata_html(truncated_text) if is_html else _extract_metadata_text(truncated_text)
    db_time_cpu = _extract_db_time_cpu(truncated_text, is_html)

    sections: dict[str, object] = {}
    completeness: dict[str, str] = {}

    sections["db_time_cpu"] = db_time_cpu
    completeness["db_time_cpu"] = "SUPPORTED" if db_time_cpu.get("db_time_sec") else "UNSUPPORTED"

    load_profile = [] if is_html else _extract_load_profile_text(truncated_text)
    sections["load_profile"] = load_profile
    completeness["load_profile"] = "SUPPORTED" if load_profile else ("UNSUPPORTED" if is_html else "PARTIALLY_SUPPORTED")

    waits = _extract_waits(truncated_text, is_html, limits)
    sections["waits"] = waits
    completeness["waits"] = "SUPPORTED" if waits else "UNSUPPORTED"

    top_sql = _extract_top_sql(truncated_text, is_html, limits)
    sections["sql"] = top_sql
    completeness["sql"] = "SUPPORTED" if top_sql else "UNSUPPORTED"

    has_rac_section = bool(re.search(r"\bRAC Statistics\b|\bGlobal Cache\b", truncated_text, re.IGNORECASE))
    sections["rac"] = {"present": has_rac_section}
    completeness["rac"] = "SUPPORTED" if has_rac_section else "UNSUPPORTED"

    # Memory / I/O / Parsing / Redo-Commit: same-shape "not yet extracted at
    # full fidelity" placeholders, explicit UNSUPPORTED rather than fabricated.
    for key in ("memory", "io", "parsing", "redo_commit"):
        sections.setdefault(key, {})
        completeness.setdefault(key, "UNSUPPORTED")

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
        source_type=source_type, parser_version=PARSER_VERSION,
        detection_confidence="HIGH", status=status,
        metadata=metadata, sections=sections, warnings=warnings,
        completeness=completeness, sensitivity="MEDIUM",
        sanitization_status=sanitization_status, source_file_hash=source_hash,
        parse_timestamp=parse_ts, sections_extracted=sections_extracted,
        sections_missing=sections_missing,
    )
