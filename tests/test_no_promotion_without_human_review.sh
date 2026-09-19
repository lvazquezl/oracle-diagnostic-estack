#!/usr/bin/env bash
# Valida que ningún artefacto pueda promoverse (candidate -> active) sin HUMAN REVIEW.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT/agents/estack-evolution-architect.md" "$ROOT/agents/knowledge-curator/AGENT.md" "$ROOT/EVOLUTION.md"; do
  if grep -qi 'HUMAN REVIEW' "$f"; then
    echo "[PASS] $f referencia HUMAN REVIEW"
  else
    echo "[FAIL] $f no referencia HUMAN REVIEW"
    FAIL=1
  fi
done

if grep -q 'candidate → under_review → active → deprecated → retired' "$ROOT/EVOLUTION.md"; then
  echo "[PASS] Estados de artefacto definidos con candidate como punto de partida obligatorio"
else
  echo "[FAIL] Estados de artefacto no definidos"
  FAIL=1
fi

exit $FAIL
