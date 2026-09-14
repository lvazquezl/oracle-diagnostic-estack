#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in shared-memory semaphores aio kernel-parameter-assessment; do
  S="$ROOT/skills/os/$f/SKILL.md"
  [ -f "$S" ] || { echo "[FAIL] falta $S"; FAIL=1; continue; }
  grep -qi 'nunca ejecuta .\?sysctl -w' "$S" && echo "[PASS] os/$f prohíbe sysctl -w" || { echo "[FAIL] os/$f no prohíbe sysctl -w"; FAIL=1; }
done
exit $FAIL
