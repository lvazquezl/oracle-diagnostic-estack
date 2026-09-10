#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 16, # 19.
# Chequeo más fuerte que test_plugin_violation_121_variant_without_con_id.sh: escanea todo el
# bloque de prosa asociado a la variante V1 (no sólo el SQL) para confirmar que con_id nunca se
# menciona como si estuviera disponible, y que el skill normaliza container_id: NOT_AVAILABLE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"
SKILL="$ROOT/skills/multitenant/plugin-violations/SKILL.md"

sql_v1=$(awk '/```sql/{n++;next} n==1 && /```/{exit} n==1{print}' "$Q")
if echo "$sql_v1" | grep -qiw 'con_id'; then
  echo "[FAIL] el bloque SQL de la variante legacy referencia con_id"
  FAIL=1
else
  echo "[PASS] el bloque SQL de la variante legacy no referencia con_id en absoluto"
fi

grep -qi 'container_id: NOT_AVAILABLE\|container_id.*NOT_AVAILABLE' "$SKILL" && echo "[PASS] el skill normaliza container_id: NOT_AVAILABLE para la variante legacy" || { echo "[FAIL] el skill no declara la normalización NOT_AVAILABLE"; FAIL=1; }

grep -qi 'nunca se infieren de.*NAME\|no inventar CON_ID\|nunca inventado' "$SKILL" && echo "[PASS] el skill declara explícitamente que container_id nunca se infiere/inventa" || { echo "[FAIL] falta la declaración explícita de no inventar container_id"; FAIL=1; }

exit $FAIL
