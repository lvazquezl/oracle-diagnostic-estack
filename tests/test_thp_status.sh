#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/transparent-hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'always.*madvise.*never\|always|madvise|never' "$S" && echo "[PASS] declara los 3 estados de THP" || { echo "[FAIL] faltan los estados de THP"; FAIL=1; }
grep -qi 'nunca inferido, siempre leído' "$S" && echo "[PASS] declara que el estado se lee, nunca se infiere" || { echo "[FAIL] falta la regla de lectura directa"; FAIL=1; }
exit $FAIL
