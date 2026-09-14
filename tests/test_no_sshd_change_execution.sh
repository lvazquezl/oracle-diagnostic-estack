#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/ssh-sshd-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Nunca edita .sshd_config' "$S" && echo "[PASS] prohíbe editar sshd_config" || { echo "[FAIL] falta la prohibición de editar sshd_config"; FAIL=1; }
grep -qi 'nunca reinicia .sshd' "$S" && echo "[PASS] prohíbe reiniciar sshd" || { echo "[FAIL] falta la prohibición de reiniciar sshd"; FAIL=1; }
exit $FAIL
