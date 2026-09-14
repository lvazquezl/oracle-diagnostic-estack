#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca.*reportarlos como si fueran el mismo límite\|No confundir límites por' "$S" \
  && echo "[PASS] distingue nproc por usuario de pid_max global" || { echo "[FAIL] falta la distinción nproc/pid_max"; FAIL=1; }
grep -q 'nproc_soft' "$S" && echo "[PASS] declara nproc_soft en el output" || { echo "[FAIL] falta nproc_soft"; FAIL=1; }
exit $FAIL
