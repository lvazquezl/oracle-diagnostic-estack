#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.report_need_backup_parser import parse_report_need_backup
r1 = parse_report_need_backup('Report of files that must be backed up to satisfy 7 days recovery window\nno datafiles found')
assert r1.sections['need_backup'] == [], r1.sections
r2 = parse_report_need_backup('File #4  8 days  20260220  ...')
assert len(r2.sections['need_backup']) == 1, r2.sections
print(r1.status.value, r2.status.value)
print('OK')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "^SUCCESS SUCCESS$" && echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_report_need_backup distingue vacío vs. filas reales" || { echo "[FAIL] parse_report_need_backup no se comportó como se esperaba"; FAIL=1; }

exit $FAIL
