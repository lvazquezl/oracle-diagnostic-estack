#!/usr/bin/env bash
# Valida que los límites de tamaño configurables (# 23 REPORT SIZE LIMITS) se apliquen: un
# reporte con más filas de waits que max_wait_entries se trunca con warning, nunca se envía
# contenido masivo sin acotar.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.common import SizeLimitPolicy
from parsers.performance.statspack_parser import parse_statspack_text

header = '''STATSPACK report for

Database    DB Id    Instance     Inst Num  Startup Time    Release     RAC
~~~~~~~~ ----------- ------------ -------- --------------- ----------- ---
ORCLBIG    1111111111 orclbig              1 01-Jan-26 08:00 19.21.0.0.0 NO

Top 5 Timed Events                                                Avg %Total
~~~~~~~~~~~~~~~~~~                                               wait   Call
Event                                            Waits    Time (s)   (ms)   Time
----------------------------------------- ------------ ----------- ------ ------
'''
rows = ''.join(f'wait event number {i:04d}                       {100+i}      {50+i}     10    1.0\n' for i in range(30))
text = header + rows

tight_limits = SizeLimitPolicy(max_wait_entries=10)
r = parse_statspack_text(text, limits=tight_limits)
d = r.to_dict()['report']
assert len(d['sections']['waits']) == 10, len(d['sections']['waits'])
assert any('truncated' in w for w in d['warnings']), d['warnings']

# Whole-report size cap
tiny_size_limits = SizeLimitPolicy(max_report_size_bytes=200)
r2 = parse_statspack_text(text, limits=tiny_size_limits)
assert any('truncated at' in w for w in r2.warnings), r2.warnings
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Límites de tamaño (max_wait_entries, max_report_size_bytes) se aplican con warning explícito"
else
  echo "[FAIL] Límites de tamaño no se aplicaron correctamente: $OUT"
  FAIL=1
fi

exit $FAIL
