#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/fra-pressure/SKILL.md"

grep -qi 'LOW|MEDIUM|HIGH|CRITICAL' "$S" && echo "[PASS] rman/fra-pressure declara enum LOW/MEDIUM/HIGH/CRITICAL" || { echo "[FAIL] falta el enum de presión"; FAIL=1; }
grep -qi 'estable, con.*SPACE_RECLAIMABLE\|Normal state' "$S" && echo "[PASS] documenta estado normal" || { echo "[FAIL] falta el estado normal"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] FRA healthy classification certificada"
exit $FAIL
