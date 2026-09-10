#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58.
# Verifica la declaración del agente/manifest (distinto de test_multitenant_not_applicable_11g.sh,
# que verifica el fixture) — el agente debe declarar 10g/11g como NOT_APPLICABLE explícitamente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
ROUTING="$ROOT/agents/oracle-multitenant-analyst/routing.yaml"

grep -A2 'family: "10g"' "$MANIFEST" | grep -q "status: NOT_APPLICABLE" && echo "[PASS] manifest declara familia 10g como NOT_APPLICABLE" || { echo "[FAIL] falta NOT_APPLICABLE para 10g"; FAIL=1; }
grep -A2 'family: "11g"' "$MANIFEST" | grep -q "status: NOT_APPLICABLE" && echo "[PASS] manifest declara familia 11g como NOT_APPLICABLE" || { echo "[FAIL] falta NOT_APPLICABLE para 11g"; FAIL=1; }
grep -qi "non_cdb" "$ROUTING" && echo "[PASS] routing.yaml declara deactivation_rule para NON-CDB" || { echo "[FAIL] falta deactivation_rule en routing.yaml"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Agente Multitenant declara explícitamente 10g/11g como NOT_APPLICABLE"

exit $FAIL
