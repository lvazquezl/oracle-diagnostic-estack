#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/rman/Q-RMAN-ARCHIVELOG-BACKUP-001.md"
Q2="$ROOT/queries/rman/Q-RMAN-ARCHIVED-LOG-COVERAGE-001.md"

for f in "$Q" "$Q2"; do
  [ -f "$f" ] || { echo "[FAIL] $f no existe"; FAIL=1; continue; }
  if ! grep -qi 'thread#' "$f"; then
    echo "[FAIL] $f no agrupa por THREAD#"
    FAIL=1
  fi
done
grep -qi 'nunca mezcla threads\|nunca se compara.*secuencias entre threads\|nunca compar' "$Q" "$Q2" >/dev/null 2>&1 \
  && echo "[PASS] documenta que nunca mezcla threads" \
  || { echo "[FAIL] falta la prohibición explícita de mezclar threads"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Cobertura de backup de archivelog thread-aware certificada"
exit $FAIL
