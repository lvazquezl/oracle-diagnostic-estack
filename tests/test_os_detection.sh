#!/usr/bin/env bash
# Valida que os-platform-analyst y el registro de skills cubran las 5 plataformas requeridas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/agents/os-platform-analyst/AGENT.md"

for plat in "Oracle Linux" "RHEL" "SUSE" "Solaris" "AIX" "Windows Server" "HP-UX"; do
  if grep -q "$plat" "$F"; then
    echo "[PASS] os-platform-analyst declara soporte para $plat"
  else
    echo "[FAIL] os-platform-analyst no declara soporte explícito para $plat"
    FAIL=1
  fi
done

for plat in linux solaris aix windows hpux; do
  if grep -qi "$plat" "$ROOT/skills/REGISTRY.md"; then
    echo "[PASS] skills/REGISTRY.md registra plataforma $plat"
  else
    echo "[FAIL] skills/REGISTRY.md no registra plataforma $plat"
    FAIL=1
  fi
done

exit $FAIL
