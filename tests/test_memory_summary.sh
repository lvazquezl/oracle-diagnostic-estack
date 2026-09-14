#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/memory/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'wasted\|desperdiciada' "$S" && echo "[PASS] aclara que cache no es memoria desperdiciada" || { echo "[FAIL] falta la aclaración de cache"; FAIL=1; }
grep -qi 'absorbe\|reemplaza y absorbe\|os/linux/memory.md' "$S" \
  && echo "[PASS] documenta la fusión con os/linux/memory.md de Foundation" || { echo "[FAIL] falta la nota de fusión"; FAIL=1; }
exit $FAIL
