#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46/7.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -qi 'CATALOG / UNCATALOG' "$MANIFEST" && echo "[PASS] manifest prohíbe CATALOG" || { echo "[FAIL] falta la prohibición de CATALOG"; FAIL=1; }
grep -qi 'REGISTER DATABASE / RESYNC CATALOG / UPGRADE CATALOG' "$MANIFEST" && echo "[PASS] manifest prohíbe REGISTER DATABASE/RESYNC CATALOG/UPGRADE CATALOG" || { echo "[FAIL] falta la prohibición de operaciones de Recovery Catalog"; FAIL=1; }

for f in $(find "$ROOT/agents/oracle-backup-recovery-analyst" "$ROOT/skills/rman" "$ROOT/queries/rman" -type f 2>/dev/null); do
  if grep -qiE '^\s*(CATALOG\s|REGISTER DATABASE|RESYNC CATALOG|UPGRADE CATALOG)' "$f"; then
    echo "[FAIL] $f contiene una sentencia ejecutable de CATALOG/REGISTER/RESYNC/UPGRADE"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar CATALOG ni operaciones de Recovery Catalog"
exit $FAIL
