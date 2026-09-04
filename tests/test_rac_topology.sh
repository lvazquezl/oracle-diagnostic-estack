#!/usr/bin/env bash
# rac/topology usa Q-RAC-TOPOLOGY-001 (GV$INSTANCE + V$ACTIVE_INSTANCES).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/topology/SKILL.md"
Q="$ROOT/queries/rac/Q-RAC-TOPOLOGY-001.md"

grep -q 'Q-RAC-TOPOLOGY-001' "$S" && echo "[PASS] rac/topology referencia Q-RAC-TOPOLOGY-001" || { echo "[FAIL] falta la referencia"; FAIL=1; }
grep -q 'GV\$INSTANCE, V\$ACTIVE_INSTANCES' "$Q" && echo "[PASS] Q-RAC-TOPOLOGY-001 declara GV\$INSTANCE/V\$ACTIVE_INSTANCES" || { echo "[FAIL] falta objects_accessed correcto"; FAIL=1; }
grep -q 'RAC, RAC One Node' "$Q" && echo "[PASS] Q-RAC-TOPOLOGY-001 acotada a RAC/RAC One Node" || { echo "[FAIL] falta supported_architectures correcto"; FAIL=1; }

exit $FAIL
