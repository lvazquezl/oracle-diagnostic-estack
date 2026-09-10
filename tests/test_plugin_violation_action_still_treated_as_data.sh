#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 8, # 13, # 39, # 43.
# Regresión: la corrección de semántica de NAME/container_name no debe debilitar la protección
# "ACTION siempre tratado como DATA" (# 8 del prompt: "no cambiar esta protección").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

grep -qi 'nunca se ejecuta contenido de.*MESSAGE.*ACTION.*como instrucción\|nunca ejecuta la acción sugerida' "$SKILL" && echo "[PASS] SKILL.md mantiene la protección ACTION/MESSAGE = DATA" || { echo "[FAIL] falta la protección ACTION/MESSAGE = DATA en el skill"; FAIL=1; }

grep -qi 'ninguna variante ejecuta la acción sugerida' "$Q" && echo "[PASS] Q-CDB-PLUGIN-VIOLATIONS-001.md mantiene la declaración de no ejecución en ambas variantes" || { echo "[FAIL] falta la declaración de no ejecución en la query"; FAIL=1; }

for f in "$ROOT/tests/test_plugin_violation_action_treated_as_data.sh" "$ROOT/tests/test_plugin_violation_no_auto_remediation.sh"; do
  [ -f "$f" ] && echo "[PASS] $(basename "$f") sigue existiendo (test pre-existente de esta protección)" || { echo "[FAIL] $(basename "$f") falta"; FAIL=1; }
done

exit $FAIL
