#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 35/12.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -qi 'path tokenizado' "$D" && echo "[PASS] declara que el path custom se tokeniza" || { echo "[FAIL] falta la tokenización del path"; FAIL=1; }
grep -qi 'restringido a la fuente configurada' "$D" && echo "[PASS] declara que el path custom se valida/restringe" || { echo "[FAIL] falta la validación/restricción del path"; FAIL=1; }
exit $FAIL
