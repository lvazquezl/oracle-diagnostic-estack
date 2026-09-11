#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -qi 'ALLOCATE CHANNEL / RELEASE CHANNEL' "$MANIFEST" && echo "[PASS] manifest prohíbe ALLOCATE/RELEASE CHANNEL" || { echo "[FAIL] falta la prohibición de ALLOCATE/RELEASE CHANNEL"; FAIL=1; }

for f in $(find "$ROOT/queries/rman" "$ROOT/skills/rman" "$ROOT/parsers/rman" -type f 2>/dev/null); do
  if grep -qiE '^\s*(ALLOCATE CHANNEL|RELEASE CHANNEL)\b' "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable de ALLOCATE/RELEASE CHANNEL"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ALLOCATE/RELEASE CHANNEL"
exit $FAIL
