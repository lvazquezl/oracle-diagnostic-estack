#!/usr/bin/env bash
# CHG-ESTACK-DICT-PSEUDO-COLUMNS-001: values of a NAME-like column that certified queries filter on (e.g.
# V$DATAGUARD_STATS.NAME = 'apply lag') live under `row_values:`, never as fake entries under `columns:`
# (which the real-catalog verification Q-DICT-VERIFY reported as COLUMN_NOT_FOUND). Every such literal a certified
# query uses must be registered, and every row_values column must be a declared column of its view.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import glob, re, sys
from mcp_gateway import catalog
text = open("compatibility/oracle-dictionary/views.yaml", encoding="utf-8").read()
starts = [(m.group(1), m.start()) for m in re.finditer(r"^  ([A-Z][A-Z0-9_$#]*):[ \t]*$", text, re.M)]
blocks = {v: text[p:(starts[i + 1][1] if i + 1 < len(starts) else len(text))] for i, (v, p) in enumerate(starts)}
fail, rowvals = [], {}
for view, b in blocks.items():
    cols = set(re.findall(r"^      ([a-z][a-z0-9_#$]*):[ \t]*\{", b.split("\n    row_values:")[0], re.M))
    for c in cols:
        if c.endswith("_row"):
            fail.append(f"{view}.{c}: pseudo-column under columns: (use row_values:)")
    if "\n    row_values:" not in b:
        continue
    rv = b.split("\n    row_values:", 1)[1]
    rv = rv.split("\n    notes:", 1)[0]
    current = None
    for line in rv.splitlines():
        m = re.match(r"^      ([a-z][a-z0-9_#$]*):[ \t]*$", line)
        if m:
            current = m.group(1)
            if current not in cols:
                fail.append(f"{view}.row_values.{current}: not a declared column of the view")
            continue
        m = re.match(r'^        "([^"]+)":[ \t]*\{min_version:[ \t]*("?[0-9.]+"?|all)\}[ \t]*$', line)
        if m and current:
            rowvals.setdefault(view, {}).setdefault(current, set()).add(m.group(1))
        elif line.strip() and not line.strip().startswith("#"):
            fail.append(f"{view}.row_values: malformed line {line.strip()!r}")
if not rowvals:
    fail.append("no row_values registered (expected V$DATAGUARD_STATS and V$PGASTAT)")
for f in glob.glob("queries/**/Q-*.md", recursive=True):
    if f.startswith("queries/oracle/dictionary/"):
        continue
    for blk in catalog.sql_blocks(open(f, encoding="utf-8").read()):
        low = blk.lower()
        for view, byc in rowvals.items():
            if not re.search(r"(?<![a-z0-9_$#])g?" + re.escape(view.lower().lstrip("g")) + r"(?![a-z0-9_$#])", low):
                continue
            for col, allowed in byc.items():
                used = set()
                for m in re.finditer(col + r"\s+in\s*\(([^)]*)\)", blk, re.I):
                    used |= set(re.findall(r"'([^']*)'", m.group(1)))
                used |= set(re.findall(r"decode\(\s*" + col + r"\s*,\s*'([^']*)'", blk, re.I))
                for u in sorted(used - allowed):
                    fail.append(f"{f}: {view}.{col} = '{u}' is not registered under row_values")
for x in fail:
    print("[FAIL] " + x)
if fail:
    sys.exit(1)
print("[PASS] row values are registered under row_values (%d views) and every certified filter on them uses registered values" % len(rowvals))
PY
