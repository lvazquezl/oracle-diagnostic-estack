#!/usr/bin/env bash
# Valida parsers/rac/lsnrctl_status_parser.py contra el fixture lsnrctl-status.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.lsnrctl_status_parser import parse_lsnrctl_status
with open('tests/fixtures/collectors/lsnrctl-status.txt') as f:
    text = f.read()
r = parse_lsnrctl_status(text)
assert r.status.value == 'SUCCESS'
assert r.sections['listener'] == 'LISTENER'
assert len(r.sections['services_registered']) == 2
print('[PASS] lsnrctl_status_parser: listener + 2 servicios registrados detectados')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
