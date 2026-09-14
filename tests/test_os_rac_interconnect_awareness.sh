#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 73.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/rac-interconnect-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca duplica' "$S" && grep -q 'evidence_refs' "$S" \
  && echo "[PASS] consolida por evidence_refs sin duplicar evidencia cruda" || { echo "[FAIL] falta la regla de no-duplicación"; FAIL=1; }
grep -q 'interconnect_os_status' "$S" && echo "[PASS] declara interconnect_os_status en el output" || { echo "[FAIL] falta interconnect_os_status"; FAIL=1; }
exit $FAIL
