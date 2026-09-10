#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 5, # 11, # 13, # 39.
# Valida que el output schema/decision logic derivan container_name/pdb_token de NAME en la
# variante legacy — no dejan container_name: null cuando NAME está disponible (# 11 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"

grep -qi 'container_name.*derivad.*NAME\|derivados de NAME\|derivado de NAME' "$SKILL" && echo "[PASS] SKILL.md declara que container_name/pdb_token se derivan de NAME en legacy" || { echo "[FAIL] falta la derivación de container_name/pdb_token desde NAME"; FAIL=1; }

if grep -qE 'container_name: string\|null\s*#.*legacy.*siempre null|container_name: null.*legacy' "$SKILL"; then
  echo "[FAIL] SKILL.md todavía deja container_name: null incondicional en legacy"
  FAIL=1
else
  echo "[PASS] SKILL.md no fuerza container_name: null en legacy"
fi

grep -qi 'nunca null si NAME está disponible' "$SKILL" && echo "[PASS] output schema documenta explícitamente que container_name no es null cuando NAME existe" || { echo "[FAIL] falta la aclaración explícita en el output schema"; FAIL=1; }

exit $FAIL
