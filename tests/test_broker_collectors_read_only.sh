#!/usr/bin/env bash
# Los 4 collectors Broker mapean exclusivamente a subcomandos SHOW allowlisted (# 23).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md"

for cid in get_dataguard_configuration get_dataguard_database_status get_dataguard_verbose_status get_fsfo_status; do
  grep -q "\`$cid\`" "$DOC" && echo "[PASS] $cid documentado" || { echo "[FAIL] $cid no documentado"; FAIL=1; }
done

for cmd in "SHOW CONFIGURATION" "SHOW DATABASE" "SHOW FAST_START FAILOVER"; do
  grep -qF "$cmd" "$DOC" && echo "[PASS] comando allowlisted documentado: $cmd" || { echo "[FAIL] falta comando: $cmd"; FAIL=1; }
done

exit $FAIL
