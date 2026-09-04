#!/usr/bin/env bash
# Valida parsers/rac/srvctl_service_parser.py contra el fixture srvctl-config-service.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.srvctl_service_parser import parse_srvctl_service_config
with open('tests/fixtures/collectors/srvctl-config-service.txt') as f:
    text = f.read()
r = parse_srvctl_service_config(text)
assert r.status.value == 'SUCCESS'
assert r.sections['clb_goal'] == 'LONG'
assert r.sections['rlb_goal'] == 'SERVICE_TIME'
assert len(r.sections['preferred_instances']) == 1
print('[PASS] srvctl_service_parser: clb_goal/rlb_goal/preferred_instances correctos')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
