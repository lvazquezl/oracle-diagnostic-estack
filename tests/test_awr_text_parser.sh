#!/usr/bin/env bash
# Valida que el parser AWR TEXT extraiga DB Time/DB CPU, Load Profile y top SQL sin SQL text.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys, json; sys.path.insert(0, '.')
from parsers.performance.awr_parser import parse_awr
with open('tests/fixtures/reports/awr-sample.txt', encoding='utf-8') as f:
    r = parse_awr(f.read(), is_html=False)
d = r.to_dict()['report']
assert d['source_type'] == 'AWR_TEXT'
assert d['sections']['db_time_cpu']['db_time_sec'] == '12018.00'
assert len(d['sections']['load_profile']) > 0
assert len(d['sections']['sql']) > 0
raw = json.dumps(d['sections']['sql'])
assert 'SELECT' not in raw.upper() or 'sql_id' in raw
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser AWR TEXT extrae DB Time/Load Profile/SQL sin SQL text"
else
  echo "[FAIL] Parser AWR TEXT falló: $OUT"
  FAIL=1
fi

exit $FAIL
