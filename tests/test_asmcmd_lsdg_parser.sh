#!/usr/bin/env bash
# Valida parsers/rac/asmcmd_lsdg_parser.py contra el fixture asmcmd-lsdg.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.asmcmd_lsdg_parser import parse_asmcmd_lsdg
with open('tests/fixtures/collectors/asmcmd-lsdg.txt') as f:
    text = f.read()
r = parse_asmcmd_lsdg(text)
assert r.status.value == 'SUCCESS'
assert len(r.sections['diskgroups']) == 2
assert r.sections['diskgroups'][0]['usable_file_mb'] == 76800
print('[PASS] asmcmd_lsdg_parser: 2 diskgroups, usable_file_mb correcto')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
