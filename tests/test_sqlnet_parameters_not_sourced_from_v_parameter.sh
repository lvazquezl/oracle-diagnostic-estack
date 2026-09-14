#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 33. Guardia de regresión: ninguna query CERTIFICADA (status != not_certified) puede
# volver a intentar obtener SQLNET.* desde V$PARAMETER/V$SPPARAMETER — SQLNET.* es configuración
# de Oracle Net (sqlnet.ora), nunca un parámetro de inicialización de instancia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  # Queries retiradas (not_certified) se conservan como registro histórico del defecto — no
  # deben re-evaluarse como si fueran certificadas.
  if grep -q '^status: not_certified' "$f"; then
    continue
  fi
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -qiE "v\\\$s?parameter" && echo "$block" | grep -qi 'sqlnet\.'; then
    echo "[FAIL] $f obtiene SQLNET.* desde V\$PARAMETER/V\$SPPARAMETER — SQLNET.* no es evidencia de parámetro de instancia"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query certificada obtiene SQLNET.* desde V\$PARAMETER/V\$SPPARAMETER"

# Confirma que la query defectuosa original está correctamente retirada, no simplemente eliminada
# ni silenciosamente reescrita sin dejar rastro del defecto.
Q="$ROOT/queries/security/Q-SEC-NETWORK-ENCRYPTION-PARAMS-001.md"
if [ -f "$Q" ] && grep -q '^status: not_certified' "$Q" && grep -q 'not_certified_reason: INCORRECT_EVIDENCE_SOURCE' "$Q"; then
  echo "[PASS] Q-SEC-NETWORK-ENCRYPTION-PARAMS-001 correctamente retirada (NOT_CERTIFIED: INCORRECT_EVIDENCE_SOURCE)"
else
  echo "[FAIL] Q-SEC-NETWORK-ENCRYPTION-PARAMS-001 no está marcada como retirada correctamente"
  FAIL=1
fi

exit $FAIL
