#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 35/12.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -qi 'nunca se convierte en acceso a archivo arbitrario' "$D" && echo "[PASS] prohíbe convertir conf= en acceso a archivo arbitrario" || { echo "[FAIL] falta la prohibición"; FAIL=1; }
grep -qi 'expone el contenido crudo del archivo' "$D" && echo "[PASS] prohíbe exponer contenido crudo" || { echo "[FAIL] falta la prohibición de contenido crudo"; FAIL=1; }
exit $FAIL
