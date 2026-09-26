#!/usr/bin/env bash
# CHG-ESTACK-ORA19C-LAB-006: Q-DICT-VERIFY-00N are GENERATED from compatibility/oracle-dictionary/views.yaml. They must
# match the dictionary exactly (no hand edits, no drift), fit the lab SQL ceiling, pass the read-only guard, and the
# generator's copy of the guard regex must be the gateway's own.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import sys
from scripts.dict_verify import generate as g
from mcp_gateway import catalog
from mcp_gateway_lab import sqlsource
fail = []
probs = g.check()
fail += probs
if g._FORBIDDEN.pattern != catalog._FORBIDDEN_SQL.pattern:
    fail.append("generator guard regex differs from mcp_gateway/catalog.py _FORBIDDEN_SQL")
if g.MAX_SQL_CHARS != sqlsource.MAX_SQL_CHARS:
    fail.append("generator MAX_SQL_CHARS differs from mcp_gateway_lab/sqlsource.py")
files, specs, skipped = g.generate()
for path, text in files.items():
    blocks = catalog.sql_blocks(text)
    if len(blocks) != 1:
        fail.append(path + ": expected exactly one SQL block")
        continue
    stmt = blocks[0].rstrip().rstrip(";").rstrip()
    try:
        catalog.assert_read_only_sql(blocks[0])
    except RuntimeError:
        fail.append(path + ": refused by the read-only guard")
    if len(stmt) > sqlsource.MAX_SQL_CHARS:
        fail.append(path + ": statement longer than the lab ceiling")
tokens, _ = g.load_tokens()
covered = [t for p in g.chunk(tokens) for t in p]
if covered != tokens or len(set(covered)) != len(covered):
    fail.append("parts do not cover every token exactly once")
if skipped != ["V$LOCK"]:
    fail.append("unexpected tokens skipped by the guard (document them before accepting): %s" % skipped)
for f in fail:
    print("[FAIL] " + f)
if fail:
    sys.exit(1)
print("[PASS] %d Q-DICT-VERIFY queries match the dictionary (%d tokens), fit the lab ceiling and pass the read-only guard" % (len(files), len(tokens)))
PY
