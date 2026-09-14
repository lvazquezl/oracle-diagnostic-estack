#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 36/15.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -q 'get_unit_cgroup_path' "$S" && echo "[PASS] declara el collector get_unit_cgroup_path" || { echo "[FAIL] falta get_unit_cgroup_path en os/process-limits"; FAIL=1; }
grep -q '`get_unit_cgroup_path`' "$D" && echo "[PASS] catálogo declara get_unit_cgroup_path" || { echo "[FAIL] falta get_unit_cgroup_path en el catálogo"; FAIL=1; }
grep -qi 'nunca adivinado por convención de nombre' "$D" && echo "[PASS] prohíbe adivinar el path por nombre del servicio" || { echo "[FAIL] falta la prohibición de adivinar"; FAIL=1; }
exit $FAIL
