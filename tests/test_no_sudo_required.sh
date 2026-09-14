#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 74/87. Ningún collector/skill del
# dominio OS requiere sudo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -qi "root/sudo/privileged shell" "$ROOT/agents/os-platform-analyst/manifest.yaml" \
  && echo "[PASS] manifest prohíbe sudo" \
  || { echo "[FAIL] falta la prohibición explícita de sudo"; FAIL=1; }

for f in $(find "$ROOT/skills/os" -name 'SKILL.md' 2>/dev/null); do
  hits=$(grep -niE '\bsudo\b' "$f" | grep -viE 'nunca|ningun|ningún|never|prohibid|forbidden|no requiere|sin sudo' || true)
  if [ -n "$hits" ]; then
    echo "[FAIL] $f menciona sudo fuera de contexto de prohibición:"
    echo "$hits"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún skill os/* requiere sudo"
exit $FAIL
