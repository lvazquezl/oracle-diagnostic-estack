#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 45.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/open-files/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'get_process_effective_limits' "$S" && echo "[PASS] declara get_process_effective_limits como evidencia" || { echo "[FAIL] falta el collector"; FAIL=1; }
grep -qi 'evidencia primaria del valor real' "$S" && echo "[PASS] declara que el límite efectivo es la evidencia primaria" || { echo "[FAIL] falta la regla de evidencia primaria"; FAIL=1; }
exit $FAIL
