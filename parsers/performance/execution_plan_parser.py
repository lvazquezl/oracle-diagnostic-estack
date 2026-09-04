"""
Execution plan text parser — # 19 of docs/PHASE_3_COMPLETION_HARDENING.md.

Supports the textual layout produced by DBMS_XPLAN.DISPLAY,
DBMS_XPLAN.DISPLAY_CURSOR and classic EXPLAIN PLAN output — a pipe-delimited
"| Id | Operation | Name | Rows | Bytes | Cost (%CPU) | Time |" table plus
an optional "Predicate Information" block and parallel-related columns
(TQ/IN-OUT/PQ Distrib) when present.

Never asserts an unrecognized text blob is a valid plan — if the pipe-table
signature is not found, status is UNSUPPORTED_FORMAT, not a best-effort
guess (# 19: "No afirmar que un formato no reconocido es un plan válido").
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from .common import (
    DEFAULT_SIZE_LIMITS,
    ParsedReport,
    ParseStatus,
    Sanitizer,
    sha256_of_text,
    truncate_to_limit,
)

PARSER_VERSION = "1.0.0"

_PLAN_HASH_RE = re.compile(r"Plan hash value:\s*(\d+)")
_HEADER_RE = re.compile(r"^\|\s*Id\s*\|\s*Operation", re.MULTILINE)
_ROW_RE = re.compile(
    r"^\|\*?\s*(\d+)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|"
    r"\s*([\d,]*)\s*\|\s*([\d,]*[KMG]?)\s*\|\s*([\d,]*)\s*(?:\(([\d]+)\))?\s*\|\s*([^|]*?)\s*\|\s*$",
    re.MULTILINE,
)
_PREDICATE_RE = re.compile(r"^\s*(\d+)\s*-\s*(access|filter)\((.+)\)\s*$", re.MULTILINE | re.IGNORECASE)


def _has_plan_table(text: str) -> bool:
    return bool(_HEADER_RE.search(text))


def _extract_operations(text: str, max_rows: int) -> list[dict[str, object]]:
    ops = []
    for m in _ROW_RE.finditer(text):
        op_id, operation, name, rows, bytes_, cost, pct_cpu, time_ = m.groups()
        if not operation and not name:
            continue
        ops.append({
            "id": int(op_id),
            "operation": operation.strip(),
            "object_token": name.strip() or None,
            "rows": rows.replace(",", "") or None,
            "bytes": bytes_ or None,
            "cost": cost.replace(",", "") or None,
            "pct_cpu": pct_cpu,
            "time": time_.strip() or None,
        })
        if len(ops) >= max_rows:
            break
    return ops


def _extract_predicates(text: str) -> dict[str, list[dict[str, str]]]:
    predicates: dict[str, list[dict[str, str]]] = {}
    m = re.search(r"Predicate Information.*?\n-+\n(.*?)(?:\n\s*\n|\Z)", text, re.DOTALL)
    block = m.group(1) if m else text
    for pm in _PREDICATE_RE.finditer(block):
        op_id, kind, expr = pm.group(1), pm.group(2).lower(), pm.group(3).strip()
        predicates.setdefault(op_id, []).append({"type": kind, "expression": expr})
    return predicates


def _has_parallel_indicators(text: str) -> bool:
    return bool(re.search(r"\bTQ\b|\bIN-OUT\b|\bPQ Distrib\b|PX COORDINATOR|PX BLOCK ITERATOR", text))


def parse_execution_plan_text(
    text: str,
    limits=DEFAULT_SIZE_LIMITS,
    sanitize: bool = True,
) -> ParsedReport:
    parse_ts = datetime.now(timezone.utc).isoformat()

    if text is None or text.strip() == "":
        return ParsedReport(
            source_type="EXECUTION_PLAN_TEXT", parser_version=PARSER_VERSION,
            detection_confidence="LOW", status=ParseStatus.EMPTY_REPORT.value,
            parse_timestamp=parse_ts,
        )

    truncated_text, was_truncated = truncate_to_limit(text, limits.max_report_size_bytes)
    warnings: list[str] = []
    if was_truncated:
        warnings.append(f"report truncated at {limits.max_report_size_bytes} bytes")
    source_hash = sha256_of_text(text)

    if not _has_plan_table(truncated_text):
        return ParsedReport(
            source_type="EXECUTION_PLAN_TEXT", parser_version=PARSER_VERSION,
            detection_confidence="LOW", status=ParseStatus.UNSUPPORTED_FORMAT.value,
            warnings=["no 'Id | Operation' plan table signature found — not treated as a valid plan"],
            source_file_hash=source_hash, parse_timestamp=parse_ts,
        )

    hash_m = _PLAN_HASH_RE.search(truncated_text)
    plan_hash_value = hash_m.group(1) if hash_m else None

    operations = _extract_operations(truncated_text, limits.max_plan_rows)
    predicates = _extract_predicates(truncated_text)
    has_parallel = _has_parallel_indicators(truncated_text)

    if sanitize:
        sanitizer = Sanitizer()
        for op in operations:
            if op.get("object_token"):
                op["object_token"] = sanitizer.object_name(op["object_token"])
        for op_id, preds in predicates.items():
            for p in preds:
                # predicates may contain application literals — object/column
                # names kept, literal values masked conservatively
                p["expression"] = re.sub(r"'[^']*'", "'<MASKED_LITERAL>'", p["expression"])
        sanitization_status = "APPLIED"
    else:
        sanitization_status = "NOT_APPLIED"

    sections = {
        "plan_hash_value": plan_hash_value,
        "operations": operations,
        "predicates": predicates,
        "parallel_indicators_present": has_parallel,
    }
    completeness = {
        "operations": "SUPPORTED" if operations else "PARTIALLY_SUPPORTED",
        "predicates": "SUPPORTED" if predicates else "UNSUPPORTED",
        "plan_hash_value": "SUPPORTED" if plan_hash_value else "UNSUPPORTED",
    }
    if len(operations) >= limits.max_plan_rows:
        warnings.append(f"plan operations truncated to {limits.max_plan_rows} rows")

    sections_extracted = [k for k, v in completeness.items() if v != "UNSUPPORTED"]
    sections_missing = [k for k, v in completeness.items() if v == "UNSUPPORTED"]
    status = ParseStatus.SUCCESS.value if (operations and not sections_missing) else ParseStatus.PARTIAL.value

    return ParsedReport(
        source_type="EXECUTION_PLAN_TEXT", parser_version=PARSER_VERSION,
        detection_confidence="HIGH", status=status,
        metadata={"plan_hash_value": plan_hash_value},
        sections=sections, warnings=warnings, completeness=completeness,
        sensitivity="LOW", sanitization_status=sanitization_status,
        source_file_hash=source_hash, parse_timestamp=parse_ts,
        sections_extracted=sections_extracted, sections_missing=sections_missing,
    )
