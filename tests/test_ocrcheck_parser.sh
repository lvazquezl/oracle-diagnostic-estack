#!/usr/bin/env bash
# Valida parsers/rac/ocrcheck_parser.py contra el fixture ocrcheck.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.ocrcheck_parser import parse_ocrcheck
with open('tests/fixtures/collectors/ocrcheck.txt') as f:
    text = f.read()
r = parse_ocrcheck(text)
assert r.status.value == 'SUCCESS'
assert r.sections['ocr_status'] == 'KNOWN'
assert r.sections['integrity_check'] == 'SUCCEEDED'
assert len(r.sections['copies']) == 2
print('[PASS] ocrcheck_parser: integrity_check SUCCEEDED, 2 copias detectadas')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
