#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/transparent-hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca modifica kernel boot args' "$S" && echo "[PASS] prohíbe modificar kernel boot args" || { echo "[FAIL] falta la prohibición de boot args"; FAIL=1; }
grep -qi 'nunca escribe en .\?/sys/kernel/' "$S" && echo "[PASS] prohíbe escribir en /sys/kernel/mm/transparent_hugepage" || { echo "[FAIL] falta la prohibición de escritura sysfs"; FAIL=1; }
grep -qi 'NOT_EXECUTED' "$S" && echo "[PASS] manual_action declarado NOT_EXECUTED" || { echo "[FAIL] falta NOT_EXECUTED"; FAIL=1; }
exit $FAIL
