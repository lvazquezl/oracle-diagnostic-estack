#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44/45/27.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/pdb-pitr-awareness/SKILL.md"
M="$ROOT/skills/rman/pdb-pitr-awareness/manifest.yaml"

[ -f "$S" ] || { echo "[FAIL] $S no existe"; exit 1; }
grep -qi 'local undo' "$S" && echo "[PASS] correlaciona local undo" || { echo "[FAIL] falta correlación con local undo"; FAIL=1; }
grep -qi 'oracle-multitenant-analyst' "$S" && echo "[PASS] delega a oracle-multitenant-analyst" || { echo "[FAIL] falta la delegación a oracle-multitenant-analyst"; FAIL=1; }
grep -qi 'nunca trata.*base física independiente\|nunca.*independiente' "$S" && echo "[PASS] documenta que nunca trata la PDB como DB física independiente" || { echo "[FAIL] falta la prohibición (# 29)"; FAIL=1; }
grep -q '^container_scope: PDB_ONLY' "$M" && echo "[PASS] manifest declara container_scope PDB_ONLY" || { echo "[FAIL] falta container_scope PDB_ONLY"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] PDB PITR awareness certificado"
exit $FAIL
