#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 29/36. El collector semántico de Oracle Net nunca ejecuta shell arbitrario.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/oracle-net-security/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }

grep -qi 'execute_shell(command)' "$S" && grep -qi 'nunca ejecuta shell arbitrario' "$S" \
  && echo "[PASS] SKILL.md prohíbe explícitamente shell arbitrario" \
  || { echo "[FAIL] falta la prohibición explícita de shell arbitrario"; FAIL=1; }

grep -qi 'ejecución de shell arbitrario' "$ROOT/agents/oracle-network-analyst/manifest.yaml" \
  && echo "[PASS] manifest de oracle-network-analyst prohíbe explícitamente shell arbitrario" \
  || { echo "[FAIL] falta la prohibición en manifest.yaml"; FAIL=1; }

exit $FAIL
