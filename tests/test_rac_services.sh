#!/usr/bin/env bash
# rac/services usa Q-RAC-SERVICES-001, nunca modifica servicios.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/services/SKILL.md"
Q="$ROOT/queries/rac/Q-RAC-SERVICES-001.md"

grep -q 'Q-RAC-SERVICES-001' "$S" && echo "[PASS] rac/services referencia Q-RAC-SERVICES-001" || { echo "[FAIL] falta referencia"; FAIL=1; }
grep -qi 'no crea/modifica/relocaliza servicios' "$S" && echo "[PASS] prohibición explícita" || { echo "[FAIL] falta prohibición"; FAIL=1; }
[ -f "$Q" ] && echo "[PASS] Q-RAC-SERVICES-001.md existe" || { echo "[FAIL] falta el archivo de query"; FAIL=1; }

exit $FAIL
