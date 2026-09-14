#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 21. Causa raíz real: extract_aliases() (tests/test_sql_static_validator.sh) sólo
# reconocía como "objeto de vista" un token que contuviera "$" — cualquier objeto DBA_*/CDB_*/
# ALL_*/USER_*/ROLE_*/AUDIT_*/UNIFIED_*/REDACTION_* nunca entraba en alias_map, así que su
# columnas nunca se validaban (ni existencia ni version-gating). Se delega al validador real (en
# vez de duplicar su lógica) para demostrar que DBA_USERS, DBA_PROFILES, DBA_SYS_PRIVS — y, por
# extensión, cualquier objeto del dictionary sin "$" — sí pasan ahora por validación de columnas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for obj in DBA_USERS DBA_PROFILES DBA_SYS_PRIVS; do
  grep -q "^  ${obj}:" "$ROOT/compatibility/oracle-dictionary/views.yaml" \
    && echo "[PASS] $obj está registrado en el dictionary" \
    || { echo "[FAIL] $obj no está registrado en el dictionary — ajustar este test"; FAIL=1; }
done

grep -rqi 'dba_users' "$ROOT/queries/security/Q-SEC-ACCOUNT-INVENTORY-001.md" \
  && grep -rqi 'dba_profiles' "$ROOT/queries/security/Q-SEC-PASSWORD-PROFILES-001.md" \
  && grep -rqi 'dba_sys_privs' "$ROOT/queries/security/Q-SEC-SYSTEM-PRIVILEGES-001.md" \
  && echo "[PASS] el catálogo real ejercita DBA_USERS/DBA_PROFILES/DBA_SYS_PRIVS" \
  || { echo "[FAIL] el catálogo real ya no ejercita uno de estos objetos — actualizar este test"; FAIL=1; }

output=$(bash "$ROOT/tests/test_sql_static_validator.sh")
status=$?

for q in Q-SEC-DEFAULT-ACCOUNTS-001 Q-SEC-ACCOUNT-INVENTORY-001 Q-SEC-PASSWORD-PROFILES-001 Q-SEC-SYSTEM-PRIVILEGES-001; do
  if echo "$output" | grep -q "$q.*referencia\|$q.*selecciona"; then
    echo "[FAIL] el validador reporta un hallazgo inesperado sobre $q (columnas DBA_* deberían ser válidas):"
    echo "$output" | grep "$q"
    FAIL=1
  else
    echo "[PASS] $q pasa la validación de columnas DBA_* sin falsos positivos"
  fi
done

if [ "$status" -ne 0 ]; then
  echo "[FAIL] tests/test_sql_static_validator.sh falló en general (exit=$status)"
  FAIL=1
fi

exit $FAIL
