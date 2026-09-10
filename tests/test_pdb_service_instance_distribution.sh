#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 59.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-SERVICES-001.md"

[ -f "$Q" ] || { echo "[FAIL] falta Q-CDB-SERVICES-001.md"; exit 1; }
grep -qi "gv\$services" "$Q" && grep -qi "gv\$active_services" "$Q" && echo "[PASS] usa GV\$SERVICES/GV\$ACTIVE_SERVICES (multi-instancia)" || { echo "[FAIL] falta el uso de vistas GV\$ multi-instancia"; FAIL=1; }
grep -qi "inst_id" "$Q" && echo "[PASS] selecciona inst_id para distribución por instancia" || { echo "[FAIL] falta inst_id"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Distribución de servicio por instancia correctamente implementada"

exit $FAIL
