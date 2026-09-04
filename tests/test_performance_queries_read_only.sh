#!/usr/bin/env bash
# Valida que toda query certificada bajo queries/performance/ declare execution_mode: READ_ONLY
# y que su bloque SQL no contenga ningún verbo de escritura (sección 62 del prompt de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='(^|[^A-Za-z_])(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|CALL|EXECUTE IMMEDIATE)([^A-Za-z_]|$)'

for f in $(find "$ROOT/queries/performance" -name 'Q-*.md'); do
  if ! grep -q '^execution_mode: READ_ONLY$' "$f"; then
    echo "[FAIL] $f no declara execution_mode: READ_ONLY"
    FAIL=1
  fi
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f contiene un verbo de escritura en su bloque SQL"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Toda query queries/performance/ es READ_ONLY sin verbos de escritura"

exit $FAIL
