#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/fra-pressure/SKILL.md"

grep -qi 'Abnormal patterns' "$S" && echo "[PASS] rman/fra-pressure documenta patrones anormales" || { echo "[FAIL] falta la sección Abnormal patterns"; FAIL=1; }
grep -qi 'MEDIUM' "$S" && echo "[PASS] declara severidad MEDIUM" || { echo "[FAIL] falta severidad MEDIUM"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] FRA warning classification certificada"
exit $FAIL
