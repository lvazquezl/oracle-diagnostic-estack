#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/oracle-groups/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'asmadmin' "$S" && grep -q 'backupdba' "$S" && echo "[PASS] declara los grupos ASM/SYSBACKUP relevantes" || { echo "[FAIL] faltan los grupos relevantes"; FAIL=1; }
grep -qi 'grupos no existen en ese modelo' "$S" && echo "[PASS] declara que la ausencia pre-12.1 no es un hallazgo" || { echo "[FAIL] falta la regla de no-hallazgo pre-12.1"; FAIL=1; }
exit $FAIL
