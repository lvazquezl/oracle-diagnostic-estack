#!/usr/bin/env bash
# Valida que ningún statement SQL en queries/*.md contenga verbos de escritura.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='(^|[^A-Za-z_])(INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE)([^A-Za-z_]|$)'

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  # Extraer sólo el/los bloque(s) de código SQL (entre ```sql y ```)
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  # Descartar literales de string ('...') antes de escanear verbos — una query de auditoría
  # legítimamente filtra por action_name IN ('GRANT', 'REVOKE', ...) como VALORES buscados en
  # evidencia histórica, nunca como verbo ejecutado por el e-stack (Fase 8, Q-SEC-UNIFIED-AUDIT-TRAIL-001).
  block_no_literals=$(echo "$block" | sed -E "s/'[^']*'//g")
  if echo "$block_no_literals" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f contiene un verbo de escritura en su statement SQL"
    FAIL=1
  else
    echo "[PASS] $f — sólo lectura"
  fi
done

exit $FAIL
