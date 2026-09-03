#!/usr/bin/env bash
# Valida skills/oracle/diagnostics: materializado, activo, manifest consistente, evidencia requerida certificada.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL_DIR="$ROOT/skills/oracle/diagnostics"

if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q '^status: active' "$SKILL_DIR/SKILL.md"; then
  echo "[PASS] skills/oracle/diagnostics/SKILL.md materializado y activo"
else
  echo "[FAIL] skills/oracle/diagnostics/SKILL.md ausente o no activo"
  FAIL=1
fi

if [ -f "$SKILL_DIR/manifest.yaml" ] && grep -q 'id: oracle/diagnostics' "$SKILL_DIR/manifest.yaml"; then
  echo "[PASS] skills/oracle/diagnostics/manifest.yaml presente y consistente"
else
  echo "[FAIL] skills/oracle/diagnostics/manifest.yaml ausente o inconsistente"
  FAIL=1
fi

if grep -rq "^query_id: Q-ORA-DIAGNOSTICS-ADR-001$" "$ROOT/queries/oracle" 2>/dev/null; then
  echo "[PASS] evidencia requerida Q-ORA-DIAGNOSTICS-ADR-001 certificada y materializada"
else
  echo "[FAIL] evidencia requerida Q-ORA-DIAGNOSTICS-ADR-001 no encontrada en el catálogo"
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
