#!/usr/bin/env bash
# Bootstrap check — valida prerrequisitos mínimos de la estación de trabajo del DBA.
# Ver DISTRIBUTION.md#bootstrap-validación-de-estación-de-trabajo.
# No modifica nada; sólo reporta. Exit code != 0 si algún check obligatorio falla.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

check() {
  local desc="$1"; local cond="$2"; local required="$3"
  if eval "$cond"; then
    echo "[OK]   $desc"
  else
    if [ "$required" = "required" ]; then
      echo "[FAIL] $desc"
      FAIL=1
    else
      echo "[WARN] $desc"
    fi
  fi
}

echo "== oracle-diagnostic-estack bootstrap check =="
echo "Repo root: $ROOT"
echo

check "Claude Code CLI disponible en PATH" "command -v claude >/dev/null 2>&1" "required"
check "CLAUDE.md presente" "[ -f '$ROOT/CLAUDE.md' ]" "required"
check "SECURITY.md presente" "[ -f '$ROOT/SECURITY.md' ]" "required"
check "policies/forbidden-operations.md presente" "[ -f '$ROOT/policies/forbidden-operations.md' ]" "required"
check "policies/identity-model.md presente" "[ -f '$ROOT/policies/identity-model.md' ]" "required"
check "sanitizers/data-classification-policy.md presente" "[ -f '$ROOT/sanitizers/data-classification-policy.md' ]" "required"
check "mcp/tool-manifest.md presente" "[ -f '$ROOT/mcp/tool-manifest.md' ]" "required"
check "agents/REGISTRY.md presente" "[ -f '$ROOT/agents/REGISTRY.md' ]" "required"
check "skills/REGISTRY.md presente" "[ -f '$ROOT/skills/REGISTRY.md' ]" "required"
check "queries/REGISTRY.md presente" "[ -f '$ROOT/queries/REGISTRY.md' ]" "required"
check ".claude/commands presente con comandos" "[ -d '$ROOT/.claude/commands' ] && [ \"\$(ls -1 '$ROOT/.claude/commands' | wc -l)\" -ge 13 ]" "required"

echo
check "config/estack.config.local.yaml existe (config local del DBA)" "[ -f '$ROOT/config/estack.config.local.yaml' ]" "optional"
check "config/allowed-targets.local.yaml existe (lista blanca de targets)" "[ -f '$ROOT/config/allowed-targets.local.yaml' ]" "optional"
[ -f "$ROOT/config/estack.config.local.yaml" ] || echo "       -> copiar config/estack.config.example.yaml a config/estack.config.local.yaml y ajustar"
[ -f "$ROOT/config/allowed-targets.local.yaml" ] || echo "       -> copiar config/allowed-targets.example.yaml a config/allowed-targets.local.yaml y definir targets permitidos"

echo
check "evidence/, analysis/, reports/ presentes" "[ -d '$ROOT/evidence' ] && [ -d '$ROOT/analysis' ] && [ -d '$ROOT/reports' ]" "required"

echo
if command -v oracle >/dev/null 2>&1 || [ -n "${ORACLE_HOME:-}" ]; then
  echo "[OK]   Oracle Client detectado (ORACLE_HOME o binario en PATH)"
else
  echo "[WARN] Oracle Client no detectado — requerido para collectors reales (Fase 2+); no bloquea Fase 1"
fi

echo
echo "== Resultado =="
if [ "$FAIL" -eq 0 ]; then
  echo "Bootstrap OK. El repositorio de Fase 1 está completo. Configura los archivos *.local.* antes de operar sobre un ambiente real."
  exit 0
else
  echo "Bootstrap FALLÓ uno o más checks obligatorios. Revisa los [FAIL] arriba."
  exit 1
fi
