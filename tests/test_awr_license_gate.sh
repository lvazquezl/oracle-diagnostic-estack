#!/usr/bin/env bash
# Valida que toda query AWR (DBA_HIST_*) certificada declare license_requirements: [Diagnostics Pack].
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(grep -rl '^objects_accessed:.*DBA_HIST_' "$ROOT/queries/performance" --include='Q-*.md' 2>/dev/null); do
  if ! grep -q 'license_requirements: \[Diagnostics Pack\]' "$f"; then
    echo "[FAIL] $f usa DBA_HIST_* pero no declara license_requirements: [Diagnostics Pack]"
    FAIL=1
  else
    echo "[PASS] $f declara Diagnostics Pack correctamente"
  fi
done

if ! grep -q "performance/awr-analysis" "$ROOT/skills/performance/awr-analysis/manifest.yaml" || ! grep -q 'license_requirements: \[Diagnostics Pack\]' "$ROOT/skills/performance/awr-analysis/manifest.yaml"; then
  echo "[FAIL] skills/performance/awr-analysis/manifest.yaml no declara license_requirements: [Diagnostics Pack]"
  FAIL=1
fi

exit $FAIL
