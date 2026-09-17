#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 17
# (# 160 del prompt): fixture -> cálculo real -> esquema de salida -> reporte con números
# provenientes del motor, nunca hardcodeados. Ejercita capacity_engine.cli (# 9, # 134 del
# prompt: adaptador local invocable, LOCAL_RUNTIME_TESTED).
#
# PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING: reescrito — la versión anterior
# concatenaba "$WTMPDIR\\archivo.json" incondicionalmente, lo que en POSIX sin cygpath producía un
# nombre de archivo con una barra invertida LITERAL (nunca un separador válido), y el CLI fallaba
# con FileNotFoundError. Ver tests/lib/capacity_engine_e2e_helpers.sh para la causa raíz completa
# y la estrategia de rutas relativas que la corrige de raíz.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_capacity_e2e_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# 1) fixture JSON local, sin datos productivos — used = 1000 + 4*día.
capacity_engine_write_linear_fixture "$TMPDIR" "fixture.json" 4.0 1000.0 90
RC=$?
if [ $RC -ne 0 ]; then
  echo "[FAIL] FIXTURE_GENERATION_FAILED (código $RC) — no se continúa hacia el CLI"
  exit 1
fi
echo '{"warning_percent": 80.0}' > "$TMPDIR/thresholds.json"
echo '{"minimum_samples": 10, "minimum_history_days": 10, "preferred_history_days": 60}' > "$TMPDIR/policy.json"

# 2) invocar el adaptador local como subproceso real (sin LLM, sin MCP, sin red) — rutas
#    RELATIVAS al workdir, nunca una ruta absoluta con separador adivinado.
capacity_engine_run "$TMPDIR" "fixture.json" "policy.json" "thresholds.json" "result.json" "report.md"
if [ "$CAPACITY_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] capacity_engine.cli terminó con código $CAPACITY_ENGINE_RUN_RC — stderr:"
  sed 's/^/    /' "$CAPACITY_ENGINE_RUN_STDERR_FILE"
  exit 1
fi

[ -f "$TMPDIR/result.json" ] || { echo "[FAIL] no se generó result.json pese a exit code 0"; exit 1; }
[ -f "$TMPDIR/report.md" ] || { echo "[FAIL] no se generó report.md pese a exit code 0"; exit 1; }

# 3) los números del reporte Markdown deben provenir del JSON calculado, nunca hardcodeados —
#    también rutas relativas (cd al workdir antes de abrir).
OUT=$(cd "$TMPDIR" && python3 -c "
import json
result = json.load(open('result.json'))
report = open('report.md', encoding='utf-8').read()

assert result['method'] == 'linear_regression', result['method']
assert abs(result['method_parameters']['slope'] - 4.0) < 1e-6, result['method_parameters']['slope']
assert result['contract_version'] and result['algorithm_version']
assert result['input_evidence_ids'] == ['EVD-E2E-1'], result['input_evidence_ids']

h1_expected = result['horizons']['1m']['expected']
h3_expected = result['horizons']['3m']['expected']
h6_expected = result['horizons']['6m']['expected']
assert h1_expected is not None and h3_expected is not None and h6_expected is not None
# el valor formateado en el reporte debe reflejar el mismo numero calculado (tolerancia de
# presentacion, nunca de calculo) -- confirma que el reporte no usa un valor distinto/hardcodeado.
formatted = f'{h1_expected:,.2f}'
assert formatted in report, (formatted, report)
assert 'Resource | Current | 1M | 3M | 6M | Threshold Date | Risk | Confidence' in report
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine.cli ejecuta el recorrido completo fixture->motor->JSON->Markdown, con números provenientes del cálculo real (rutas relativas, portable)"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
