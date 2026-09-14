#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 37/22/555.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/skills/os/cgroups/SKILL.md"
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca se deduplican dos nodos' "$C" && echo "[PASS] os/cgroups prohíbe deduplicar nodos por valor numérico" || { echo "[FAIL] falta la prohibición en os/cgroups"; FAIL=1; }
grep -qi 'similitud numérica' "$S" && echo "[PASS] os/process-limits prohíbe deduplicar por similitud numérica" || { echo "[FAIL] falta la prohibición en os/process-limits"; FAIL=1; }
exit $FAIL
