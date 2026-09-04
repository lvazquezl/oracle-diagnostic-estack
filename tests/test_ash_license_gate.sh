#!/usr/bin/env bash
# Valida que Q-PERF-WAIT-ASH-001 y skills/performance/ash-analysis declaren
# license_requirements: [Diagnostics Pack] sin excepción — ASH nunca tiene fallback de igual
# granularidad sin licencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

F="$ROOT/queries/performance/waits/Q-PERF-WAIT-ASH-001.md"
if [ ! -f "$F" ] || ! grep -q 'license_requirements: \[Diagnostics Pack\]' "$F"; then
  echo "[FAIL] Q-PERF-WAIT-ASH-001.md no declara license_requirements: [Diagnostics Pack]"
  FAIL=1
else
  echo "[PASS] Q-PERF-WAIT-ASH-001.md declara Diagnostics Pack"
fi

M="$ROOT/skills/performance/ash-analysis/manifest.yaml"
if [ ! -f "$M" ] || ! grep -q 'license_requirements: \[Diagnostics Pack\]' "$M"; then
  echo "[FAIL] skills/performance/ash-analysis/manifest.yaml no declara license_requirements: [Diagnostics Pack]"
  FAIL=1
else
  echo "[PASS] skills/performance/ash-analysis/manifest.yaml declara Diagnostics Pack"
fi

exit $FAIL
