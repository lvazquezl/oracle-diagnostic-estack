#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 70/43.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/licensing-gates/SKILL.md"
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"

for st in INCLUDED SEPARATELY_LICENSED LICENSE_RESTRICTED UNKNOWN REQUIRES_REVIEW; do
  grep -q "$st" "$S" && echo "[PASS] declara estado $st" || { echo "[FAIL] falta $st"; FAIL=1; }
done
grep -q "REQUIRES_REVIEW\|LICENSE_RESTRICTED" "$SCHEMA" \
  && echo "[PASS] output-schema propaga los estados de licensing" \
  || { echo "[FAIL] falta la propagación en el schema"; FAIL=1; }

exit $FAIL
