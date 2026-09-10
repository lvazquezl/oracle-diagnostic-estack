#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 19, # 25, # 31.
# "latest" nunca debe inferirse como soporte de una major futura desconocida a nivel de política
# de negocio (docs/QUERY_VARIANTS.md#future-proof-version-policy) — la librería compartida sólo
# provee la comparación numérica; la decisión de negocio (future_status: COMPATIBILITY_VALIDATION_
# REQUIRED, nunca latest:SUPPORTED) sigue viviendo en config/capability-matrix.yaml, sin cambios en
# este hardening (# 31 del prompt: "no introducir latest: SUPPORTED").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
source "$ROOT/scripts/lib/version.sh"

# La librería sí compara correctamente una major futura hipotética contra rangos con max explícito
# (nunca "latest") — una major 24 no encajaría en un rango con max: "23.0".
version_in_range "24.0" "12.1" "23.0" && { echo "[FAIL] 24.0 encajó incorrectamente en [12.1, 23.0]"; FAIL=1; } || echo "[PASS] 24.0 (major futura desconocida) no encaja en un rango con max explícito 23.0"

grep -q 'future_status: COMPATIBILITY_VALIDATION_REQUIRED' "$ROOT/config/capability-matrix.yaml" && echo "[PASS] config/capability-matrix.yaml sigue declarando future_status: COMPATIBILITY_VALIDATION_REQUIRED" || { echo "[FAIL] falta future_status: COMPATIBILITY_VALIDATION_REQUIRED"; FAIL=1; }

# Sólo la fila multitenant está en alcance de este hardening — otras filas (Oracle Core, RAC, etc.)
# legítimamente declaran latest: SUPPORTED (dominio realmente soportado al techo actual) y no deben
# tocarse aquí. Sólo se inspecciona la línea `versions:` real (el YAML map), no `notes:` — ese campo
# menciona 'latest: SUPPORTED' como prosa explicando que el campo fue ELIMINADO, no un valor vivo.
versions_line=$(awk '/^  - id: multitenant$/{f=1} f && /^    versions:/{print; exit}' "$ROOT/config/capability-matrix.yaml")
if echo "$versions_line" | grep -qE 'latest:\s*SUPPORTED'; then
  echo "[FAIL] la fila multitenant de config/capability-matrix.yaml introduce latest: SUPPORTED en versions:"
  FAIL=1
else
  echo "[PASS] la fila multitenant de config/capability-matrix.yaml no declara latest: SUPPORTED en versions: ($versions_line)"
fi

exit $FAIL
