#!/usr/bin/env bash
# Valida que ningun agente/workflow/skill referencie un skill por nombre corto ambiguo
# (temp, undo, sga, pga, services, memory, io) en vez del skill_id completo (dominio/skill).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
AMBIGUOUS='temp|undo|sga|pga|services|memory|io'

for f in "$ROOT"/agents/*.md "$ROOT"/workflows/*.md; do
  base=$(basename "$f")
  case "$base" in _AGENT_CONTRACT_TEMPLATE.md|_WORKFLOW_CONTRACT_TEMPLATE.md) continue ;; esac
  # Buscar backtick-quoted bare ambiguous words SIN un "/" antes (no domain-qualified) dentro de
  # secciones de referencia a skills.
  hits=$(grep -noE '`('"$AMBIGUOUS"')`' "$f" || true)
  if [ -n "$hits" ]; then
    echo "[FAIL] $f referencia un nombre corto ambiguo sin calificar: $hits"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún agente/workflow referencia un skill por nombre corto ambiguo"

exit $FAIL
