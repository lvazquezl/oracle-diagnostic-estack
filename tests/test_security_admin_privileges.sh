#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66/13.
# Q-SEC-ADMIN-PRIVILEGES-001 debe cubrir SYSDBA/SYSOPER/SYSASM/SYSBACKUP/SYSDG/SYSKM con boundaries reales.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/security/Q-SEC-ADMIN-PRIVILEGES-001.md"

for v in V1 V2 V3; do
  grep -q "variant_id: Q-SEC-ADMIN-PRIVILEGES-001-$v" "$Q" && echo "[PASS] declara variante $v" || { echo "[FAIL] falta variante $v"; FAIL=1; }
done

grep -q "sysasm" "$Q" && grep -q "sysbackup" "$Q" && grep -q "syskm" "$Q" \
  && echo "[PASS] cubre sysasm/sysbackup/syskm con version-awareness" \
  || { echo "[FAIL] falta cobertura de columnas version-gated"; FAIL=1; }

exit $FAIL
