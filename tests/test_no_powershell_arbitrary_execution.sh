#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 10/74/87. Ningún collector Windows
# ejecuta PowerShell arbitrario.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -qi "ejecución de PowerShell arbitrario" "$ROOT/agents/os-platform-analyst/manifest.yaml" \
  && echo "[PASS] manifest prohíbe PowerShell arbitrario" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

grep -qi "No exponer PowerShell arbitrario\|Ningún collector Windows ejecuta PowerShell arbitrario" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" \
  && echo "[PASS] docs/OS_READONLY_COLLECTOR_MODEL.md documenta la prohibición para collectors Windows" \
  || { echo "[FAIL] falta la documentación de la prohibición"; FAIL=1; }

for f in $(find "$ROOT/skills/os" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" \( -name '*.md' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|forbidden|no exponer|no crea'; then
      echo "[FAIL] $f:$lineno contiene un patrón de PowerShell arbitrario sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE '\bpowershell\(command\)|\biex\b|Invoke-Expression' "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto ejecuta PowerShell arbitrario"
exit $FAIL
