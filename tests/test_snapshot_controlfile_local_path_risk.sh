#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/21.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/snapshot-controlfile/SKILL.md"
FX="$ROOT/tests/fixtures/19c-snapshot-controlfile-local-path-rac-issue.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -qi 'ORA-00245' "$S" && echo "[PASS] rman/snapshot-controlfile documenta ORA-00245" || { echo "[FAIL] falta ORA-00245"; FAIL=1; }
grep -qi 'ORA-00245' "$FX" && echo "[PASS] fixture modela el riesgo ORA-00245" || { echo "[FAIL] fixture no modela ORA-00245"; FAIL=1; }
grep -q 'severity: HIGH' "$FX" && echo "[PASS] fixture clasifica el riesgo como HIGH" || { echo "[FAIL] fixture no clasifica severidad HIGH"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] snapshot controlfile local path risk certificado"
exit $FAIL
