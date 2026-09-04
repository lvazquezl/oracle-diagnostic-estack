#!/usr/bin/env bash
# rac/service-placement distingue configured vs. current instances.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/service-placement/SKILL.md"

grep -q 'preferred_instances' "$S" && grep -q 'current_instances' "$S" && echo "[PASS] distingue preferred/available/current instances" || { echo "[FAIL] falta el modelo de placement"; FAIL=1; }
grep -qi 'no relocaliza el servicio' "$S" && echo "[PASS] prohibición explícita de relocate" || { echo "[FAIL] falta prohibición"; FAIL=1; }

exit $FAIL
