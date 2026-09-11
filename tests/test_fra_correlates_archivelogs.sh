#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 18/44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/fra-pressure/SKILL.md"

for term in "archivelog" "retención|retention" "deletion policy" "flashback" "Data Guard"; do
  grep -qiE "$term" "$S" && echo "[PASS] rman/fra-pressure correlaciona con: $term" || { echo "[FAIL] falta correlación con: $term"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] FRA pressure correlaciona todas las causas del prompt (# 18)"
exit $FAIL
