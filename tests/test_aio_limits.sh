#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/aio/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'aio-max-nr' "$S" && echo "[PASS] declara aio-max-nr" || { echo "[FAIL] falta aio-max-nr"; FAIL=1; }
grep -qi '> 95%.*HIGH\|>95%.*HIGH\|`HIGH`.*> 95%' "$S" && echo "[PASS] declara umbral HIGH sobre 95%" || { echo "[FAIL] falta el umbral HIGH"; FAIL=1; }
exit $FAIL
