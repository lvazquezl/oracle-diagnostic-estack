#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 71/45.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/compliance-mapping/SKILL.md"
SCHEMA="$ROOT/agents/oracle-security-analyst/output-schema.yaml"

grep -q "INSUFFICIENT_EVIDENCE" "$S" && echo "[PASS] declara INSUFFICIENT_EVIDENCE" || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE"; FAIL=1; }
grep -A2 "status: PASS|FAIL|PARTIAL" "$SCHEMA" | grep -q "INSUFFICIENT_EVIDENCE" \
  && echo "[PASS] output-schema incluye INSUFFICIENT_EVIDENCE en el enum de status" \
  || { echo "[FAIL] falta INSUFFICIENT_EVIDENCE en el schema"; FAIL=1; }

exit $FAIL
