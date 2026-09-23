"""
mcp_gateway_lab.sqlsource — resolves the certified SQL variant for a collector, straight from queries/**/Q-*.md.

Every resolution re-reads the certified file and fails closed unless:
  * the front matter is still `status: active`, `risk_class: R0`, `execution_mode: READ_ONLY`;
  * the SHA-256 of all SQL blocks equals the hash the gateway catalog recorded at startup (no edit after startup);
  * exactly one declared variant covers the target's numeric Oracle version (docs/QUERY_VARIANTS.md), or, for a query
    that declares no `variants:`, its IMPLICIT variant: exactly one SQL block, and config/query-compatibility-matrix.yaml
    records it as `variants: implicit_full_range`, `validation_status: COMPATIBLE`, with a range covering the version;
  * the selected block passes the catalog's read-only guard (single SELECT/WITH, no DML/DDL/PL/SQL/packages).
The trailing ';' is removed only because the driver does not accept statement terminators.
"""
from __future__ import annotations

import hashlib
import os
import re

from mcp_gateway import catalog
from mcp_gateway.versions import compare_versions, parse_version

_VARIANT = re.compile(
    r'^  - variant_id: (?P<id>[A-Z0-9-]+)\n'
    r'(?:    (?!oracle_versions)[a-z_]+: .*\n)*?'
    r'    oracle_versions: \{min: "(?P<min>[0-9.]+)", max: (?:"(?P<max>[0-9.]+)"|(?P<latest>latest))\}\n'
    r'(?:    (?!sql_block)[a-z_]+: .*\n)*?'
    r'    sql_block: "(?P<block>[^"\n]{1,120})"$', re.M)
_IMPLICIT = re.compile(
    r'^  (?P<id>Q-[A-Z0-9-]{3,60}): \{file: (?P<file>[A-Za-z0-9_./-]{1,200}), variants: implicit_full_range, '
    r'min: "(?P<min>[0-9.]+)", max: (?:"(?P<max>[0-9.]+)"|(?P<latest>latest)), .*validation_status: COMPATIBLE[,}]', re.M)
MATRIX_FILE = os.path.join(catalog.REPO_ROOT, "config", "query-compatibility-matrix.yaml")
_BLOCK = re.compile(r'^# Statement / procedure \(read-only\) — (?P<label>[^\n]{1,120})\n+```sql\n(?P<sql>.*?)```', re.M | re.S)
MAX_SQL_CHARS = 4000


class SqlSourceError(RuntimeError):
    def __init__(self):
        super().__init__("certified SQL could not be resolved safely")


class Certified:
    def __init__(self, query_id, sql, variant_id, max_rows, max_output_bytes, timeout_seconds):
        self.query_id, self.sql, self.variant_id = query_id, sql, variant_id
        self.max_rows, self.max_output_bytes, self.timeout_seconds = max_rows, max_output_bytes, timeout_seconds
        self.sql_sha256 = hashlib.sha256(sql.encode("utf-8")).hexdigest()


def resolve(collector, db_version: str) -> Certified:
    """`db_version` is a dotted version ('19.0' for the family, or the observed '19.27.0.0.0')."""
    if collector.kind != "sql_query" or not collector.query_sha256 or parse_version(db_version) is None:
        raise SqlSourceError()
    path = catalog._find_query_file(collector.collector_id)
    if path is None:
        raise SqlSourceError()
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read(200_000)
    except OSError:
        raise SqlSourceError()
    fm = catalog._parse_front_matter(text)
    if fm.get("status") != "active" or fm.get("risk_class") != "R0" or fm.get("execution_mode") != "READ_ONLY":
        raise SqlSourceError()
    blocks = catalog.sql_blocks(text)
    if hashlib.sha256("\n".join(blocks).encode("utf-8")).hexdigest() != collector.query_sha256:
        raise SqlSourceError()                                    # certified file changed after the gateway started
    front = text.split("\n---\n", 1)[0]
    if re.search(r'^variants:', front, re.M):
        by_label = {m.group("label").strip(): m.group("sql").strip() for m in _BLOCK.finditer(text)}
        matches = [m for m in _VARIANT.finditer(front) if _covers(db_version, m)]
        if len(matches) != 1:
            raise SqlSourceError()
        m = matches[0]
        sql, variant_id = by_label.get(m.group("block")), m.group("id")
    else:
        sql, variant_id = _implicit_variant(collector.collector_id, path, blocks, db_version)
    if not sql or sql not in blocks:
        raise SqlSourceError()
    try:
        catalog.assert_read_only_sql(sql)
    except RuntimeError:
        raise SqlSourceError()
    stmt = sql.rstrip()
    stmt = stmt[:-1].rstrip() if stmt.endswith(";") else stmt
    if ";" in stmt or len(stmt) > MAX_SQL_CHARS:
        raise SqlSourceError()
    try:
        max_rows, max_bytes, timeout = int(fm["max_rows"]), int(fm["max_output_bytes"]), int(fm["timeout_seconds"])
    except (KeyError, ValueError):
        raise SqlSourceError()
    return Certified(collector.collector_id, stmt, variant_id, max_rows, max_bytes, timeout)


def _covers(db_version: str, m) -> bool:
    lo_ok = compare_versions(db_version, m.group("min")) in (0, 1)
    hi_ok = True if m.group("latest") else compare_versions(db_version, m.group("max") + ".99.99.99") in (-1, 0)
    return lo_ok and hi_ok


def _implicit_variant(query_id: str, path: str, blocks: list, db_version: str):
    """A query without `variants:` has ONE implicit variant (docs/QUERY_VARIANTS.md), usable only when the compatibility
    matrix certifies it as implicit_full_range + COMPATIBLE for this file and version. Anything else fails closed."""
    if len(blocks) != 1:
        raise SqlSourceError()
    try:
        with open(MATRIX_FILE, encoding="utf-8") as f:
            matrix = f.read(500_000)
    except OSError:
        raise SqlSourceError()
    entries = [m for m in _IMPLICIT.finditer(matrix) if m.group("id") == query_id]
    if len(entries) != 1 or len(re.findall(r'^  ' + re.escape(query_id) + r':', matrix, re.M)) != 1:
        raise SqlSourceError()
    m = entries[0]
    if os.path.realpath(os.path.join(catalog.REPO_ROOT, m.group("file"))) != os.path.realpath(path) or not _covers(db_version, m):
        raise SqlSourceError()
    return blocks[0], query_id + "-IMPLICIT"
