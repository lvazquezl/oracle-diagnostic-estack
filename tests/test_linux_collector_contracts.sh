#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 76.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -q '## Catálogo — Linux' "$D" && echo "[PASS] declara el catálogo Linux" || { echo "[FAIL] falta el catálogo Linux"; FAIL=1; }
for c in get_hugepages_status get_ipc_limits get_multipath_summary get_interfaces get_routes; do
  grep -q "\`$c\`" "$D" && echo "[PASS] catálogo Linux incluye $c" || { echo "[FAIL] falta $c en el catálogo Linux"; FAIL=1; }
done
grep -qi 'nunca .sysctl -a' "$D" && echo "[PASS] prohíbe sysctl -a completo en Linux" || { echo "[FAIL] falta la prohibición de sysctl -a"; FAIL=1; }
exit $FAIL
