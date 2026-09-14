#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/open-files/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'file_max' "$S" && echo "[PASS] declara file_max" || { echo "[FAIL] falta file_max"; FAIL=1; }
grep -qi '> 80%.*MEDIUM\|> 95%.*HIGH' "$S" && echo "[PASS] declara umbrales 80%/95%" || { echo "[FAIL] faltan los umbrales"; FAIL=1; }
grep -qi 'rman-media-manager-awareness' "$S" && echo "[PASS] correlaciona con RMAN media manager" || { echo "[FAIL] falta la correlación RMAN"; FAIL=1; }
exit $FAIL
