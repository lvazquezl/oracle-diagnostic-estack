#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 45/31.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'requiere confirmar que el PID pertenece a esa unit systemd' "$S" \
  && echo "[PASS] requiere confirmar membership del PID en la unit para aplicar TasksMax" || { echo "[FAIL] falta el requisito de membership de unit"; FAIL=1; }
exit $FAIL
