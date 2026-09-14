#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING. Valida que
# agents/os-platform-analyst/manifest.yaml declara todos los campos requeridos y los 45
# allowed_skills.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/os-platform-analyst/manifest.yaml"

for field in id version domain status mission supported_platforms supported_architectures \
             allowed_skills forbidden_capabilities required_gates input_contract \
             output_contract security_mode evidence_policy evolution_policy; do
  grep -qE "^${field}:" "$M" && echo "[PASS] manifest.yaml declara $field" || { echo "[FAIL] manifest.yaml no declara $field"; FAIL=1; }
done

COUNT=$(awk '/^allowed_skills:/{f=1;next} /^[a-zA-Z_]+:/{f=0} f' "$M" | grep -c '^\s*-\s*os/')
[ "$COUNT" -eq 45 ] && echo "[PASS] allowed_skills tiene exactamente 45 entradas os/*" || { echo "[FAIL] allowed_skills tiene $COUNT entradas (esperado 45)"; FAIL=1; }

[ -f "$ROOT/agents/os-platform-analyst.md" ] && { echo "[FAIL] el flat file superado agents/os-platform-analyst.md todavía existe"; FAIL=1; } || echo "[PASS] el flat file superado fue eliminado"

exit $FAIL
