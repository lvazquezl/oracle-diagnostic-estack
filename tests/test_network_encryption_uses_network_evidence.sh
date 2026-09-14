#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 34. security/network-encryption debe declarar como fuente de evidencia el collector
# semántico de Oracle Net o evidencia manual sanitizada — nunca V$PARAMETER/init parameters.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/network-encryption/SKILL.md"
M="$ROOT/skills/security/network-encryption/manifest.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }

grep -qi 'get_oracle_net_security_configuration' "$S" \
  && echo "[PASS] network-encryption referencia el collector semántico get_oracle_net_security_configuration" \
  || { echo "[FAIL] falta la referencia al collector semántico"; FAIL=1; }

grep -qi 'MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION' "$S" \
  && echo "[PASS] network-encryption acepta evidencia manual sanitizada de Oracle Net como fallback" \
  || { echo "[FAIL] falta el fallback de evidencia manual sanitizada"; FAIL=1; }

if grep -qi 'query_id: Q-SEC-NETWORK-ENCRYPTION-PARAMS-001' "$M"; then
  echo "[FAIL] manifest todavía referencia la query retirada como fuente de evidencia"
  FAIL=1
else
  echo "[PASS] manifest ya no referencia la query retirada como fuente de evidencia"
fi

if grep -qiE 'Read-only operations.*V\$PARAMETER|V\$PARAMETER.*filtrada' "$S"; then
  echo "[FAIL] SKILL.md todavía declara V\$PARAMETER como su operación de lectura"
  FAIL=1
else
  echo "[PASS] SKILL.md ya no declara V\$PARAMETER como su fuente de lectura"
fi

exit $FAIL
