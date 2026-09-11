#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/29.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/multitenant-awareness/SKILL.md"

grep -q 'pdb_datafile_coverage' "$S" && echo "[PASS] declara pdb_datafile_coverage" || { echo "[FAIL] falta pdb_datafile_coverage"; FAIL=1; }
grep -qi 'nunca trata una PDB como base de datos física independiente' "$S" && echo "[PASS] documenta la prohibición (# 29)" || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }
grep -qi 'PARTIALLY_SUPPORTED' "$S" && echo "[PASS] degrada a PARTIALLY_SUPPORTED sin certeza completa" || { echo "[FAIL] falta la degradación PARTIALLY_SUPPORTED"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB backup scope certificado"
exit $FAIL
