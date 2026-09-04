#!/usr/bin/env bash
# Valida parsers/rac/voting_parser.py contra el fixture voting.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.voting_parser import parse_voting
with open('tests/fixtures/collectors/voting.txt') as f:
    text = f.read()
r = parse_voting(text)
assert r.status.value == 'SUCCESS'
assert r.sections['located_count'] == 3
assert r.sections['quorum_at_risk'] is False
print('[PASS] voting_parser: 3 voting disks, quorum_at_risk=False')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
