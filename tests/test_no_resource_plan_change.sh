#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 31/61/62.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

grep -qi "RESOURCE_MANAGER_PLAN" "$MANIFEST" && echo "[PASS] manifest prohíbe explícitamente ALTER SYSTEM SET RESOURCE_MANAGER_PLAN" || { echo "[FAIL] falta la prohibición de cambiar el plan"; FAIL=1; }

for f in $(find "$ROOT/queries/multitenant" "$ROOT/skills/multitenant" -type f); do
  if grep -Eiq 'ALTER SYSTEM SET RESOURCE_MANAGER_PLAN' "$f"; then
    window=$(grep -B3 -Ei 'ALTER SYSTEM SET RESOURCE_MANAGER_PLAN' "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|prohibid'; then
      echo "[FAIL] $f contiene un cambio de resource plan sin contexto de prohibición"
      FAIL=1
    fi
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún cambio de CDB Resource Plan en el catálogo Multitenant"

exit $FAIL
