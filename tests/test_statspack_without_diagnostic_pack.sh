#!/usr/bin/env bash
# Valida que Q-PERF-WAIT-STATSPACK-001/performance/statspack-analysis declaren
# license_requirements: none — Statspack es la ruta explícita sin Diagnostics Pack.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

F="$ROOT/queries/performance/waits/Q-PERF-WAIT-STATSPACK-001.md"
grep -q 'license_requirements: none' "$F" && echo "[PASS] Q-PERF-WAIT-STATSPACK-001 sin licencia" || { echo "[FAIL] Q-PERF-WAIT-STATSPACK-001 declara licencia"; FAIL=1; }

M="$ROOT/skills/performance/statspack-analysis/manifest.yaml"
grep -q 'license_requirements: none' "$M" && echo "[PASS] performance/statspack-analysis sin licencia" || { echo "[FAIL] performance/statspack-analysis declara licencia"; FAIL=1; }

S="$ROOT/skills/performance/statspack-analysis/SKILL.md"
grep -qi 'primera clase' "$S" && echo "[PASS] statspack-analysis documentado como ruta de primera clase" || { echo "[FAIL] falta la declaración de 'primera clase'"; FAIL=1; }

exit $FAIL
