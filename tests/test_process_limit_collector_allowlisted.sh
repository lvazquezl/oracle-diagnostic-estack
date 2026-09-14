#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 35/47.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
for c in get_process_effective_limits get_service_limit_configuration get_pam_limit_configuration; do
  grep -q "\`$c\`" "$D" && echo "[PASS] catálogo declara $c" || { echo "[FAIL] falta $c en el catálogo"; FAIL=1; }
done
grep -qi 'PID debe provenir de .get_oracle_process_summary./.get_grid_process_summary., nunca aceptado como input arbitrario' "$D" \
  && echo "[PASS] declara validación de PID contra collectors certificados" || { echo "[FAIL] falta la validación de PID"; FAIL=1; }
grep -qi 'unit allowlisted/validada contra el PID objetivo, nunca .systemctl show <arbitrary user input>' "$D" \
  && echo "[PASS] declara que la unit systemd está allowlisted, nunca input arbitrario" || { echo "[FAIL] falta la validación de unit"; FAIL=1; }
exit $FAIL
