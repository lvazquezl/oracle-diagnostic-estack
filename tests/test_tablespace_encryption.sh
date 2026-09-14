#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 69/33.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/tablespace-encryption/SKILL.md"

for st in ENCRYPTED UNENCRYPTED UNKNOWN NOT_APPLICABLE; do
  grep -q "$st" "$S" && echo "[PASS] declara estado $st" || { echo "[FAIL] falta $st"; FAIL=1; }
done
tr '\n' ' ' < "$S" | grep -qi "nunca declara[[:space:]]*incumplimiento sin policy target" \
  && echo "[PASS] declara explícitamente que nunca declara incumplimiento sin policy target" \
  || { echo "[FAIL] falta la declaración"; FAIL=1; }

exit $FAIL
