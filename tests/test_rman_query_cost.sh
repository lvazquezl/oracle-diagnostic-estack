#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='LOW|MEDIUM|HIGH|BLOCKED'

for f in "$ROOT"/queries/rman/Q-*.md; do
  line=$(grep -m1 '^cost_class:' "$f" || true)
  if [ -z "$line" ]; then
    echo "[FAIL] $(basename "$f") no declara cost_class"
    FAIL=1
  elif ! echo "$line" | grep -Eq ": ($VALID)$"; then
    echo "[FAIL] $(basename "$f") declara cost_class fuera del enum: $line"
    FAIL=1
  elif echo "$line" | grep -q "BLOCKED"; then
    echo "[FAIL] $(basename "$f") tiene cost_class BLOCKED — no debería estar certificada"
    FAIL=1
  else
    echo "[PASS] $(basename "$f") declara cost_class válido: $line"
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Toda query RMAN declara cost_class válido, ninguna BLOCKED"
exit $FAIL
