#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46/8.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -qi '"CONFIGURE (cualquier variante' "$MANIFEST" && echo "[PASS] manifest prohíbe CONFIGURE" || { echo "[FAIL] falta la prohibición de CONFIGURE"; FAIL=1; }

for f in $(find "$ROOT/agents/oracle-backup-recovery-analyst" "$ROOT/skills/rman" "$ROOT/queries/rman" -type f 2>/dev/null); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|prohibid|forbidden|blocked'; then
      echo "[FAIL] $f:$lineno contiene CONFIGURE ejecutable sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE '^\s*CONFIGURE\s' "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna capacidad real de ejecutar CONFIGURE"
exit $FAIL
