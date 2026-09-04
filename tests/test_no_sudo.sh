#!/usr/bin/env bash
# El e-stack nunca requiere/usa sudo para los collectors de Fase 4.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT"/parsers/rac/*.py; do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    line=$(sed -n "${lineno}p" "$f")
    if ! echo "$line" | grep -qiE 'sin .{0,20}sudo|nunca|ningun|prohibid'; then
      echo "[FAIL] $f:$lineno menciona sudo sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE '\bsudo\b' "$f")
done

grep -qi 'sin .root./.sudo./.grid.' "$ROOT/agents/oracle-rac-analyst/AGENT.md" \
  && echo "[PASS] AGENT.md declara explícitamente sin sudo" \
  || { echo "[FAIL] falta declaración explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto Fase 4 menciona/requiere sudo"
exit $FAIL
