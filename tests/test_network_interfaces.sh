#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/network-interfaces/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'get_interfaces' "$S" && echo "[PASS] formaliza el collector get_interfaces de Fase 4" || { echo "[FAIL] falta la referencia a get_interfaces"; FAIL=1; }
grep -qi 'TOKENIZE por defecto' "$S" && echo "[PASS] declara TOKENIZE por defecto para direcciones" || { echo "[FAIL] falta TOKENIZE"; FAIL=1; }
exit $FAIL
