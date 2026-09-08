#!/usr/bin/env bash
# Valida parsers/dataguard/broker_parser.py::parse_show_fsfo contra el fixture, y que nunca
# expone db_unique_name real en observer_status (regresión del fix de leak encontrado en sesión).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.dataguard.broker_parser import parse_show_fsfo
with open('tests/fixtures/broker/show-fsfo.txt') as f:
    r = parse_show_fsfo(f.read())
assert r.status.value == 'SUCCESS'
assert r.sections['enabled'] is True
assert r.sections['threshold_seconds'] == 30
assert r.sections['observer_status'] == 'CONNECTED'
assert 'observer_state' not in r.sections, 'observer_state no debe exponerse (leak de db_unique_name sin tokenizar)'
print('[PASS] parse_show_fsfo: enabled/threshold/observer correctos, sin leak')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && FAIL=1
exit $FAIL
