#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 74. Ningún artefacto del dominio OS
# declara un lector de archivo genérico con path arbitrario.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='read_file\(path\)|\bcat\(path\)'

for f in $(find "$ROOT/agents/os-platform-analyst" "$ROOT/skills/os" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|forbidden|no crea|no expone|lector de archivo genérico'; then
      echo "[FAIL] $f:$lineno contiene un patrón de lectura de archivo arbitraria sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE "$PATTERN" "$f")
done

grep -q 'lector de archivo genérico' "$ROOT/agents/os-platform-analyst/manifest.yaml" \
  && echo "[PASS] manifest de os-platform-analyst prohíbe explícitamente lector de archivo genérico" \
  || { echo "[FAIL] falta la prohibición en manifest.yaml"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto del dominio OS declara lectura de archivo arbitraria"
exit $FAIL
