#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42/35.
# Toda query cost_class MEDIUM+ debe declarar timeout_seconds/max_rows/max_output_bytes explícitos
# — nunca se consultan años de historia por defecto (# 35 del prompt de Fase 7).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/queries/rman/Q-*.md; do
  name=$(basename "$f")
  cost=$(grep -m1 '^cost_class:' "$f" | awk '{print $2}')
  if [ "$cost" = "MEDIUM" ] || [ "$cost" = "HIGH" ]; then
    for field in timeout_seconds max_rows max_output_bytes; do
      if ! grep -q "^${field}:" "$f"; then
        echo "[FAIL] $name (cost_class $cost) no declara $field"
        FAIL=1
      fi
    done
    echo "[PASS] $name (cost_class $cost) declara budget completo"
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Toda query RMAN cost_class MEDIUM+ declara budget explícito"
exit $FAIL
