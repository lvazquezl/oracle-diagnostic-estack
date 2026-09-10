#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/23ai-modern-cdb-pdb.yaml"
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 23ai-modern-cdb-pdb.yaml"; exit 1; }
grep -q "major: 23" "$FX" && echo "[PASS] fixture declara oracle_version.major=23" || { echo "[FAIL] fixture no declara 23"; FAIL=1; }
grep -A2 'family: "23ai"' "$MANIFEST" | grep -q "status: KNOWN_SUPPORTED" && echo "[PASS] manifest declara 23ai como KNOWN_SUPPORTED explícitamente (no por herencia de 'latest')" || { echo "[FAIL] falta KNOWN_SUPPORTED explícito para 23ai"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] 23ai reconocido explícitamente como KNOWN_SUPPORTED"

exit $FAIL
