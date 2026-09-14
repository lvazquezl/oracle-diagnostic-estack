#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/numa/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca deshabilita NUMA\|nunca recomienda deshabilitar NUMA' "$S" \
  && echo "[PASS] prohíbe deshabilitar NUMA automáticamente" || { echo "[FAIL] falta la prohibición"; FAIL=1; }
grep -qi 'node_count' "$S" && echo "[PASS] declara node_count" || { echo "[FAIL] falta node_count"; FAIL=1; }
exit $FAIL
