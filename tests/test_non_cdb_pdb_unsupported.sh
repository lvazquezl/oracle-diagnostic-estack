#!/usr/bin/env bash
# Valida que multitenant/pdb no aplique fuera de CDB (NON_CDB -> UNSUPPORTED).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q 'NON-CDB              → multitenant/pdb  → UNSUPPORTED' "$ROOT/policies/version-awareness-policy.md"; then
  echo "[PASS] policies/version-awareness-policy.md documenta NON-CDB -> multitenant/pdb -> UNSUPPORTED"
else
  echo "[FAIL] policies/version-awareness-policy.md no documenta NON-CDB -> multitenant/pdb -> UNSUPPORTED"
  FAIL=1
fi

# Compatibility Hardening (docs/PHASE_2_COMPATIBILITY_HARDENING.md): Q-PERF-WAIT-AWR-001,
# Q-PERF-WAIT-ASH-001 y 5 queries oracle/* declaraban container_scope: CDB_ROOT de forma
# INCORRECTA -- CDB_ROOT es exclusivo de Multitenant (12c+) pero esas queries también declaraban
# soporte 10g/11g, versiones sin CDB. Corregidas a ANY_CONTAINER (vistas CDB-wide, no CON_ID-scoped).
# Fase 6 (Multitenant) materializó las 15 queries reales bajo queries/multitenant/*, todas con
# container_scope: CDB_ROOT_ONLY -- y renombró el enum de CDB_ROOT/PDB/NON_CDB (bareword) a
# CDB_ROOT_ONLY/PDB_ONLY/NON_CDB_ONLY (ver docs/CONTRACTS.md#container_scope, nota de nomenclatura).
if grep -q 'container_scope: NON_CDB_ONLY|CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NOT_APPLICABLE' "$ROOT/docs/CONTRACTS.md"; then
  echo "[PASS] docs/CONTRACTS.md declara CDB_ROOT_ONLY como valor válido de container_scope (Query Contract v2)"
else
  echo "[FAIL] docs/CONTRACTS.md no declara CDB_ROOT_ONLY como valor válido de container_scope"
  FAIL=1
fi

if grep -qi 'NON-CDB.*fuera de scope\|nunca queries CDB/PDB' "$ROOT/agents/oracle-multitenant-analyst/AGENT.md"; then
  echo "[PASS] agents/oracle-multitenant-analyst/AGENT.md declara alcance exclusivo CDB/PDB (no aplica a NON-CDB)"
else
  echo "[FAIL] agents/oracle-multitenant-analyst/AGENT.md no declara exclusión explícita de NON-CDB"
  FAIL=1
fi

exit $FAIL
