#!/usr/bin/env bash
# Valida que el parser AWR HTML extraiga DB Time/DB CPU y produzca el envelope común
# (# 16 AWR PARSER, # 20 PARSER OUTPUT CONTRACT).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys, json; sys.path.insert(0, '.')
from parsers.performance.awr_parser import parse_awr
with open('tests/fixtures/reports/awr-sample.html', encoding='utf-8') as f:
    r = parse_awr(f.read(), is_html=True)
d = r.to_dict()['report']
assert d['source_type'] == 'AWR_HTML'
assert d['sections']['db_time_cpu']['db_time_sec'] == '12018.00'
assert d['sections']['db_time_cpu']['db_cpu_sec'] == '7200.00'
assert d['status'] in ('SUCCESS', 'PARTIAL')
assert 'report_id' in d and 'parser_version' in d and 'evidence_refs' in d
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser AWR HTML extrae DB Time/DB CPU y produce el envelope común"
else
  echo "[FAIL] Parser AWR HTML falló: $OUT"
  FAIL=1
fi

exit $FAIL
