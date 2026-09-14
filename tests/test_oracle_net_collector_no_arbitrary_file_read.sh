#!/usr/bin/env bash
# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING,
# sección 29/35. El collector semántico de Oracle Net nunca es un lector de archivo genérico.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/oracle-net-security/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }

grep -qi 'read_file(path)' "$S" && grep -qi 'nunca implementa un lector de archivo genérico\|path arbitrario' "$S" \
  && echo "[PASS] SKILL.md prohíbe explícitamente un lector de archivo genérico con path arbitrario" \
  || { echo "[FAIL] falta la prohibición explícita de lector de archivo genérico"; FAIL=1; }

grep -qi 'resuelve el path por convención de plataforma, nunca recibe un path del modelo' "$S" \
  && echo "[PASS] SKILL.md documenta que el path se resuelve por convención, nunca por parámetro del modelo" \
  || { echo "[FAIL] falta la aclaración de resolución de path por convención"; FAIL=1; }

grep -qi 'lector de archivo genérico' "$ROOT/agents/oracle-network-analyst/manifest.yaml" \
  && echo "[PASS] manifest de oracle-network-analyst prohíbe explícitamente lector de archivo genérico" \
  || { echo "[FAIL] falta la prohibición en manifest.yaml"; FAIL=1; }

exit $FAIL
