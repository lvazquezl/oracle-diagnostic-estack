#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 46.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'reportarlos como si fueran el mismo límite' "$S" && echo "[PASS] distingue nproc por usuario de pid_max global" || { echo "[FAIL] falta la distinción"; FAIL=1; }
grep -qi 'pid_max. global nunca compensa un .nproc./límite efectivo por usuario bajo' "$S" \
  && echo "[PASS] declara que pid_max global nunca compensa nproc bajo" || { echo "[FAIL] falta la regla anti-compensación"; FAIL=1; }
exit $FAIL
