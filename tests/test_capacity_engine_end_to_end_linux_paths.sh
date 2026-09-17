#!/usr/bin/env bash
# PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING (# 1, # 20, # 67 del prompt):
# reproduce el defecto de raíz (backslash concatenado a una ruta POSIX) y confirma que la
# estrategia de rutas relativas de tests/lib/capacity_engine_e2e_helpers.sh lo corrige, sin
# depender de que `cygpath` exista o no.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_capacity_e2e_linux_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

capacity_engine_write_linear_fixture "$TMPDIR" "fixture.json" 4.0 1000.0 90
[ $? -eq 0 ] || { echo "[FAIL] FIXTURE_GENERATION_FAILED"; exit 1; }

# --- 1) Reproducción del defecto original: TMPDIR es una ruta POSIX; el código anterior
#        concatenaba "\\" incondicionalmente sin verificar si el interprete la necesitaba. ---
REPRO=$(python3 -c "
try:
    open(r'$TMPDIR\\fixture.json')
    print('UNEXPECTED_FILE_OPENED')
except FileNotFoundError as e:
    print('REPRODUCED:' + str(e))
" 2>&1)
if echo "$REPRO" | grep -q '^REPRODUCED:'; then
  echo "[PASS] defecto de raíz reproducido: concatenar '\\\\' a una ruta POSIX produce un nombre de archivo inexistente ($REPRO)"
else
  echo "[FAIL] no se pudo reproducir el defecto de raíz esperado: $REPRO"
  FAIL=1
fi

# --- 2) La estrategia corregida (rutas relativas vía cd, ver capacity_engine_run) NUNCA
#        construye ese string y debe tener éxito sobre el MISMO TMPDIR POSIX. ---
echo '{"warning_percent": 80.0}' > "$TMPDIR/thresholds.json"
echo '{"minimum_samples": 10, "minimum_history_days": 10, "preferred_history_days": 60}' > "$TMPDIR/policy.json"

capacity_engine_run "$TMPDIR" "fixture.json" "policy.json" "thresholds.json" "result.json" "report.md"
if [ "$CAPACITY_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] capacity_engine_run (ruta relativa) falló con código $CAPACITY_ENGINE_RUN_RC — stderr:"
  sed 's/^/    /' "$CAPACITY_ENGINE_RUN_STDERR_FILE"
  FAIL=1
else
  echo "[PASS] capacity_engine_run tiene éxito sobre el mismo TMPDIR POSIX usando rutas relativas (sin cygpath, sin backslash)"
fi

[ -f "$TMPDIR/result.json" ] && [ -f "$TMPDIR/report.md" ] && echo "[PASS] result.json y report.md generados correctamente en un entorno POSIX puro" || { echo "[FAIL] faltan artefactos de salida"; FAIL=1; }

# --- 3) Confirmar explícitamente que capacity_engine_run() nunca invoca cygpath en su propia
#        definición (sólo capacity_engine_to_interp_path, la ruta de respaldo para casos que sí
#        requieren una ruta absoluta, la usa) -- la corrección no depende de la disponibilidad de
#        cygpath para el flujo principal.
HELPER_SRC="$ROOT/tests/lib/capacity_engine_e2e_helpers.sh"
RUN_FN_BODY=$(awk '/^capacity_engine_run\(\)/{flag=1} flag{print} flag && /^}/{exit}' "$HELPER_SRC")
if echo "$RUN_FN_BODY" | grep -q "cygpath"; then
  echo "[FAIL] capacity_engine_run() depende de cygpath en su ruta principal — contradice la estrategia de rutas relativas"
  FAIL=1
else
  echo "[PASS] capacity_engine_run() no invoca cygpath — la corrección funciona independientemente de su disponibilidad"
fi

exit $FAIL
