#!/usr/bin/env bash
# Valida que ningún agente solicite SYSDBA/SYSOPER/SYSASM/root/sudo para sí mismo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/agents/*.md "$ROOT"/agents/*/AGENT.md; do
  base=$(basename "$f")
  [ "$base" = "_AGENT_CONTRACT_TEMPLATE.md" ] && continue
  # Buscar menciones de privilegios elevados que NO estén en una línea de negación/prohibición
  hits=$(grep -niE 'SYSDBA|SYSOPER|SYSASM|\bsudo\b|\bas root\b|root (user|access|password|privilege)' "$f" | grep -viE 'no requiere|nunca|forbidden|prohibi|sin.*sysdba|sin `sysdba|no dispone|read-only' || true)
  if [ -n "$hits" ]; then
    echo "[FAIL] $f menciona un privilegio elevado fuera de contexto de prohibición:"
    echo "$hits"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún agente solicita privilegios elevados para sí mismo"

exit $FAIL
