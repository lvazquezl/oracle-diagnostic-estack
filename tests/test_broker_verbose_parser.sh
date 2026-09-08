#!/usr/bin/env bash
# Valida parsers/dataguard/broker_parser.py::parse_show_database_verbose contra el fixture.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.dataguard.broker_parser import parse_show_database_verbose
with open('tests/fixtures/broker/show-database-verbose.txt') as f:
    r = parse_show_database_verbose(f.read())
assert r.status.value == 'SUCCESS'
assert r.sections['properties']['LogXptMode'] == 'SYNC'
assert r.sections['properties']['MaxFailure'] == '0'
print('[PASS] parse_show_database_verbose: properties extraídas correctamente')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1
exit $FAIL
