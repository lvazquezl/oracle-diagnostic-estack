#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 44/18.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-process-limits-insufficient-privileges.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'nunca se usa .sudo./.su./.runuser./escalamiento' "$S" && echo "[PASS] prohíbe sudo/su/runuser/escalamiento" || { echo "[FAIL] falta la prohibición"; FAIL=1; }
grep -q 'sudo_attempted: false' "$FX" && echo "[PASS] fixture declara sudo_attempted: false" || { echo "[FAIL] falta sudo_attempted en la fixture"; FAIL=1; }
exit $FAIL
