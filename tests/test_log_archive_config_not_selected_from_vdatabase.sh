#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 6.
# LOG_ARCHIVE_CONFIG no es columna de V$DATABASE (bug de certificación corregido en Q-DG-ROLE-001
# v1.0 -> v2.0). Ninguna query certificada debe volver a seleccionarla desde V$DATABASE, y el
# dictionary debe seguir sin registrarla ahí a propósito (para que el SQL Static Validator la
# rechace si alguien la reintroduce).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

# 1) El dictionary no debe listar log_archive_config dentro del bloque columns: de V$DATABASE.
vdb_block=$(awk '/^  V\$DATABASE:[ \t]*$/{flag=1;next} /^  [A-Za-z$#0-9_]+:[ \t]*$/{flag=0} flag' "$DICT")
if echo "$vdb_block" | grep -qi 'log_archive_config:'; then
  echo "[FAIL] compatibility/oracle-dictionary/views.yaml registra LOG_ARCHIVE_CONFIG como columna de V\$DATABASE — no existe ahí"
  FAIL=1
else
  echo "[PASS] V\$DATABASE no registra LOG_ARCHIVE_CONFIG como columna (correcto — es un parámetro, no una columna)"
fi

# 2) Ninguna query certificada selecciona log_archive_config desde v$database.
for f in $(grep -rli 'log_archive_config' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f" | tr '\n' ' ')
  if echo "$block" | grep -qi 'log_archive_config' && echo "$block" | grep -qi 'v\$database'; then
    echo "[FAIL] $f — selecciona log_archive_config en un bloque SQL que referencia v\$database"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada selecciona LOG_ARCHIVE_CONFIG desde V\$DATABASE"

# 3) LOG_ARCHIVE_CONFIG, cuando se usa, debe venir documentado vía Q-ORA-PARAMETERS-001 (V$PARAMETER).
if grep -rli 'log_archive_config' "$ROOT/skills/dataguard" "$ROOT/agents/oracle-dataguard-analyst" "$ROOT/docs" 2>/dev/null | xargs grep -L 'Q-ORA-PARAMETERS-001' 2>/dev/null | grep -q .; then
  echo "[FAIL] existe documentación de LOG_ARCHIVE_CONFIG sin atribuirla a Q-ORA-PARAMETERS-001/V\$PARAMETER"
  FAIL=1
else
  echo "[PASS] Toda mención de LOG_ARCHIVE_CONFIG en skills/agente/docs de Data Guard atribuye la fuente correcta (Q-ORA-PARAMETERS-001)"
fi

exit $FAIL
