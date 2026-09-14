#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 75.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in oracle-processes grid-processes; do
  S="$ROOT/skills/os/$f/SKILL.md"
  [ -f "$S" ] || { echo "[FAIL] falta $S"; FAIL=1; continue; }
  grep -qi 'Nunca envía command-line arguments completos por defecto' "$S" \
    && echo "[PASS] os/$f prohíbe enviar command-line arguments completos por defecto" \
    || { echo "[FAIL] os/$f no prohíbe los argumentos completos"; FAIL=1; }
done
exit $FAIL
