#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 42/5.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
OUT="$ROOT/agents/os-platform-analyst/output-schema.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q '# Launch context model' "$S" && echo "[PASS] declara la sección Launch context model" || { echo "[FAIL] falta la sección"; FAIL=1; }
for val in SYSTEMD PAM_LOGIN PAM_SU MANUAL_SHELL ORACLE_CLUSTERWARE OTHER UNKNOWN; do
  grep -q "$val" "$S" && echo "[PASS] declara el valor $val" || { echo "[FAIL] falta el valor $val"; FAIL=1; }
done
grep -q 'launch_context:' "$OUT" && echo "[PASS] output-schema.yaml declara launch_context" || { echo "[FAIL] falta launch_context en output-schema.yaml"; FAIL=1; }
exit $FAIL
