"""Typed bind parameters for certified queries on the human-reported route (CHG-ESTACK-SEC-QUERIES-001).

SQL*Plus cannot bind `:name` from a spooled script without PL/SQL, and the e-stack never emits PL/SQL. Instead, after
the certified SQL was resolved and hash-verified, each bind is replaced by a literal of its declared type
(config/query-parameters.json). Only digits, an ISO timestamp, a 13-char sql_id or an upper-case Oracle name can be
rendered: no quote, comment or statement separator can come from a value. The result is checked by the read-only
guard again and its own sha256 is recorded with the request.
"""
import json
import os
import re
from datetime import datetime

from mcp_gateway import catalog

TYPES_FILE = os.path.join(catalog.REPO_ROOT, "config", "query-parameters.json")
_TS = re.compile(r"^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}$")
_SQL_ID = re.compile(r"^[0-9a-z]{13}$")
_ORACLE_NAME = re.compile(r"^[A-Z][A-Z0-9_$#]{0,127}$")
_INT = re.compile(r"^\d{1,10}$")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


class ParameterError(ValueError):
    pass


def _types() -> dict:
    with open(TYPES_FILE, encoding="utf-8") as f:
        return json.load(f)["parameters"]


def _scan(sql: str):
    """Yield (kind, text) chunks: 'lit' for '...' literals and -- / /* */ comments, 'bind' for :name, 'sql' otherwise."""
    i, n, buf = 0, len(sql), []
    while i < n:
        c = sql[i]
        if c == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'" and j + 1 < n and sql[j + 1] == "'":
                    j += 2
                    continue
                if sql[j] == "'":
                    break
                j += 1
            yield "sql", "".join(buf); buf = []
            yield "lit", sql[i:j + 1]
            i = j + 1
        elif sql.startswith("--", i) or sql.startswith("/*", i):
            j = sql.find("\n", i) if sql.startswith("--", i) else sql.find("*/", i) + 2
            j = n if j <= 0 else j
            yield "sql", "".join(buf); buf = []
            yield "lit", sql[i:j]
            i = j
        elif c == ":" and (i == 0 or not (sql[i - 1].isalnum() or sql[i - 1] in "_:")):
            m = _NAME.match(sql, i + 1)
            if m:
                yield "sql", "".join(buf); buf = []
                yield "bind", m.group(0)
                i = m.end()
            else:
                buf.append(c); i += 1
        else:
            buf.append(c); i += 1
    yield "sql", "".join(buf)


def binds_of(sql: str) -> list:
    out = []
    for kind, text in _scan(sql):
        if kind == "bind" and text not in out:
            out.append(text)
    return out


def describe(name: str, spec: dict) -> str:
    t = spec["type"]
    if t == "integer":
        return f"{name} (integer {spec['min']}..{spec['max']})"
    return f"{name} ({ {'timestamp': 'YYYY-MM-DDTHH:MM:SS', 'sql_id': '13-char sql_id', 'oracle_name': 'UPPER_CASE Oracle name'}[t] })"


def _literal(name: str, value: str, spec: dict) -> str:
    t = spec["type"]
    if t == "integer":
        if not isinstance(value, str) or not _INT.match(value) or not spec["min"] <= int(value) <= spec["max"]:
            raise ParameterError(f"invalid value for parameter {name}")
        return str(int(value))
    if t == "timestamp":
        if not isinstance(value, str) or not _TS.match(value):
            raise ParameterError(f"invalid value for parameter {name}")
        try:
            datetime.strptime(value.replace("T", " "), "%Y-%m-%d %H:%M:%S")
        except ValueError:
            raise ParameterError(f"invalid value for parameter {name}")
        return "TO_DATE('" + value.replace("T", " ") + "', 'YYYY-MM-DD HH24:MI:SS')"
    if t == "sql_id" and isinstance(value, str) and _SQL_ID.match(value):
        return "'" + value + "'"
    if t == "oracle_name" and isinstance(value, str) and _ORACLE_NAME.match(value):
        return "'" + value + "'"
    raise ParameterError(f"invalid value for parameter {name}")


def render(sql: str, params: dict) -> str:
    """The certified SQL with every bind replaced by its typed literal. Missing, unknown or invalid → ParameterError."""
    types = _types()
    needed = binds_of(sql)
    params = dict(params or {})
    unknown = sorted(set(params) - set(needed))
    if unknown:
        raise ParameterError("this query does not take parameter(s): " + ", ".join(unknown))
    missing = [b for b in needed if b not in params]
    if missing:
        raise ParameterError("this query requires parameters: " + "; ".join(
            describe(b, types[b]) if b in types else f"{b} (not supported on this route)" for b in missing))
    for b in needed:
        if b not in types:
            raise ParameterError(f"parameter {b} is not supported on this route")
    lits = {b: _literal(b, params[b], types[b]) for b in needed}
    if "window_start" in params and "window_end" in params and params["window_start"].replace("T", " ") >= params["window_end"].replace("T", " "):
        raise ParameterError("window_start must be before window_end")
    out = "".join(lits[text] if kind == "bind" else text for kind, text in _scan(sql))
    catalog.assert_read_only_sql(out)
    return out
