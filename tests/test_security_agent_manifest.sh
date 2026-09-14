#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 2.
# Valida que agents/oracle-security-analyst/manifest.yaml declara todos los campos requeridos y
# los 39 allowed_skills.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/oracle-security-analyst/manifest.yaml"

for field in id version domain status mission supported_versions supported_architectures \
             allowed_skills forbidden_capabilities required_gates input_contract \
             output_contract security_mode evidence_policy evolution_policy; do
  grep -qE "^${field}:" "$M" && echo "[PASS] manifest.yaml declara $field" || { echo "[FAIL] manifest.yaml no declara $field"; FAIL=1; }
done

COUNT=$(awk '/^allowed_skills:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$M" | grep -c '^\s*-\s*security/')
[ "$COUNT" -eq 39 ] && echo "[PASS] allowed_skills tiene exactamente 39 entradas security/*" || { echo "[FAIL] allowed_skills tiene $COUNT entradas (esperado 39)"; FAIL=1; }

grep -q "security_mode: READ_ONLY_ALWAYS" "$M" && echo "[PASS] security_mode: READ_ONLY_ALWAYS" || { echo "[FAIL] falta security_mode: READ_ONLY_ALWAYS"; FAIL=1; }

exit $FAIL
