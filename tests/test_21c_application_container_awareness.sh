#!/usr/bin/env bash
# PHASE 6 — ORACLE MULTITENANT / CDB / PDB, sección 58.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/21c-application-container.yaml"
SKILL="$ROOT/skills/multitenant/application-containers/SKILL.md"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 21c-application-container.yaml"; exit 1; }
grep -q "major: 21" "$FX" && echo "[PASS] fixture declara oracle_version.major=21" || { echo "[FAIL] fixture no declara 21"; FAIL=1; }
grep -q "application_root: \"YES\"" "$FX" && echo "[PASS] fixture declara un application_root" || { echo "[FAIL] fixture no declara application_root"; FAIL=1; }
grep -qi "PARTIALLY_SUPPORTED" "$SKILL" && echo "[PASS] skill declara PARTIALLY_SUPPORTED cuando el detalle no está certificado" || { echo "[FAIL] falta la declaración PARTIALLY_SUPPORTED"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Application Containers correctamente reconocidos desde 21c (topología, sin lifecycle)"

exit $FAIL
