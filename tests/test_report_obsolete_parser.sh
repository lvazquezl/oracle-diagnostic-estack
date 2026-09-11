#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.report_obsolete_parser import parse_report_obsolete
r1 = parse_report_obsolete('RMAN retention policy will be applied to the command\nno obsolete backups found')
assert r1.sections['obsolete_count'] == 0, r1.sections
r2 = parse_report_obsolete('Backup Set    12   14-JAN-24\nArchive Log   45   14-JAN-24')
assert r2.sections['obsolete_count'] == 2, r2.sections
print(r1.status.value, r2.status.value)
print('OK')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "^SUCCESS SUCCESS$" && echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_report_obsolete distingue 0 vs. N obsoletos" || { echo "[FAIL] parse_report_obsolete no se comportó como se esperaba"; FAIL=1; }

exit $FAIL
