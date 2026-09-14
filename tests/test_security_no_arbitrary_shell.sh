#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72.
# Nombre domain-prefixed (tests/test_no_arbitrary_shell.sh ya existe, propiedad de otro dominio).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='execute_shell\(|run_shell\(|os\.system\(|subprocess\.'

for f in $(find "$ROOT/agents/oracle-security-analyst" "$ROOT/skills/security" "$ROOT/queries/security" -type f 2>/dev/null); do
  if grep -qiE "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un patrón de ejecución de shell"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto Security contiene capacidad de shell arbitrario"

exit $FAIL
