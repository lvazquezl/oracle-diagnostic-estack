#!/usr/bin/env bash
# rac/interconnect usa GV$CLUSTER_INTERCONNECTS, distingue red pública/interconnect/ASM/backup,
# nunca asume causa sin evidencia (# 33).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/interconnect/SKILL.md"
Q="$ROOT/queries/rac/Q-RAC-INTERCONNECT-001.md"

grep -q 'GV\$CLUSTER_INTERCONNECTS' "$S" && echo "[PASS] rac/interconnect usa GV\$CLUSTER_INTERCONNECTS" || { echo "[FAIL] falta la referencia"; FAIL=1; }
grep -qi 'sin asumir que una interfaz/bond/VLAN incorrecta es la causa' "$S" && echo "[PASS] no asume causa sin evidencia" || { echo "[FAIL] falta la advertencia explícita"; FAIL=1; }
[ -f "$Q" ] && echo "[PASS] Q-RAC-INTERCONNECT-001.md existe" || { echo "[FAIL] falta la query"; FAIL=1; }

exit $FAIL
