#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/discovery/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'os_target' "$S" && echo "[PASS] declara el modelo os_target" || { echo "[FAIL] falta os_target"; FAIL=1; }
grep -q 'nunca reutiliza\|scripts/lib/version.sh' "$S" >/dev/null 2>&1
grep -qi 'COMPATIBILITY_VALIDATION_REQUIRED' "$S" && echo "[PASS] declara COMPATIBILITY_VALIDATION_REQUIRED para plataforma no reconocida" || { echo "[FAIL] falta COMPATIBILITY_VALIDATION_REQUIRED"; FAIL=1; }
grep -q 'hostname_token' "$S" && echo "[PASS] declara hostname_token sanitizado" || { echo "[FAIL] falta hostname_token"; FAIL=1; }
exit $FAIL
