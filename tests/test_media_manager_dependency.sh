#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/24.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/sbt-media-manager/SKILL.md"

grep -qi 'sin credenciales' "$S" && echo "[PASS] rman/sbt-media-manager opera sin credenciales" || { echo "[FAIL] falta 'sin credenciales'"; FAIL=1; }
grep -qi 'Commvault/Simpana' "$S" && echo "[PASS] reconoce Commvault/Simpana como conocimiento de dominio" || { echo "[FAIL] falta el reconocimiento de Commvault/Simpana"; FAIL=1; }
grep -qi 'no como agente nuevo\|nunca como agente' "$S" && echo "[PASS] documenta que no se convierte en agente nuevo" || { echo "[FAIL] falta la prohibición de agente nuevo"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Media manager dependency awareness certificada"
exit $FAIL
