#!/usr/bin/env bash
# PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING (# 41, # 44, # 70 del prompt): si el
# CLI retorna código distinto de cero (p.ej. fixture JSON malformado), el test debe reportar el
# código y el stderr real -- nunca afirmar que generó resultados, nunca enmascarar la excepción
# con grep/`|| true`/sustituciones que absorban el status.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_capacity_e2e_badjson_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# JSON deliberadamente malformado -- json.load() debe lanzar una excepción real, no un forecast.
printf '{"samples": [ this is not valid json ' > "$TMPDIR/fixture.json"
echo '{"warning_percent": 80.0}' > "$TMPDIR/thresholds.json"
echo '{"minimum_samples": 10, "minimum_history_days": 10, "preferred_history_days": 60}' > "$TMPDIR/policy.json"

capacity_engine_run "$TMPDIR" "fixture.json" "policy.json" "thresholds.json" "result.json" "report.md"
RC="$CAPACITY_ENGINE_RUN_RC"

if [ "$RC" -eq 0 ]; then
  echo "[FAIL] capacity_engine.cli reportó éxito (código 0) sobre un fixture JSON malformado -- nunca debería ocurrir"
  FAIL=1
else
  echo "[PASS] capacity_engine.cli retorna código distinto de cero ($RC) ante un fixture JSON malformado -- reportado explícitamente, no asumido"
fi

if grep -qiE "JSONDecodeError|Expecting|json\\.decoder" "$CAPACITY_ENGINE_RUN_STDERR_FILE"; then
  echo "[PASS] el stderr real (JSONDecodeError) queda expuesto sin enmascarar"
else
  echo "[FAIL] no se encontró la excepción JSON esperada en stderr:"
  cat "$CAPACITY_ENGINE_RUN_STDERR_FILE"
  FAIL=1
fi

# distinguir explícitamente: esto es un fallo del CLI/parsing, NO un fallo numérico del motor --
# nunca se declara que el motor calculó mal, sólo que el input era inválido.
if [ -f "$TMPDIR/result.json" ]; then
  echo "[FAIL] no debería existir result.json cuando el CLI falló por entrada inválida"
  FAIL=1
else
  echo "[PASS] sin result.json parcial/inventado tras el fallo de parsing -- distinción correcta entre fallo de entrada y fallo numérico"
fi

exit $FAIL
