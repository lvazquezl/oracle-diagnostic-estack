#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 44/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-process-limits-insufficient-privileges.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q '# Insufficient privileges fallback' "$S" && echo "[PASS] declara la sección de fallback" || { echo "[FAIL] falta la sección"; FAIL=1; }
grep -q 'INSUFFICIENT_PRIVILEGES' "$S" && echo "[PASS] declara INSUFFICIENT_PRIVILEGES" || { echo "[FAIL] falta INSUFFICIENT_PRIVILEGES"; FAIL=1; }
grep -q 'collection_status: INSUFFICIENT_PRIVILEGES' "$FX" && echo "[PASS] fixture declara collection_status INSUFFICIENT_PRIVILEGES" || { echo "[FAIL] falta en la fixture"; FAIL=1; }
exit $FAIL
