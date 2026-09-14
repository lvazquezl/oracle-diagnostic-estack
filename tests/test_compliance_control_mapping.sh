#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 71/44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/compliance-mapping/SKILL.md"
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"

for f in framework control_id requirement status evidence_ids rationale scope version confidence remediation_ref; do
  grep -q "$f" "$S" && echo "[PASS] control declara campo $f" || { echo "[FAIL] falta el campo $f"; FAIL=1; }
done
grep -q "compliance_mapping:" "$SCHEMA" && echo "[PASS] output-schema declara compliance_mapping" || { echo "[FAIL] falta compliance_mapping en el schema"; FAIL=1; }
grep -qi "nunca copia benchmarks propietarios" "$S" && echo "[PASS] declara nunca copiar benchmarks propietarios" || { echo "[FAIL] falta la declaración"; FAIL=1; }

exit $FAIL
