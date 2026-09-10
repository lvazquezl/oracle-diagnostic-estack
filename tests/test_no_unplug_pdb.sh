#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
AGENT="$ROOT/agents/oracle-multitenant-analyst/AGENT.md"

grep -qi "\bUNPLUG\b" "$AGENT" && echo "[PASS] AGENT.md lista UNPLUG entre las operaciones prohibidas" || { echo "[FAIL] falta UNPLUG en las prohibiciones"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de UNPLUG PDB"

exit $FAIL
