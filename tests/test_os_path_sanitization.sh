#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 75.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

S1="$ROOT/skills/os/filesystems/SKILL.md"
[ -f "$S1" ] || { echo "[FAIL] falta $S1"; FAIL=1; }
grep -qi 'MASK.\?/.\?TOKENIZE.\? por defecto' "$S1" && echo "[PASS] os/filesystems enmascara/tokeniza mount_point por defecto" || { echo "[FAIL] os/filesystems no declara MASK/TOKENIZE"; FAIL=1; }

S2="$ROOT/skills/os/security-filesystem-awareness/SKILL.md"
[ -f "$S2" ] || { echo "[FAIL] falta $S2"; FAIL=1; }
grep -qi 'TOKENIZE.\? por defecto' "$S2" && echo "[PASS] os/security-filesystem-awareness tokeniza el path del wallet por defecto" || { echo "[FAIL] os/security-filesystem-awareness no declara TOKENIZE"; FAIL=1; }
exit $FAIL
