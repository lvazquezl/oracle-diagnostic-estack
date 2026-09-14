#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/ssh-sshd-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Sólo posture awareness' "$S" && echo "[PASS] declara alcance de sólo posture awareness" || { echo "[FAIL] falta la declaración de alcance"; FAIL=1; }
grep -qi 'nunca inspecciona claves privadas' "$S" && echo "[PASS] prohíbe inspeccionar claves privadas" || { echo "[FAIL] falta la prohibición de claves privadas"; FAIL=1; }
exit $FAIL
