#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.show_all_parser import parse_show_all
text = '''CONFIGURE RETENTION POLICY TO REDUNDANCY 2; # default
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/u01/app/oracle/product/19.0.0/dbhome_1/dbs/snapcf_orcl.f';'''
r = parse_show_all(text)
print(r.status.value)
assert len(r.sections['configuration']) == 3, r.sections
assert r.sections['configuration'][0]['is_default'] is True
assert 'PATH_TOKEN' in r.sections['configuration'][2]['config'], r.sections['configuration'][2]
print('OK')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "^SUCCESS$" && echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_show_all extrae configuración y sanitiza SNAPSHOT CONTROLFILE NAME" || { echo "[FAIL] parse_show_all no se comportó como se esperaba"; FAIL=1; }

exit $FAIL
