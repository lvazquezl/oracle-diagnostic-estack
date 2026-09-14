#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in ephemeral-ports tcp-socket-awareness network-interfaces bonding vlan mtu routing dns; do
  S="$ROOT/skills/os/$f/SKILL.md"
  [ -f "$S" ] || { echo "[FAIL] falta $S"; FAIL=1; continue; }
  if grep -A2 '# Forbidden operations' "$S" | grep -qi 'nunca'; then
    echo "[PASS] os/$f declara Forbidden operations con nunca-modifica"
  else
    echo "[FAIL] os/$f no declara una prohibición explícita de cambio"; FAIL=1
  fi
  grep -qi 'NOT_EXECUTED' "$S" && echo "[PASS] os/$f declara manual_action NOT_EXECUTED" || { echo "[FAIL] os/$f no declara NOT_EXECUTED"; FAIL=1; }
done
exit $FAIL
