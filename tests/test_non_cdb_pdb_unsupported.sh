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
# Ninguna query materializada en Oracle Core es hoy legítimamente CDB_ROOT-exclusiva -- las
# candidatas reales (Q-CDB-PDB-STATE-001, Q-CDB-CONTAINERS-001, dominio multitenant) están
# `registered`, no materializadas (fuera de alcance de Fase 2/este hardening). Validar en su
# lugar que CDB_ROOT sigue siendo un valor de enum válido y documentado en el Query Contract
# -- el modelo soporta la distinción aunque el catálogo actual no la use todavía.
if grep -q 'container_scope: NON_CDB|CDB_ROOT|PDB|ANY_CONTAINER|NOT_APPLICABLE' "$ROOT/docs/CONTRACTS.md"; then
  echo "[PASS] docs/CONTRACTS.md declara CDB_ROOT como valor válido de container_scope (Query Contract v2)"
else
  echo "[FAIL] docs/CONTRACTS.md no declara CDB_ROOT como valor válido de container_scope"
  FAIL=1
fi

if grep -q 'CDB/PDB exclusivamente' "$ROOT/agents/oracle-multitenant-analyst.md"; then
  echo "[PASS] oracle-multitenant-analyst.md declara alcance exclusivo CDB/PDB (no aplica a NON-CDB)"
else
  echo "[FAIL] oracle-multitenant-analyst.md no declara exclusión explícita de NON-CDB"
  FAIL=1
fi

exit $FAIL
