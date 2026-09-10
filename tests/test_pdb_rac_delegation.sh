#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 34/59.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ROUTING="$ROOT/agents/oracle-multitenant-analyst/routing.yaml"
COLLAB="$ROOT/agents/oracle-multitenant-analyst/collaboration.yaml"

grep -q "agent: oracle-rac-analyst" "$ROUTING" && echo "[PASS] routing.yaml declara delegación a oracle-rac-analyst" || { echo "[FAIL] falta la delegación a oracle-rac-analyst"; FAIL=1; }
grep -q "oracle-rac-analyst" "$COLLAB" && echo "[PASS] collaboration.yaml incluye oracle-rac-analyst en may_delegate_to" || { echo "[FAIL] falta oracle-rac-analyst en collaboration.yaml"; FAIL=1; }
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"
grep -q "supported_architectures: \[standalone, rac, rac_one_node\]" "$MANIFEST" && echo "[PASS] el agente declara RAC como arquitectura soportada, pero la delegación a oracle-rac-analyst sólo aplica cuando el Target Profile confirma RAC (Capability Filter, no lógica ad-hoc)" || { echo "[FAIL] falta la declaración de arquitecturas soportadas"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Delegación a oracle-rac-analyst correctamente definida"

exit $FAIL
