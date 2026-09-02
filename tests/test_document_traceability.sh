#!/usr/bin/env bash
# Valida que la documentación exija análisis Markdown de origen antes de cualquier binario.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT/agents/technical-documentation-manager.md" "$ROOT/skills/documentation/healthcheck-report.md" "$ROOT/workflows/document.md"; do
  if grep -q 'NO ANALYSIS WITHOUT EVIDENCE RECORD\|NO DELIVERABLE WITHOUT TRACEABILITY' "$f"; then
    echo "[PASS] $f exige trazabilidad al análisis de origen"
  else
    echo "[FAIL] $f no exige trazabilidad al análisis de origen"
    FAIL=1
  fi
done

exit $FAIL
