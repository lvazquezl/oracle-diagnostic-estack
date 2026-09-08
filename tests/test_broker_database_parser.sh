#!/usr/bin/env bash
# Valida parsers/dataguard/broker_parser.py::parse_show_database contra fixtures healthy y warning.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.dataguard.broker_parser import parse_show_database
with open('tests/fixtures/broker/show-database.txt') as f:
    r1 = parse_show_database(f.read())
assert r1.status.value == 'SUCCESS'
assert r1.sections['database_status'] == 'SUCCESS'
assert r1.sections['transport_lag_seconds'] == 0
with open('tests/fixtures/broker/show-database-warning.txt') as f:
    r2 = parse_show_database(f.read())
assert r2.sections['database_status'] == 'WARNING'
assert r2.sections['apply_lag_seconds'] == 340
assert r2.sections['warnings'][0]['code'] == 'ORA-16826'
print('[PASS] parse_show_database: healthy y warning correctos')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1
exit $FAIL
