#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -qi '"CROSSCHECK (cualquier variante' "$MANIFEST" && echo "[PASS] manifest prohíbe CROSSCHECK" || { echo "[FAIL] falta la prohibición de CROSSCHECK"; FAIL=1; }

for f in $(find "$ROOT/agents/oracle-backup-recovery-analyst" "$ROOT/skills/rman" "$ROOT/queries/rman" "$ROOT/parsers/rman" -type f 2>/dev/null); do
  if grep -qiE '^\s*CROSSCHECK\s' "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable de CROSSCHECK"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar CROSSCHECK"
exit $FAIL
