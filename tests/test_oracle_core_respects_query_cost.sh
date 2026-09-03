#!/usr/bin/env bash
# Valida que toda query Oracle Core declare cost_class válido y ninguna sea BLOCKED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='^cost_class: (LOW|MEDIUM|HIGH|BLOCKED)$'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  line=$(grep '^cost_class:' "$f" || true)
  if [ -z "$line" ] || ! echo "$line" | grep -Eq "$VALID"; then
    echo "[FAIL] $f no declara cost_class válido"
    FAIL=1
  elif echo "$line" | grep -q 'BLOCKED'; then
    echo "[FAIL] $f está certificada con cost_class BLOCKED"
    FAIL=1
  fi
done

# Fase 2 favorece LOW; MEDIUM sólo cuando necesario; HIGH evitado salvo justificación (sección 15).
high_count=$(grep -rl '^cost_class: HIGH$' "$ROOT/queries/oracle" 2>/dev/null | wc -l)
if [ "$high_count" -eq 0 ]; then
  echo "[PASS] Ninguna query Oracle Core (Fase 2) es cost_class HIGH — favorece LOW/MEDIUM"
else
  echo "[FAIL] $high_count query(s) Oracle Core son cost_class HIGH sin justificación excepcional esperada en Fase 2"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] Toda query Oracle Core declara cost_class válido y ninguna es BLOCKED"

exit $FAIL
