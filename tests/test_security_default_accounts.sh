#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 8. Test faltante identificado por el hardening: Q-SEC-DEFAULT-ACCOUNTS-001 declaraba
# min_version: 11.0 y seleccionaba incondicionalmente DBA_USERS.ORACLE_MAINTAINED sin que ningún
# test lo detectara (causa raíz: gap del Static Validator para objetos DBA_*, ya corregido en
# tests/test_sql_static_validator.sh#extract_aliases).
#
# PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION: reescrito — ORACLE_MAINTAINED
# requiere 12.1.0.2 específicamente (footnote oficial verbatim en docs.oracle.com/database/121/
# REFRN/.../DBA_USERS: "This column is available starting with Oracle Database 12c Release 1
# (12.1.0.2)", verificado en el HTML crudo, sin resumen de modelo), no 12.1.0.1 genérico como se
# certificó en el micro-hardening previo. Variant V1 ahora cubre 11.0-12.1.0.1 (no sólo 11.0-11.2)
# y Variant V2 ahora empieza en 12.1.0.2 (no 12.1).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/security/Q-SEC-DEFAULT-ACCOUNTS-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-SEC-DEFAULT-ACCOUNTS-001.md"; exit 1; }

sql_block() {
  awk -v n="$1" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$Q"
}

# Legacy variant covers 11g through 12.1.0.1 (ORACLE_MAINTAINED does not exist there)
grep -q "variant_id: Q-SEC-DEFAULT-ACCOUNTS-001-V1" "$Q" \
  && grep -q 'oracle_versions: {min: "11.0", max: "12.1.0.1"}' "$Q" \
  && echo "[PASS] Variant V1 (legacy_pre12102, 11.0-12.1.0.1) existe" \
  || { echo "[FAIL] falta Variant V1 acotada a 11.0-12.1.0.1"; FAIL=1; }

v1_block=$(sql_block 1)
if echo "$v1_block" | grep -qi 'oracle_maintained'; then
  echo "[FAIL] Variant V1 (legacy) selecciona oracle_maintained — columna no existe antes de 12.1.0.2"
  FAIL=1
else
  echo "[PASS] Variant V1 (legacy, hasta 12.1.0.1) no referencia oracle_maintained"
fi

# Modern variant starts at 12.1.0.2 (ORACLE_MAINTAINED's real boundary, footnote oficial)
grep -q "variant_id: Q-SEC-DEFAULT-ACCOUNTS-001-V2" "$Q" \
  && grep -q 'oracle_versions: {min: "12.1.0.2", max: "23.0"}' "$Q" \
  && echo "[PASS] Variant V2 (modern_12102plus, 12.1.0.2+) existe" \
  || { echo "[FAIL] falta Variant V2 acotada a 12.1.0.2-23.0"; FAIL=1; }

v2_block=$(sql_block 2)
if echo "$v2_block" | grep -qi 'oracle_maintained'; then
  echo "[PASS] Variant V2 (12.1.0.2+) selecciona oracle_maintained"
else
  echo "[FAIL] Variant V2 (12.1.0.2+) no selecciona oracle_maintained"
  FAIL=1
fi

# output normalization exists
grep -q 'default_account:' "$Q" && grep -q 'source_variant:' "$Q" && grep -q 'NOT_AVAILABLE' "$Q" \
  && echo "[PASS] Output normalization (default_account/source_variant/NOT_AVAILABLE) documentado" \
  || { echo "[FAIL] falta el modelo de output normalization"; FAIL=1; }

exit $FAIL
