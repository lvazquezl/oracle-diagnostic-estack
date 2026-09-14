#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 34/4/10.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'module_arguments: {conf: string|null, debug: bool|null, set_all: bool|null, utmp_early: bool|null}' "$S" \
  && echo "[PASS] declara los 4 argumentos del módulo (conf/debug/set_all/utmp_early)" || { echo "[FAIL] faltan los argumentos del módulo"; FAIL=1; }
grep -qi 'atribuyendo argumentos del servicio padre a un módulo encontrado en un' "$S" \
  && echo "[PASS] prohíbe atribuir argumentos del parent service a un módulo en un include" || { echo "[FAIL] falta la prohibición de atribución incorrecta"; FAIL=1; }
exit $FAIL
