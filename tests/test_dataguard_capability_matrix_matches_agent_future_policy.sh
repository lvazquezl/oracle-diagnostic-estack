#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 19.
# Impide la contradicción exacta descrita en el prompt: Agent Contract declarando UNKNOWN_FUTURE
# mientras Capability Matrix declara "latest SUPPORTED" para el mismo dominio. Debe existir una
# sola interpretación entre Agent Contract, Query Compatibility Matrix, Capability Matrix,
# documentación y tests (# 16 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
CAP="$ROOT/config/capability-matrix.yaml"
DOC="$ROOT/docs/CAPABILITY_MATRIX.md"
MATRIX="$ROOT/config/query-compatibility-matrix.yaml"
MANIFEST="$ROOT/agents/oracle-dataguard-analyst/manifest.yaml"

# 1) Agent Contract debe declarar UNKNOWN_FUTURE para la familia futura.
grep -q 'status: UNKNOWN_FUTURE' "$MANIFEST" && echo "[PASS] Agent Contract declara UNKNOWN_FUTURE para versiones futuras" || { echo "[FAIL] Agent Contract no declara UNKNOWN_FUTURE"; FAIL=1; }

# 2) Capability Matrix NO debe declarar 'latest: SUPPORTED' para dataguard (la contradicción exacta del ejemplo).
# Alcance estricto a la línea versions: {...} (estructura), no a notas en prosa.
dg_row=$(awk '/id: dataguard/{flag=1} flag{print} flag && /^  - id:/ && !/id: dataguard/{exit}' "$CAP")
dg_versions_line=$(awk '/id: dataguard/{flag=1} flag && /^    versions:/{print; exit}' "$CAP")
if echo "$dg_versions_line" | grep -qE '\blatest:'; then
  echo "[FAIL] CONTRADICCIÓN: Agent declara UNKNOWN_FUTURE pero Capability Matrix versions:{...} declara la clave 'latest:' para dataguard"
  FAIL=1
else
  echo "[PASS] Capability Matrix no contradice al Agent Contract — versions:{...} sin la clave 'latest:' en dataguard"
fi
echo "$dg_row" | grep -q 'future_status: COMPATIBILITY_VALIDATION_REQUIRED' && echo "[PASS] Capability Matrix declara future_status: COMPATIBILITY_VALIDATION_REQUIRED, consistente con UNKNOWN_FUTURE del agente" || { echo "[FAIL] falta future_status: COMPATIBILITY_VALIDATION_REQUIRED"; FAIL=1; }

# 3) Query Compatibility Matrix: ninguna entrada Q-DG-* debe usar 'max: latest'.
dg_queries=$(awk '/Fase 5 \(Data Guard\)/{flag=1} flag{print} /^notes: >/{flag=0}' "$MATRIX")
if echo "$dg_queries" | grep -q 'max: latest'; then
  echo "[FAIL] config/query-compatibility-matrix.yaml todavía usa max: latest en alguna query Data Guard"
  FAIL=1
else
  echo "[PASS] Query Compatibility Matrix usa max explícito en todas las queries Data Guard, consistente con UNKNOWN_FUTURE"
fi

# 4) Documentación debe reflejar la misma interpretación.
grep -qi 'COMPATIBILITY_VALIDATION_REQUIRED' "$DOC" && echo "[PASS] docs/CAPABILITY_MATRIX.md documenta la misma interpretación (COMPATIBILITY_VALIDATION_REQUIRED)" || { echo "[FAIL] docs/CAPABILITY_MATRIX.md no documenta COMPATIBILITY_VALIDATION_REQUIRED"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Agent Contract, Query Compatibility Matrix, Capability Matrix y documentación tienen una única interpretación consistente de 'unknown future major -> COMPATIBILITY_VALIDATION_REQUIRED'"

exit $FAIL
