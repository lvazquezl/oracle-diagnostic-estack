#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/dns/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'get_name_resolution' "$S" && echo "[PASS] formaliza el collector get_name_resolution de Fase 4" || { echo "[FAIL] falta la referencia a get_name_resolution"; FAIL=1; }
grep -qi 'No duplica.*network/name-resolution\|nunca duplica esa lógica de.\?dominio Oracle' "$S" \
  && echo "[PASS] declara no duplicar la lógica de dominio Oracle SCAN/TNS" || { echo "[FAIL] falta la prohibición de duplicación"; FAIL=1; }
exit $FAIL
