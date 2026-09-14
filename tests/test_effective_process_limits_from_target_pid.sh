#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q '# Effective process limits — primary evidence' "$S" && echo "[PASS] declara la sección de evidencia primaria" || { echo "[FAIL] falta la sección"; FAIL=1; }
grep -q 'get_process_effective_limits' "$S" && echo "[PASS] declara el collector get_process_effective_limits" || { echo "[FAIL] falta el collector"; FAIL=1; }
grep -q 'get_process_effective_limits' "$D" && echo "[PASS] docs/OS_READONLY_COLLECTOR_MODEL.md cataloga el collector" || { echo "[FAIL] falta el catálogo"; FAIL=1; }
grep -qi 'PID-scoped' "$D" && echo "[PASS] declara el collector como PID-scoped" || { echo "[FAIL] falta PID-scoped"; FAIL=1; }
exit $FAIL
