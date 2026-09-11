#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.restore_preview_parser import parse_restore_preview
text = '''restoring datafile 00001
handle=/backup/orcl_full_01.bkp media=DISK
media recovery start'''
r = parse_restore_preview(text)
print(r.status.value)
assert r.sections['datafiles_covered'] == ['00001'], r.sections
assert r.sections['restore_blocked'] is False, r.sections
assert r.sections['media_recovery_expected'] is True, r.sections
assert r.sections['pieces_required'][0]['handle'].startswith('HANDLE_TOKEN'), r.sections
print('OK')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "^SUCCESS$" && echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_restore_preview extrae datafiles/piezas sin ejecutar nada" || { echo "[FAIL] parse_restore_preview no se comportó como se esperaba"; FAIL=1; }

echo "$ROOT" > /dev/null
grep -rqi 'nunca ejecuta\|nunca se ejecuta\|nunca invocado\|never execut' "$ROOT/parsers/rman/restore_preview_parser.py" && echo "[PASS] el parser documenta que RESTORE PREVIEW nunca se ejecuta" || { echo "[FAIL] falta la prohibición explícita en el parser"; FAIL=1; }

exit $FAIL
