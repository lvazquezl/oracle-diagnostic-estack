#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/rac-awareness/SKILL.md"

grep -qi 'nunca asume que todos los nodos\|nunca se asume que todos los nodos' "$S" && echo "[PASS] rman/rac-awareness documenta que nunca asume participación de todos los nodos" || { echo "[FAIL] falta la prohibición (# 22)"; FAIL=1; }
grep -q '^supported_architectures: \[rac, rac_one_node\]' "$ROOT/skills/rman/rac-awareness/manifest.yaml" && echo "[PASS] manifest restringido a RAC/RAC One Node" || { echo "[FAIL] manifest no restringido a arquitecturas RAC"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] RMAN RAC channel awareness certificado"
exit $FAIL
