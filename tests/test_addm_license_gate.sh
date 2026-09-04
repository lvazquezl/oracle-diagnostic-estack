#!/usr/bin/env bash
# Valida que skills/performance/addm-analysis declare license_requirements: [Diagnostics Pack]
# y que nunca clasifique un finding ADDM como CONFIRMED_ROOT_CAUSE (sólo EVIDENCE_SOURCE).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

M="$ROOT/skills/performance/addm-analysis/manifest.yaml"
if [ ! -f "$M" ] || ! grep -q 'license_requirements: \[Diagnostics Pack\]' "$M"; then
  echo "[FAIL] skills/performance/addm-analysis/manifest.yaml no declara license_requirements: [Diagnostics Pack]"
  FAIL=1
else
  echo "[PASS] skills/performance/addm-analysis/manifest.yaml declara Diagnostics Pack"
fi

S="$ROOT/skills/performance/addm-analysis/SKILL.md"
if grep -Eq 'confidence: .*CONFIRMED_ROOT_CAUSE|classification: CONFIRMED_ROOT_CAUSE' "$S"; then
  echo "[FAIL] skills/performance/addm-analysis/SKILL.md asigna CONFIRMED_ROOT_CAUSE como estado alcanzable — ADDM nunca debe alcanzar ese estado"
  FAIL=1
else
  echo "[PASS] skills/performance/addm-analysis/SKILL.md nunca asigna CONFIRMED_ROOT_CAUSE como estado"
fi
if ! grep -q 'EVIDENCE_SOURCE' "$S"; then
  echo "[FAIL] skills/performance/addm-analysis/SKILL.md no clasifica sus findings como EVIDENCE_SOURCE"
  FAIL=1
else
  echo "[PASS] skills/performance/addm-analysis/SKILL.md clasifica correctamente como EVIDENCE_SOURCE, nunca CONFIRMED_ROOT_CAUSE"
fi

exit $FAIL
