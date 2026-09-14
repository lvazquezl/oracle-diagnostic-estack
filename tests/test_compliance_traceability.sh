#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 71/47.
# Trazabilidad EVD -> FND -> REC -> CHG mantenida en cada control.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/compliance-mapping/SKILL.md"

grep -q "EVD.*FND.*REC.*CHG\|EVD → FND → REC → CHG" "$S" \
  && echo "[PASS] declara la trazabilidad EVD -> FND -> REC -> CHG" \
  || { echo "[FAIL] falta la trazabilidad"; FAIL=1; }
grep -q "remediation_ref" "$S" && echo "[PASS] control incluye remediation_ref" || { echo "[FAIL] falta remediation_ref"; FAIL=1; }
grep -q "evidence_ids" "$S" && echo "[PASS] control incluye evidence_ids" || { echo "[FAIL] falta evidence_ids"; FAIL=1; }

exit $FAIL
