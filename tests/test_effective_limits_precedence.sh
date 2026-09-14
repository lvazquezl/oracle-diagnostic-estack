#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 43/14.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q '# Source priority' "$S" && echo "[PASS] declara la sección Source priority" || { echo "[FAIL] falta la sección"; FAIL=1; }
grep -q 'EFFECTIVE_TARGET_PROCESS_LIMITS' "$S" && echo "[PASS] declara EFFECTIVE_TARGET_PROCESS_LIMITS como prioridad 1" || { echo "[FAIL] falta EFFECTIVE_TARGET_PROCESS_LIMITS"; FAIL=1; }
grep -qi 'nunca fusionada mediante una regla de mínimo universal' "$S" && echo "[PASS] prohíbe la fusión mediante mínimo universal" || { echo "[FAIL] falta la prohibición de fusión"; FAIL=1; }
exit $FAIL
