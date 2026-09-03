#!/usr/bin/env bash
# Valida skills/oracle/controlfile: materializado, activo, manifest consistente, evidencia requerida certificada.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL_DIR="$ROOT/skills/oracle/controlfile"

if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q '^status: active' "$SKILL_DIR/SKILL.md"; then
  echo "[PASS] skills/oracle/controlfile/SKILL.md materializado y activo"
else
  echo "[FAIL] skills/oracle/controlfile/SKILL.md ausente o no activo"
  FAIL=1
fi

if [ -f "$SKILL_DIR/manifest.yaml" ] && grep -q 'id: oracle/controlfile' "$SKILL_DIR/manifest.yaml"; then
  echo "[PASS] skills/oracle/controlfile/manifest.yaml presente y consistente"
else
  echo "[FAIL] skills/oracle/controlfile/manifest.yaml ausente o inconsistente"
  FAIL=1
fi

if grep -rq "^query_id: Q-ORA-CONTROLFILE-001$" "$ROOT/queries/oracle" 2>/dev/null; then
  echo "[PASS] evidencia requerida Q-ORA-CONTROLFILE-001 certificada y materializada"
else
  echo "[FAIL] evidencia requerida Q-ORA-CONTROLFILE-001 no encontrada en el catálogo"
  FAIL=1
fi

for section in "# Diagnostic logic / Decision tree" "# Confidence model" "# DBA commands / prechecks / rollback / postchecks" "# Change history"; do
  if grep -qF "$section" "$SKILL_DIR/SKILL.md"; then
    echo "[PASS] $SKILL_DIR/SKILL.md declara '$section'"
  else
    echo "[FAIL] $SKILL_DIR/SKILL.md no declara '$section'"
    FAIL=1
  fi
done

exit $FAIL
