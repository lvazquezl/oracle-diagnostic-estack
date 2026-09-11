#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44/27.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/pitr-readiness/SKILL.md"
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

for m in "UNTIL TIME" "UNTIL SCN" "UNTIL SEQUENCE"; do
  grep -qF "$m" "$S" && echo "[PASS] rman/pitr-readiness reconoce $m" || { echo "[FAIL] falta $m"; FAIL=1; }
done
grep -qi 'siempre manual\|Siempre manual' "$S" && echo "[PASS] documenta que siempre es manual" || { echo "[FAIL] falta 'siempre manual'"; FAIL=1; }
grep -qi 'RESTORE (cualquier variante' "$MANIFEST" && echo "[PASS] manifest prohíbe RESTORE en cualquier variante (incl. UNTIL)" || { echo "[FAIL] falta prohibición de RESTORE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PITR awareness certificado, siempre manual"
exit $FAIL
