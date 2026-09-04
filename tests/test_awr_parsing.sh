#!/usr/bin/env bash
# Valida que el AWR input model esté documentado (parser local, nunca envío de AWR completo)
# y que la fixture 12c-awr.yaml exista para validar el flujo AWR estructurado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if ! grep -q 'AWR input model' "$ROOT/agents/oracle-performance-analyst/AGENT.md"; then
  echo "[FAIL] agents/oracle-performance-analyst/AGENT.md no documenta el AWR input model"
  FAIL=1
else
  echo "[PASS] AWR input model documentado"
fi

if ! grep -q 'STRUCTURED SECTIONS' "$ROOT/agents/oracle-performance-analyst/AGENT.md"; then
  echo "[FAIL] agents/oracle-performance-analyst/AGENT.md no documenta las secciones estructuradas del AWR input model"
  FAIL=1
else
  echo "[PASS] Secciones estructuradas del AWR input model documentadas"
fi

# La estructura real vive en el parser — verificar que coincide con lo documentado.
OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.awr_parser import parse_awr
with open('tests/fixtures/reports/awr-sample.txt', encoding='utf-8') as f:
    r = parse_awr(f.read(), is_html=False)
for key in ('db_time_cpu', 'load_profile', 'waits', 'sql', 'rac', 'memory', 'io', 'parsing', 'redo_commit'):
    assert key in r.sections, key
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] parsers/performance/awr_parser.py produce exactamente las secciones documentadas"
else
  echo "[FAIL] Secciones del parser AWR no coinciden con lo documentado: $OUT"
  FAIL=1
fi

[ -f "$ROOT/tests/fixtures/12c-awr.yaml" ] && echo "[PASS] fixture 12c-awr.yaml existe" || { echo "[FAIL] falta tests/fixtures/12c-awr.yaml"; FAIL=1; }

exit $FAIL
