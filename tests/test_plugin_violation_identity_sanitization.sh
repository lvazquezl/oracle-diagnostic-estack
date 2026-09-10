#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 7, # 13, # 39.
# NAME puede contener el nombre real de la PDB (ej. PROD_SALES) — debe pasar por sanitización,
# mismo mapping consistente dentro del mismo análisis, nunca KEEP sin tokenizar.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"

if grep -qE '`name`.*→\s*KEEP' "$Q"; then
  echo "[FAIL] Q-CDB-PLUGIN-VIOLATIONS-001.md todavía declara name → KEEP (debería ser MASK/tokenizado)"
  FAIL=1
else
  echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001.md no deja name como KEEP"
fi

grep -qE '`name`.*→\s*\*\*MASK\*\*|`name`.*MASK' "$Q" && echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001.md declara name → MASK" || { echo "[FAIL] falta name → MASK en las notas de sanitización"; FAIL=1; }

grep -qi 'mismo mapping dentro del mismo análisis\|mapping consistente dentro del mismo análisis' "$SKILL" && echo "[PASS] SKILL.md declara mapping consistente dentro del mismo análisis" || { echo "[FAIL] falta la declaración de mapping consistente"; FAIL=1; }

grep -q 'PDB_NNN' "$Q" "$SKILL" && echo "[PASS] tokenización PDB_NNN referenciada (mismo criterio que Q-CDB-PDB-STATE-001)" || { echo "[FAIL] falta la referencia al tokenizado PDB_NNN"; FAIL=1; }

exit $FAIL
