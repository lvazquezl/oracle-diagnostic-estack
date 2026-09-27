#!/usr/bin/env bash
# CHG-ESTACK-ORA19C-LAB-005 — V$BACKUP_REDOLOG no tiene COMPLETION_TIME (Oracle Database Reference 19c; una query
# que la usó falló en Oracle real). Guardia de regresión independiente de tests/test_sql_static_validator.sh, que sólo
# revisa la primera lista SELECT: aquí se revisa CADA sentencia SQL certificada que lea v$backup_redolog, completa.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

block=$(awk '/^  V\$BACKUP_REDOLOG:/{f=1;next} f&&/^  [A-Z]/{exit} f' "$DICT")
if echo "$block" | grep -Eq '^ +completion_time:'; then
  echo "[FAIL] el diccionario declara V\$BACKUP_REDOLOG.completion_time, que no existe"
  FAIL=1
else
  echo "[PASS] el diccionario no declara V\$BACKUP_REDOLOG.completion_time"
fi

found=0
for f in $(grep -rl --include='Q-*.md' -i 'v\$backup_redolog' "$ROOT/queries"); do
  # CHG-ESTACK-ORA19C-LAB-006: Q-DICT-VERIFY-00N (queries/oracle/dictionary/) only read DBA_TAB_COLUMNS; view and column
  # names appear there as literal tokens generated from the dictionary (checked above and by
  # tests/test_dict_verify_queries_match_dictionary.sh), not as SQL over v$backup_redolog.
  case "$f" in "$ROOT/queries/oracle/dictionary/"*) continue ;; esac
  n=$(grep -c '```sql' "$f" || true)
  i=0
  while [ "$i" -lt "$n" ]; do
    i=$((i+1))
    sql=$(awk -v n="$i" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$f" | sed 's/--.*$//')
    # Cada sentencia separada por UNION se evalúa por separado: sólo importa si ESE tramo lee v$backup_redolog.
    # awk (portable BSD/GNU): une el bloque en una línea y la parte en tramos por UNION [ALL], siempre con \n final.
    echo "$sql" | awk '{printf "%s ", $0} END {print ""}' | awk '{gsub(/[Uu][Nn][Ii][Oo][Nn]( [Aa][Ll][Ll])?/, "\n"); print}' | while IFS= read -r part; do
      if echo "$part" | grep -qi 'v\$backup_redolog' && echo "$part" | grep -qi 'completion_time'; then
        echo "[FAIL] $(basename "$f") bloque #$i usa completion_time en una sentencia sobre v\$backup_redolog" >&2
        echo X
      fi
    done | grep -q X && FAIL=1
    found=1
  done
done
[ "$found" -eq 1 ] || { echo "[FAIL] ninguna query certificada lee v\$backup_redolog (se esperaba Q-RMAN-ARCHIVELOG-BACKUP-001)"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "[PASS] ninguna sentencia certificada sobre V\$BACKUP_REDOLOG usa COMPLETION_TIME"
exit $FAIL
