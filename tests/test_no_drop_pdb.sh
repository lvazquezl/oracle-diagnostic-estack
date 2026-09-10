#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

grep -qi "DROP PLUGGABLE DATABASE" "$MANIFEST" && echo "[PASS] manifest prohíbe explícitamente DROP PLUGGABLE DATABASE" || { echo "[FAIL] falta la prohibición de DROP PLUGGABLE DATABASE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de DROP PLUGGABLE DATABASE"

exit $FAIL
