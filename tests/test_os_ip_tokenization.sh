#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 75.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

S1="$ROOT/skills/os/network-interfaces/SKILL.md"
[ -f "$S1" ] || { echo "[FAIL] falta $S1"; FAIL=1; }
grep -qi 'TOKENIZE por defecto' "$S1" && echo "[PASS] os/network-interfaces tokeniza direcciones IP/MAC por defecto" || { echo "[FAIL] os/network-interfaces no declara TOKENIZE"; FAIL=1; }

S2="$ROOT/skills/os/routing/SKILL.md"
[ -f "$S2" ] || { echo "[FAIL] falta $S2"; FAIL=1; }
grep -qi 'TOKENIZE' "$S2" && echo "[PASS] os/routing tokeniza gateways/destinos" || { echo "[FAIL] os/routing no declara TOKENIZE"; FAIL=1; }
exit $FAIL
