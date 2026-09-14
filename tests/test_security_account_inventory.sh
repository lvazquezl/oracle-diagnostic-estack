#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66.
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING:
# Q-SEC-ACCOUNT-INVENTORY-001 se dividió de 2 a 3 variantes porque DBA_USERS.LAST_LOGIN requiere
# 12.1.0.2 específicamente (no "12.1" genérico).
#
# PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION: reescrito — COMMON y
# ORACLE_MAINTAINED también requieren 12.1.0.2 (footnote oficial verbatim en
# docs.oracle.com/database/121/REFRN/.../DBA_USERS, verificado en el HTML crudo sin resumen de
# modelo: "This column is available starting with Oracle Database 12c Release 1 (12.1.0.2)."
# adjunta a las tres columnas), no 12.1.0.1 como se certificó en el micro-hardening previo.
# Variant V2 (12.1-12.1.0.1) ahora sólo selecciona AUTHENTICATION_TYPE (certificada
# independientemente, 11.2+) — ni COMMON ni ORACLE_MAINTAINED. Variant V3 (12.1.0.2+) es la única
# que selecciona las tres columnas patch-level-gated.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/security/Q-SEC-ACCOUNT-INVENTORY-001.md"

[ -f "$Q" ] && echo "[PASS] Q-SEC-ACCOUNT-INVENTORY-001.md existe" || { echo "[FAIL] falta Q-SEC-ACCOUNT-INVENTORY-001.md"; FAIL=1; }

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q" 2>/dev/null)
if echo "$block" | grep -Eiq 'password\b|spare4'; then
  echo "[FAIL] Q-SEC-ACCOUNT-INVENTORY-001 selecciona columna de credencial"
  FAIL=1
else
  echo "[PASS] Q-SEC-ACCOUNT-INVENTORY-001 no selecciona password/spare4"
fi

grep -q "variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V1" "$Q" \
  && grep -q "variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V2" "$Q" \
  && grep -q "variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V3" "$Q" \
  && echo "[PASS] declara las 3 variantes legacy_pre12c/multitenant_pre12102/modern_12102plus" \
  || { echo "[FAIL] faltan una o más variantes V1/V2/V3"; FAIL=1; }

grep -q 'oracle_versions: {min: "12.1", max: "12.1.0.1"}' "$Q" \
  && echo "[PASS] Variant V2 acotada a 12.1-12.1.0.1" \
  || { echo "[FAIL] Variant V2 no declara el boundary 12.1-12.1.0.1"; FAIL=1; }

grep -q 'oracle_versions: {min: "12.1.0.2", max: "23.0"}' "$Q" \
  && echo "[PASS] Variant V3 acotada a 12.1.0.2+ (con common/oracle_maintained/last_login)" \
  || { echo "[FAIL] Variant V3 no declara el boundary 12.1.0.2+"; FAIL=1; }

sql_block() {
  awk -v n="$1" '/```sql/{c++} c==n && /```sql/{flag=1;next} flag && /```/{flag=0} flag' "$Q"
}

v2_block=$(sql_block 2)
for col in common oracle_maintained last_login; do
  if echo "$v2_block" | grep -qi "$col"; then
    echo "[FAIL] Variant V2 (12.1-12.1.0.1) selecciona $col, columna que requiere 12.1.0.2"
    FAIL=1
  else
    echo "[PASS] Variant V2 no selecciona $col"
  fi
done
if echo "$v2_block" | grep -qi 'authentication_type'; then
  echo "[PASS] Variant V2 selecciona authentication_type (certificada independientemente, 11.2+)"
else
  echo "[FAIL] Variant V2 no selecciona authentication_type"
  FAIL=1
fi

v3_block=$(sql_block 3)
for col in common oracle_maintained last_login; do
  if echo "$v3_block" | grep -qi "$col"; then
    echo "[PASS] Variant V3 selecciona $col"
  else
    echo "[FAIL] Variant V3 (12.1.0.2+) no selecciona $col"
    FAIL=1
  fi
done

exit $FAIL
