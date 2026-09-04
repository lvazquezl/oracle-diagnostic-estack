#!/usr/bin/env bash
# Valida que agents/oracle-performance-analyst/manifest.yaml declare todos los campos
# requeridos (# 27 PERFORMANCE AGENT MANIFEST).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/oracle-performance-analyst/manifest.yaml"

[ -f "$M" ] || { echo "[FAIL] falta manifest.yaml"; exit 1; }

for field in "^id:" "^version:" "^domain:" "^mission:" "^supported_versions:" "^supported_architectures:" "^allowed_skills:" "^forbidden_capabilities:" "^required_gates:" "^input_contract:" "^output_contract:" "^security_mode:" "^evidence_policy:" "^evolution_policy:"; do
  if grep -q "$field" "$M"; then
    echo "[PASS] manifest.yaml declara $field"
  else
    echo "[FAIL] manifest.yaml no declara $field"
    FAIL=1
  fi
done

# 31 skills listados
count=$(grep -c '^  - performance/' "$M")
if [ "$count" -eq 31 ]; then
  echo "[PASS] manifest.yaml declara exactamente 31 allowed_skills"
else
  echo "[FAIL] manifest.yaml declara $count allowed_skills, se esperaban 31"
  FAIL=1
fi

exit $FAIL
