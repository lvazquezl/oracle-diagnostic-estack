#!/usr/bin/env bash
# Valida parsers/rac/olsnodes_parser.py contra el fixture olsnodes.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.olsnodes_parser import parse_olsnodes
with open('tests/fixtures/collectors/olsnodes.txt') as f:
    text = f.read()
r = parse_olsnodes(text)
assert r.status.value == 'SUCCESS'
assert len(r.sections['nodes']) == 3
inactive = [n for n in r.sections['nodes'] if n['membership_status'] == 'Inactive']
assert len(inactive) == 1
print('[PASS] olsnodes_parser: 3 nodos, 1 Inactive detectado')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
