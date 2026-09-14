#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 44/17.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-process-limits-insufficient-privileges.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'manual_collection' "$S" && echo "[PASS] declara manual_collection" || { echo "[FAIL] falta manual_collection"; FAIL=1; }
grep -q 'owner_role: OS_ADMIN' "$S" && echo "[PASS] declara owner_role OS_ADMIN" || { echo "[FAIL] falta owner_role OS_ADMIN"; FAIL=1; }
grep -q 'manual_collection_generated: true' "$FX" && echo "[PASS] fixture declara manual_collection_generated: true" || { echo "[FAIL] falta en la fixture"; FAIL=1; }
exit $FAIL
