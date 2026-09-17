#!/usr/bin/env bash
# PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING (# 40, # 69 del prompt): si el
# fixture no existe, el CLI debe fallar con código distinto de cero de inmediato -- el test no
# debe continuar hacia aserciones sobre result.json/report.md que producirían errores secundarios
# confusos, y no debe enmascarar la excepción con grep/`|| true`.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_capacity_e2e_missing_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# fixture.json deliberadamente ausente -- nunca escrito.
echo '{"warning_percent": 80.0}' > "$TMPDIR/thresholds.json"
echo '{"minimum_samples": 10, "minimum_history_days": 10, "preferred_history_days": 60}' > "$TMPDIR/policy.json"

capacity_engine_run "$TMPDIR" "fixture.json" "policy.json" "thresholds.json" "result.json" "report.md"

if [ "$CAPACITY_ENGINE_RUN_RC" -eq 0 ]; then
  echo "[FAIL] capacity_engine.cli terminó con código 0 pese a que fixture.json no existe -- se esperaba un fallo explícito"
  FAIL=1
else
  echo "[PASS] capacity_engine.cli falla con código distinto de cero ($CAPACITY_ENGINE_RUN_RC) cuando el fixture no existe"
fi

# la excepción real (FileNotFoundError) debe estar en stderr, nunca silenciada.
if grep -qi "FileNotFoundError\|No such file" "$CAPACITY_ENGINE_RUN_STDERR_FILE"; then
  echo "[PASS] el stderr real del CLI (FileNotFoundError) queda capturado, no enmascarado"
else
  echo "[FAIL] stderr no contiene la excepción esperada -- posible enmascaramiento:"
  cat "$CAPACITY_ENGINE_RUN_STDERR_FILE"
  FAIL=1
fi

# fail-fast: ni result.json ni report.md deben existir -- el CLI no debe producir salida parcial.
if [ -f "$TMPDIR/result.json" ] || [ -f "$TMPDIR/report.md" ]; then
  echo "[FAIL] el CLI produjo un artefacto de salida pese a fallar -- no es fail-fast"
  FAIL=1
else
  echo "[PASS] ningún artefacto de salida parcial se generó tras el fallo (fail-fast real)"
fi

exit $FAIL
