#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.list_backup_summary_parser import parse_list_backup_summary
text = '12  B  A  A  DISK  14-JAN-24  1  1  NO  TAG20240114020000'
r = parse_list_backup_summary(text)
print(r.status.value)
assert len(r.sections['summary']) == 1, r.sections
row = r.sections['summary'][0]
assert row['status'] == 'AVAILABLE', row
assert row['tag'].startswith('TAG_TOKEN'), row
print('OK')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "^SUCCESS$" && echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_list_backup_summary extrae filas y tokeniza TAG" || { echo "[FAIL] parse_list_backup_summary no se comportó como se esperaba"; FAIL=1; }

exit $FAIL
