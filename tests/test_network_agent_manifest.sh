#!/usr/bin/env bash
# Valida que agents/oracle-network-analyst/manifest.yaml declara todos los campos requeridos
# y los 15 allowed_skills (14 de Fase 4 + network/oracle-net-security agregada por PHASE 8 —
# SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/oracle-network-analyst/manifest.yaml"

for field in id version domain status mission supported_versions supported_architectures \
             allowed_skills forbidden_capabilities required_gates input_contract \
             output_contract security_mode evidence_policy evolution_policy; do
  grep -qE "^${field}:" "$M" && echo "[PASS] manifest.yaml declara $field" || { echo "[FAIL] manifest.yaml no declara $field"; FAIL=1; }
done

COUNT=$(awk '/^allowed_skills:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$M" | grep -c '^\s*-\s*network/')
[ "$COUNT" -eq 15 ] && echo "[PASS] allowed_skills tiene exactamente 15 entradas network/*" || { echo "[FAIL] allowed_skills tiene $COUNT entradas (esperado 15)"; FAIL=1; }

exit $FAIL
