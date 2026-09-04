#!/usr/bin/env bash
# El e-stack nunca requiere/usa identidad root para los collectors de Fase 4 (# 22, # 96).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT"/agents/oracle-rac-analyst/*.yaml "$ROOT"/agents/oracle-asm-storage-analyst/*.yaml "$ROOT"/agents/oracle-network-analyst/*.yaml; do
  [ -f "$f" ] || continue
  if grep -Eq '\brequired_os_identity:\s*root\b|identity:\s*root\b' "$f"; then
    echo "[FAIL] $f declara identidad root requerida"
    FAIL=1
  fi
done

grep -qi 'sin .root./.sudo./.grid. con capacidad de cambio\|# El e-stack NO tendrá' "$ROOT/agents/oracle-rac-analyst/AGENT.md" \
  && echo "[PASS] AGENT.md declara explícitamente sin root" \
  || { echo "[FAIL] falta declaración explícita de 'sin root' en AGENT.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara identidad root requerida"
exit $FAIL
