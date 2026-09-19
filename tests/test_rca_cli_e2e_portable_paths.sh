#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING: rca_engine.cli se invoca de punta a
# punta usando exclusivamente rutas RELATIVAS al workdir (nunca una ruta absoluta con separador
# adivinado) — portable entre POSIX y Windows nativo, mismo patrón que
# tests/test_capacity_engine_end_to_end_linux_paths.sh. Reproduce y verifica explícitamente que
# rca_engine.cli funciona con --out-dir (validación de ruta de salida) y con nombres de archivo
# que incluyen espacios.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_cli_paths_$$"
mkdir -p "$TMPDIR/out dir with spaces"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/positive_confirmed.json" "$TMPDIR/fixture.json"

# 1) relative paths, no --out-dir
rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] baseline relative-path run: exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }
[ -f "$TMPDIR/result.json" ] || { echo "[FAIL] result.json missing after relative-path run"; FAIL=1; }

# 2) --out-dir with a path containing spaces — output paths validated to resolve inside it.
( cd "$TMPDIR" && PYTHONPATH="$ROOT" python3 -m rca_engine.cli \
    --fixture fixture.json --out-dir "out dir with spaces" \
    --out result.json --markdown report.md ) 2> "$TMPDIR/.cli_stderr_spaces.log"
RC=$?
if [ $RC -ne 0 ]; then
  echo "[FAIL] --out-dir con espacios: exit $RC"
  sed 's/^/    /' "$TMPDIR/.cli_stderr_spaces.log"
  FAIL=1
else
  [ -f "$TMPDIR/out dir with spaces/result.json" ] || { echo "[FAIL] no se escribió dentro de --out-dir"; FAIL=1; }
fi

# 3) an output path attempting to escape --out-dir via '..' must be rejected (exit non-zero, no file written outside).
( cd "$TMPDIR" && PYTHONPATH="$ROOT" python3 -m rca_engine.cli \
    --fixture fixture.json --out-dir "out dir with spaces" \
    --out "../escape.json" ) > /dev/null 2>"$TMPDIR/.cli_stderr_escape.log"
RC2=$?
if [ $RC2 -eq 0 ]; then
  echo "[FAIL] una ruta de salida con '..' fuera de --out-dir no fue rechazada"
  FAIL=1
else
  echo "[PASS] path traversal fuera de --out-dir correctamente rechazado (exit $RC2)"
fi
[ -f "$TMPDIR/escape.json" ] && { echo "[FAIL] escape.json fue escrito fuera de --out-dir"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] rca_engine.cli end-to-end con rutas relativas, --out-dir y espacios en el path, portable"
exit $FAIL
