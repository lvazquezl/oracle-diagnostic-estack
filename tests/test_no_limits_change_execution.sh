#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in process-limits open-files ulimits systemd-limits; do
  S="$ROOT/skills/os/$f/SKILL.md"
  [ -f "$S" ] || { echo "[FAIL] falta $S"; FAIL=1; continue; }
  grep -qi 'nunca edita' "$S" && echo "[PASS] os/$f prohíbe editar limits.conf/units" || { echo "[FAIL] os/$f no prohíbe editar la configuración"; FAIL=1; }
  grep -qi 'NOT_EXECUTED' "$S" && echo "[PASS] os/$f declara manual_action NOT_EXECUTED" || { echo "[FAIL] os/$f no declara NOT_EXECUTED"; FAIL=1; }
done
exit $FAIL
