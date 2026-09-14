#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/34.
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING:
# reescrito porque Q-SEC-NETWORK-ENCRYPTION-PARAMS-001 (que este test antes verificaba como
# fuente activa) fue retirada — SQLNET.* nunca fue evidencia válida de V$PARAMETER. La fuente de
# evidencia ahora es el collector semántico network/oracle-net-security, propiedad de
# oracle-network-analyst.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/network-encryption/SKILL.md"
NS="$ROOT/skills/network/oracle-net-security/SKILL.md"

[ -f "$NS" ] || { echo "[FAIL] falta $NS"; exit 1; }

for p in SQLNET.ENCRYPTION_CLIENT SQLNET.ENCRYPTION_SERVER SQLNET.CRYPTO_CHECKSUM; do
  grep -qi "$p" "$NS" && echo "[PASS] network/oracle-net-security referencia $p" || { echo "[FAIL] falta $p"; FAIL=1; }
done

grep -qi "oracle-network-analyst" "$S" && echo "[PASS] security/network-encryption integra con oracle-network-analyst" || { echo "[FAIL] falta la integración documentada"; FAIL=1; }

grep -q '^status: not_certified' "$ROOT/queries/security/Q-SEC-NETWORK-ENCRYPTION-PARAMS-001.md" \
  && echo "[PASS] Q-SEC-NETWORK-ENCRYPTION-PARAMS-001 permanece retirada (NOT_CERTIFIED)" \
  || { echo "[FAIL] Q-SEC-NETWORK-ENCRYPTION-PARAMS-001 ya no está marcada como retirada"; FAIL=1; }

exit $FAIL
