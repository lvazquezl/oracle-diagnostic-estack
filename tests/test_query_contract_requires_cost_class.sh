#!/usr/bin/env bash
# Valida que toda query certificada declare cost_class y risk_class, y que sean campos distintos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID_COST='^cost_class: (LOW|MEDIUM|HIGH|BLOCKED)$'

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  cost=$(grep '^cost_class:' "$f" || true)
  risk=$(grep '^risk_class:' "$f" || true)
  if [ -z "$cost" ]; then
    echo "[FAIL] $f no declara cost_class"
    FAIL=1
  elif ! echo "$cost" | grep -Eq "$VALID_COST"; then
    echo "[FAIL] $f declara cost_class con valor fuera del enum: $cost"
    FAIL=1
  fi
  if [ -z "$risk" ]; then
    echo "[FAIL] $f no declara risk_class"
    FAIL=1
  fi
  # cost_class certificado nunca puede ser BLOCKED (ver policies/query-cost-policy.md)
  if echo "$cost" | grep -q 'BLOCKED'; then
    echo "[FAIL] $f está certificada con cost_class BLOCKED — eso es contradictorio (BLOCKED = rechazada del catálogo)"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Toda query certificada declara cost_class y risk_class válidos, y ninguna es BLOCKED"

exit $FAIL
