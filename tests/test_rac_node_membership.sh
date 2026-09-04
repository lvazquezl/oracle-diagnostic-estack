#!/usr/bin/env bash
# rac/node-membership usa el collector get_cluster_nodes (olsnodes), nunca agrega/quita nodos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/node-membership/SKILL.md"

grep -q 'get_cluster_nodes' "$S" && echo "[PASS] rac/node-membership usa get_cluster_nodes" || { echo "[FAIL] falta la referencia al collector"; FAIL=1; }
grep -qi 'no agrega/quita nodos del cluster' "$S" && echo "[PASS] prohibición explícita" || { echo "[FAIL] falta prohibición"; FAIL=1; }
grep -qi 'MANUAL COLLECTION INSTRUCTION' "$S" && echo "[PASS] declara fallback INSUFFICIENT_PRIVILEGES" || { echo "[FAIL] falta fallback de privilegios"; FAIL=1; }

exit $FAIL
