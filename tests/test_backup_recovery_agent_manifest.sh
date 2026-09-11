#!/usr/bin/env bash
# Valida que agents/oracle-backup-recovery-analyst/manifest.yaml declara todos los campos
# requeridos y los 30 allowed_skills.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

for field in id version domain status mission supported_versions supported_architectures \
             allowed_skills forbidden_capabilities required_gates input_contract \
             output_contract security_mode evidence_policy evolution_policy; do
  grep -qE "^${field}:" "$M" && echo "[PASS] manifest.yaml declara $field" || { echo "[FAIL] manifest.yaml no declara $field"; FAIL=1; }
done

COUNT=$(awk '/^allowed_skills:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$M" | grep -c '^\s*-\s*rman/')
[ "$COUNT" -eq 30 ] && echo "[PASS] allowed_skills tiene exactamente 30 entradas rman/*" || { echo "[FAIL] allowed_skills tiene $COUNT entradas (esperado 30)"; FAIL=1; }

exit $FAIL
