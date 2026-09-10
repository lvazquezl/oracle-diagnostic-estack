#!/usr/bin/env bash
# Valida que agents/oracle-multitenant-analyst/manifest.yaml declara todos los campos requeridos
# y los 26 allowed_skills.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/oracle-multitenant-analyst/manifest.yaml"

for field in id version domain status mission supported_versions supported_architectures \
             allowed_skills forbidden_capabilities required_gates input_contract \
             output_contract security_mode evidence_policy evolution_policy; do
  grep -qE "^${field}:" "$M" && echo "[PASS] manifest.yaml declara $field" || { echo "[FAIL] manifest.yaml no declara $field"; FAIL=1; }
done

COUNT=$(awk '/^allowed_skills:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$M" | grep -c '^\s*-\s*multitenant/')
[ "$COUNT" -eq 26 ] && echo "[PASS] allowed_skills tiene exactamente 26 entradas multitenant/*" || { echo "[FAIL] allowed_skills tiene $COUNT entradas (esperado 26)"; FAIL=1; }

exit $FAIL
