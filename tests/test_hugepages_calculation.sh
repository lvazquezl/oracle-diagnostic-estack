#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'required_pages = ceil(total_SGA_bytes / hugepage_size_bytes)' "$S" \
  && echo "[PASS] declara la fórmula certificada" || { echo "[FAIL] falta la fórmula certificada"; FAIL=1; }
grep -qiE 'shortfall = *$|shortfall =[[:space:]]*$|shortfall =' "$S" && echo "[PASS] declara el cálculo de shortfall" || { echo "[FAIL] falta shortfall"; FAIL=1; }
exit $FAIL
