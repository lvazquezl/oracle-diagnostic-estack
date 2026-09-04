#!/usr/bin/env bash
# Valida que routing.yaml declare condiciones de activación explícitas y delegación deliberada
# (# 28 ROUTING: "evitar activaciones innecesarias").
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
R="$ROOT/agents/oracle-performance-analyst/routing.yaml"

[ -f "$R" ] || { echo "[FAIL] falta routing.yaml"; exit 1; }

grep -q '^activation_conditions:' "$R" && echo "[PASS] declara activation_conditions" || { echo "[FAIL] falta activation_conditions"; FAIL=1; }
grep -q '^deactivation_rule:' "$R" && echo "[PASS] declara deactivation_rule (evita activación por defecto)" || { echo "[FAIL] falta deactivation_rule"; FAIL=1; }
grep -q '^delegates_to:' "$R" && echo "[PASS] declara delegates_to" || { echo "[FAIL] falta delegates_to"; FAIL=1; }
grep -q '^receives_from:' "$R" && echo "[PASS] declara receives_from" || { echo "[FAIL] falta receives_from"; FAIL=1; }
grep -q '^must_not_delegate_to:' "$R" && echo "[PASS] declara must_not_delegate_to" || { echo "[FAIL] falta must_not_delegate_to"; FAIL=1; }

for agent in oracle-rac-analyst oracle-asm-storage-analyst os-platform-analyst incident-root-cause-analyst change-advisor capacity-analyst; do
  grep -q "agent: $agent" "$R" && echo "[PASS] delegates_to incluye $agent" || { echo "[FAIL] delegates_to no incluye $agent"; FAIL=1; }
done

exit $FAIL
