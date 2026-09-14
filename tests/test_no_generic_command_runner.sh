#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 74. Ningún artefacto del dominio OS
# declara un runner de comando genérico.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='run_command\(|execute_command\(|\bshell_exec\('

for f in $(find "$ROOT/agents/os-platform-analyst" "$ROOT/skills/os" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|forbidden|no crea|no expone'; then
      echo "[FAIL] $f:$lineno contiene un patrón de command runner genérico sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE "$PATTERN" "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto del dominio OS declara un command runner genérico"
exit $FAIL
