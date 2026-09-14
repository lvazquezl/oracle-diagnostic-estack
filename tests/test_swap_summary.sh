#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/swap/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'NO es por sí solo un incidente\|no declarar incidente sólo por swap' "$S" \
  && echo "[PASS] declara que swap_used > 0 no es incidente por sí solo" || { echo "[FAIL] falta la regla anti-falso-positivo"; FAIL=1; }
exit $FAIL
