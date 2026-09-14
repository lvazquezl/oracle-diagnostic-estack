#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 76.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -q '## Catálogo — Windows' "$D" && echo "[PASS] declara el catálogo Windows" || { echo "[FAIL] falta el catálogo Windows"; FAIL=1; }
for c in get_windows_os_identity get_windows_memory_summary get_windows_network_summary get_windows_service_status get_windows_time_sync_status; do
  grep -q "\`$c\`" "$D" && echo "[PASS] catálogo Windows incluye $c" || { echo "[FAIL] falta $c en el catálogo Windows"; FAIL=1; }
done
grep -qi 'Ningún collector Windows ejecuta PowerShell arbitrario' "$D" && echo "[PASS] prohíbe PowerShell arbitrario en Windows" || { echo "[FAIL] falta la prohibición de PowerShell arbitrario"; FAIL=1; }
exit $FAIL
