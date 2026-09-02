#!/usr/bin/env bash
# Valida que /change implemente el flujo completo de 12 pasos, en orden, sin saltos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/EVOLUTION.md"

STEPS=(DETECT "CHANGE REQUEST" "GAP ANALYSIS" "IMPACT ANALYSIS" PROPOSAL IMPLEMENT TEST "SECURITY VALIDATION" "REGRESSION VALIDATION" DOCUMENT "HUMAN REVIEW" PROMOTE)

last_line=0
ok=1
for step in "${STEPS[@]}"; do
  line=$(grep -n "$step" "$F" | head -1 | cut -d: -f1)
  if [ -z "$line" ]; then
    echo "[FAIL] EVOLUTION.md no contiene el paso '$step'"
    ok=0
    FAIL=1
    continue
  fi
  if [ "$line" -lt "$last_line" ]; then
    echo "[FAIL] Paso '$step' aparece fuera de orden"
    ok=0
    FAIL=1
  fi
  last_line=$line
done
[ $ok -eq 1 ] && echo "[PASS] Los 12 pasos de /change están presentes y en orden"

if grep -q 'HUMAN REVIEW' "$F" && grep -Eq 'no promueve|obligatoria para cualquier promoción|Ningún paso se puede saltar' "$F"; then
  echo "[PASS] EVOLUTION.md exige HUMAN REVIEW sin excepción"
else
  echo "[FAIL] EVOLUTION.md no exige HUMAN REVIEW explícitamente sin excepción"
  FAIL=1
fi

exit $FAIL
