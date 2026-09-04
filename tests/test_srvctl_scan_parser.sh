#!/usr/bin/env bash
# Valida parsers/rac/srvctl_scan_parser.py contra los fixtures srvctl-config/status-scan.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.srvctl_scan_parser import parse_srvctl_scan_config, parse_srvctl_scan_status
with open('tests/fixtures/collectors/srvctl-config-scan.txt') as f:
    c = parse_srvctl_scan_config(f.read())
with open('tests/fixtures/collectors/srvctl-status-scan.txt') as f:
    s = parse_srvctl_scan_status(f.read())
assert c.status.value == 'SUCCESS'
assert len(c.sections['configured_ips']) == 3
assert s.status.value == 'SUCCESS'
offline = [l for l in s.sections['scan_listeners'] if l['status'] == 'OFFLINE']
assert len(offline) == 1
print('[PASS] srvctl_scan_parser: 3 IPs configuradas, 1 SCAN listener OFFLINE detectado')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1

exit $FAIL
