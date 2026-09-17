#!/usr/bin/env bash
# PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING (# 34, # 68 del prompt): el directorio
# de trabajo contiene un espacio -- confirma quoting seguro en capacity_engine_run/
# capacity_engine_write_linear_fixture, sin interpolar contenido de archivos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp capacity e2e spaces $$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

capacity_engine_write_linear_fixture "$TMPDIR" "fixture.json" 4.0 1000.0 90
if [ $? -ne 0 ]; then
  echo "[FAIL] FIXTURE_GENERATION_FAILED en un directorio con espacios"
  exit 1
fi
[ -f "$TMPDIR/fixture.json" ] && echo "[PASS] fixture.json escrito correctamente en un directorio con espacios en el nombre" || { echo "[FAIL] fixture.json no se escribió"; exit 1; }

echo '{"warning_percent": 80.0}' > "$TMPDIR/thresholds.json"
echo '{"minimum_samples": 10, "minimum_history_days": 10, "preferred_history_days": 60}' > "$TMPDIR/policy.json"

capacity_engine_run "$TMPDIR" "fixture.json" "policy.json" "thresholds.json" "result.json" "report.md"
if [ "$CAPACITY_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] capacity_engine.cli falló con código $CAPACITY_ENGINE_RUN_RC en un directorio con espacios — stderr:"
  sed 's/^/    /' "$CAPACITY_ENGINE_RUN_STDERR_FILE"
  exit 1
fi

if [ -f "$TMPDIR/result.json" ] && [ -f "$TMPDIR/report.md" ]; then
  echo "[PASS] capacity_engine.cli produce result.json/report.md correctamente con un workdir cuyo nombre contiene espacios"
else
  echo "[FAIL] faltan artefactos de salida en el directorio con espacios"
  FAIL=1
fi

OUT=$(cd "$TMPDIR" && python3 -c "
import json
result = json.load(open('result.json'))
assert abs(result['method_parameters']['slope'] - 4.0) < 1e-6, result['method_parameters']['slope']
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] el resultado numérico es correcto pese al espacio en la ruta del workdir"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
