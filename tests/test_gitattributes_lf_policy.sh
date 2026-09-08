#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 24.
# Confirma que .gitattributes mantiene, como mínimo, eol=lf para las extensiones críticas.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/.gitattributes"
FAIL=0

[ -f "$F" ] || { echo "[FAIL] falta .gitattributes"; exit 1; }

for pattern in '\*\.sh' '\*\.bash' '\*\.py' '\*\.yaml' '\*\.yml' '\*\.json' '\*\.md'; do
  label=$(echo "$pattern" | sed 's/\\//g')
  if grep -E "^${pattern}[[:space:]]+text[[:space:]]+eol=lf" "$F" >/dev/null; then
    echo "[PASS] $label declara text eol=lf"
  else
    echo "[FAIL] $label no declara text eol=lf explícitamente"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] .gitattributes mantiene eol=lf para todas las extensiones críticas"

exit $FAIL
