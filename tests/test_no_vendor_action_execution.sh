#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/24.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/sbt-media-manager/SKILL.md"

grep -qi 'nunca ejecuta acciones del vendor' "$S" && echo "[PASS] rman/sbt-media-manager documenta que nunca ejecuta acciones del vendor" || { echo "[FAIL] falta la prohibición de acciones del vendor"; FAIL=1; }

for f in $(find "$ROOT/skills/rman" "$ROOT/parsers/rman" -type f 2>/dev/null); do
  if grep -qiE '(execute|run|trigger)_(vendor|backup)_job\(' "$f"; then
    echo "[FAIL] $f contiene un wrapper de ejecución de job del vendor"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar acciones del vendor de media manager"
exit $FAIL
