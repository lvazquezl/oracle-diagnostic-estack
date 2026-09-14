#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 76.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -q '## Catálogo — Solaris' "$D" && echo "[PASS] declara el catálogo Solaris" || { echo "[FAIL] falta el catálogo Solaris"; FAIL=1; }
grep -q 'psrinfo -pv' "$D" && echo "[PASS] catálogo Solaris usa psrinfo -pv (no lscpu)" || { echo "[FAIL] falta psrinfo -pv"; FAIL=1; }
grep -qi 'terminología .aggregation' "$D" && echo "[PASS] documenta la terminología aggregation vs bonding" || { echo "[FAIL] falta la nota de terminología"; FAIL=1; }
grep -qi 'No asumir sintaxis Linux' "$D" && echo "[PASS] prohíbe asumir sintaxis Linux en Solaris" || { echo "[FAIL] falta la prohibición de sintaxis Linux"; FAIL=1; }
exit $FAIL
