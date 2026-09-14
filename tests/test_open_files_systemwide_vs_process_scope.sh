#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 45/19.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/open-files/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Distingue explícitamente 5 conceptos que' "$S" && echo "[PASS] distingue explícitamente los 5 conceptos" || { echo "[FAIL] falta la distinción de 5 conceptos"; FAIL=1; }
grep -q 'systemd_limit_nofile' "$S" && echo "[PASS] declara systemd_limit_nofile por separado" || { echo "[FAIL] falta systemd_limit_nofile"; FAIL=1; }
exit $FAIL
