#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 73.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/security-filesystem-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca lee contenido del wallet' "$S" && echo "[PASS] prohíbe leer el contenido del wallet" || { echo "[FAIL] falta la prohibición de leer el wallet"; FAIL=1; }
grep -qi 'CRITICAL.\{0,10\}si el wallet tiene permisos .group./.world. readable' "$S" \
  && echo "[PASS] declara CRITICAL para wallet world/group readable" || { echo "[FAIL] falta la regla CRITICAL de permisos amplios"; FAIL=1; }
exit $FAIL
