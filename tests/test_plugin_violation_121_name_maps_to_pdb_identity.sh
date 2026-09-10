#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 4-5, # 13, # 39.
# Valida que la semántica documentada de NAME (identidad de PDB, no violación/componente) está
# reflejada en la query y el skill — verificado contra Oracle Database Reference 12.1/19c:
# "The name of an existing PDB or a PDB intended to be created".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

grep -qi 'identidad de PDB\|es la identidad de PDB\|PDB identity' "$Q" && echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001.md declara NAME como identidad de PDB" || { echo "[FAIL] falta la semántica correcta de NAME en la query"; FAIL=1; }

grep -qi 'existing PDB or a PDB intended to be created' "$DICT" && echo "[PASS] el dictionary cita la descripción verificada de Oracle para NAME" || { echo "[FAIL] falta la cita textual de Oracle Database Reference"; FAIL=1; }

if grep -qi 'nombre de la violación, ej. componente\|no un nombre de violación\|identifica la violación/componente' "$SKILL"; then
  if ! grep -qi 'corrige una interpretación incorrecta' "$SKILL"; then
    echo "[FAIL] SKILL.md todavía contiene la afirmación incorrecta sobre NAME sin marcarla como corregida"
    FAIL=1
  else
    echo "[PASS] SKILL.md sólo referencia la afirmación incorrecta como corrección histórica"
  fi
else
  echo "[PASS] SKILL.md no contiene la afirmación incorrecta sobre NAME"
fi

exit $FAIL
