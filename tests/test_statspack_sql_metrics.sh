#!/usr/bin/env bash
# Valida SQL metrics de Statspack en ambas rutas: la query en vivo (Q-PERF-WAIT-STATSPACK-001)
# sigue sin consultar STATS$SQL_SUMMARY (mínimo privilegio, sin cambios), mientras que la ruta
# de reporte de archivo (parsers/performance/statspack_parser.py) sí extrae SQL ordered by
# executions/CPU/elapsed/gets/reads — SQL metrics ya no es un gap, ver # 10 STATSPACK ANALYSIS
# SKILL de docs/PHASE_3_COMPLETION_HARDENING.md.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/statspack-analysis/SKILL.md"

grep -qi 'sql_metrics' "$S" && echo "[PASS] statspack-analysis documenta sql_metrics en el capability map" || { echo "[FAIL] no documenta sql_metrics"; FAIL=1; }
grep -qi 'Fuera de alcance' "$S" && echo "[PASS] statspack-analysis declara alcance explícito" || { echo "[FAIL] falta sección de alcance"; FAIL=1; }

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$ROOT/queries/performance/waits/Q-PERF-WAIT-STATSPACK-001.md" 2>/dev/null)
if echo "$block" | grep -q 'STATS\$SQL_SUMMARY'; then
  echo "[FAIL] Q-PERF-WAIT-STATSPACK-001 consulta STATS\$SQL_SUMMARY (fuera del alcance de esta query específica — SQL metrics viene del parser, no de esta query)"
  FAIL=1
else
  echo "[PASS] Q-PERF-WAIT-STATSPACK-001 (ruta en vivo) sigue sin consultar STATS\$SQL_SUMMARY — sin cambio, mínimo privilegio"
fi

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
assert r.completeness['sql_by_cpu'] == 'SUPPORTED'
assert r.completeness['sql_by_elapsed'] == 'SUPPORTED'
assert len(r.sections['sql']) > 0
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Ruta de reporte de archivo SÍ extrae SQL metrics (ya no es un gap)"
else
  echo "[FAIL] Ruta de reporte de archivo no extrae SQL metrics: $OUT"
  FAIL=1
fi

exit $FAIL
