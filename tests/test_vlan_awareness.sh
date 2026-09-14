#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/vlan/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'vlan_id' "$S" && echo "[PASS] declara vlan_id" || { echo "[FAIL] falta vlan_id"; FAIL=1; }
grep -qi 'Mismatch de .vlan_id./MTU entre nodos RAC' "$S" && echo "[PASS] declara HIGH para mismatch entre nodos RAC" || { echo "[FAIL] falta la regla de mismatch RAC"; FAIL=1; }
exit $FAIL
