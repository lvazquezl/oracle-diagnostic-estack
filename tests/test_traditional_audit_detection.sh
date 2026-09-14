#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68/28.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/traditional-auditing/SKILL.md"
Q="$ROOT/queries/security/Q-SEC-TRADITIONAL-AUDIT-001.md"

grep -qi "nunca asume Unified Auditing en 10g/11g" "$S" \
  && echo "[PASS] declara explícitamente que nunca asume Unified Auditing en 10g/11g" \
  || { echo "[FAIL] falta la declaración"; FAIL=1; }

for v in V1 V2; do
  grep -q "variant_id: Q-SEC-TRADITIONAL-AUDIT-001-$v" "$Q" && echo "[PASS] declara variante $v" || { echo "[FAIL] falta variante $v"; FAIL=1; }
done

exit $FAIL
