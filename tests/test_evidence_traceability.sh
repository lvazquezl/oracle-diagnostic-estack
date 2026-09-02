#!/usr/bin/env bash
# Valida que el modelo EVD->FND->REC->CHG esté definido y que la plantilla de análisis lo soporte.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -q 'EVIDENCE (EVD-) → FINDING (FND-) → RECOMMENDATION (REC-) → CHANGE PROPOSAL (CHG-)' "$ROOT/docs/CONTRACTS.md"; then
  echo "[PASS] docs/CONTRACTS.md define la cadena de trazabilidad EVD->FND->REC->CHG"
else
  echo "[FAIL] docs/CONTRACTS.md no define la cadena de trazabilidad completa"
  FAIL=1
fi

for f in evidence-manifest.json findings.md recommendations.md proposed-changes.md evidence.md; do
  if [ -f "$ROOT/analysis/_TEMPLATE/$f" ]; then
    echo "[PASS] analysis/_TEMPLATE/$f presente"
  else
    echo "[FAIL] analysis/_TEMPLATE/$f ausente"
    FAIL=1
  fi
done

exit $FAIL
