#!/usr/bin/env bash
# Valida que el parser Statspack nunca extraiga/almacene SQL text — sólo SQL_ID + métricas
# (# 9 STATSPACK SQL PRIVACY).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# El código del parser nunca busca/captura texto de SQL — sólo el patrón de 13-caracteres del SQL_ID.
if grep -Eq 'SQL_TEXT|SQL_FULLTEXT|sql_text' "$ROOT/parsers/performance/statspack_parser.py"; then
  echo "[FAIL] statspack_parser.py referencia SQL_TEXT/SQL_FULLTEXT"
  FAIL=1
else
  echo "[PASS] statspack_parser.py no referencia SQL_TEXT/SQL_FULLTEXT en absoluto"
fi

OUT=$(cd "$ROOT" && python3 -c "
import sys, json; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
raw = json.dumps(r.sections['sql'])
for row in r.sections['sql']:
    assert set(row.keys()) == {'sql_id', 'metrics'}, row.keys()
    assert len(row['sql_id']) == 13
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Filas SQL contienen únicamente sql_id + metrics, nunca texto de SQL"
else
  echo "[FAIL] Verificación de filas SQL falló: $OUT"
  FAIL=1
fi

exit $FAIL
