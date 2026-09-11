#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 18/44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT/skills/rman/fra/SKILL.md" "$ROOT/skills/rman/fra-pressure/SKILL.md" "$ROOT/queries/rman/Q-RMAN-FRA-USAGE-001.md"; do
  [ -f "$f" ] || { echo "[FAIL] $f no existe"; FAIL=1; continue; }
  grep -qi 'nunca borra archivos\|nunca ejecuta ninguna operación de limpieza' "$f" && echo "[PASS] $(basename "$f") documenta que nunca borra archivos" || { echo "[FAIL] $(basename "$f") no prohíbe borrado de archivos"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] FRA nunca borra archivos automáticamente"
exit $FAIL
