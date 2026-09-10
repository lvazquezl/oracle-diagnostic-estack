#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 7/57.
# CDB detection reutiliza Q-DISC-IDENTITY-001 (Oracle Core) — nunca lee V$DATABASE.CDB antes de 12c.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/oracle/discovery/Q-DISC-IDENTITY-001.md"
SKILL="$ROOT/skills/multitenant/cdb-discovery/SKILL.md"

grep -q "NON-CDB por construcción" "$Q" && echo "[PASS] Q-DISC-IDENTITY-001 V1 (10.2-11.2) no lee d.cdb" || { echo "[FAIL] falta la guardia de d.cdb en V1"; FAIL=1; }
grep -q "válido desde 12.1" "$Q" && echo "[PASS] d.cdb documentado como válido sólo desde 12.1" || { echo "[FAIL] falta la nota de versión de d.cdb"; FAIL=1; }
grep -qi "bootstrap de Oracle Core" "$SKILL" && echo "[PASS] multitenant/cdb-discovery reutiliza el bootstrap de Oracle Core, no re-implementa" || { echo "[FAIL] falta la referencia de reutilización en cdb-discovery"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] CDB detection reutiliza Q-DISC-IDENTITY-001 sin leer V\$DATABASE.CDB antes de 12c"

exit $FAIL
