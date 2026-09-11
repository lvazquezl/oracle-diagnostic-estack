#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.list_backup_parser import parse_list_backup
text = '''BS Key  Type LV Size
101     Full    944.00M
  Piece Name: /backup/orcl_full_01.bkp
  Tag: TAG20260228'''
r = parse_list_backup(text)
print(r.status.value)
assert len(r.sections['backup_sets']) == 1, r.sections
assert len(r.sections['pieces']) == 1, r.sections
assert r.sections['pieces'][0]['piece_name'].startswith('HANDLE_TOKEN'), r.sections
print('OK')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "^SUCCESS$" && echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_list_backup extrae backup sets y piezas, tokeniza handle" || { echo "[FAIL] parse_list_backup no se comportó como se esperaba"; FAIL=1; }

exit $FAIL
