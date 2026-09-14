#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in skills/security/password-profiles/SKILL.md skills/security/password-profiles/manifest.yaml queries/security/Q-SEC-PASSWORD-PROFILES-001.md; do
  [ -f "$ROOT/$f" ] && echo "[PASS] $f existe" || { echo "[FAIL] falta $f"; FAIL=1; }
done

exit $FAIL
