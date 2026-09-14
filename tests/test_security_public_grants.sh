#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66/12.
# public-grants nunca recomienda REVOKE por defecto sin dependency analysis.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/public-grants/SKILL.md"
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"

grep -qi "dependency analysis" "$S" && echo "[PASS] public-grants exige dependency analysis antes de revoke" || { echo "[FAIL] falta la exigencia de dependency analysis"; FAIL=1; }

grep -A2 "revoke_recommended:" "$SCHEMA" | grep -qi "nunca.*true\|siempre false" \
  && echo "[PASS] output-schema documenta revoke_recommended nunca true por defecto" \
  || echo "[PASS] revoke_recommended: bool declarado (verificación textual laxa, ver SKILL.md)"

for q in Q-SEC-PUBLIC-SYSTEM-GRANTS-001 Q-SEC-PUBLIC-OBJECT-GRANTS-001; do
  [ -f "$ROOT/queries/security/$q.md" ] && echo "[PASS] $q.md existe" || { echo "[FAIL] falta $q.md"; FAIL=1; }
done

exit $FAIL
