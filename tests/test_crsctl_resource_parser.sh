#!/usr/bin/env bash
# Valida parsers/rac/crsctl_resource_parser.py contra el fixture crsctl-stat-res.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.crsctl_resource_parser import parse_crsctl_resources
with open('tests/fixtures/collectors/crsctl-stat-res.txt') as f:
    text = f.read()
r = parse_crsctl_resources(text)
assert r.status.value == 'SUCCESS'
assert r.sections['total_resources'] == 17, r.sections['total_resources']
assert r.sections['offline'] == 3, r.sections['offline']
assert len(r.sections['anomalous_resources']) == 1, r.sections['anomalous_resources']
assert r.sections['anomalous_resources'][0]['resource'] == 'ora.orcl.svc1.svc'
print('[PASS] crsctl_resource_parser: total/offline/anomalous correctos')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
