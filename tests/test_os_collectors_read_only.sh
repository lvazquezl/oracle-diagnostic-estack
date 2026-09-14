#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 74.
# Equivalente OS-específico de test_collectors_read_only.sh (Fase 4, hardcoded a
# docs/GI_READONLY_COLLECTORS.md) — domain-prefixed para no colisionar.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

grep -q 'side_effect_class: READ_ONLY|BLOCKED' "$DOC" \
  && echo "[PASS] side_effect_class declarado como READ_ONLY|BLOCKED" \
  || { echo "[FAIL] falta la declaración de side_effect_class"; FAIL=1; }

grep -qi 'side_effect_class.*es siempre .READ_ONLY. para todo collector habilitado' "$DOC" \
  && echo "[PASS] regla explícita: READ_ONLY para todo collector habilitado" \
  || { echo "[FAIL] falta la regla explícita de READ_ONLY por defecto"; FAIL=1; }

exit $FAIL
