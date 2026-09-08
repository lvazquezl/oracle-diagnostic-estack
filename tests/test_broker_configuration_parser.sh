#!/usr/bin/env bash
# Valida parsers/dataguard/broker_parser.py::parse_show_configuration contra el fixture.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.dataguard.broker_parser import parse_show_configuration
with open('tests/fixtures/broker/show-configuration.txt') as f:
    text = f.read()
r = parse_show_configuration(text)
assert r.status.value == 'SUCCESS'
assert r.sections['configuration_status'] == 'SUCCESS'
assert r.sections['fsfo_enabled'] is True
assert len(r.sections['members']) == 2
print('[PASS] parse_show_configuration: status/fsfo/members correctos')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1
exit $FAIL
