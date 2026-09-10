#!/usr/bin/env bash
# Valida que el Query Variant Resolver encuentre una variante compatible para Oracle 10g
# en cada logical query que declara cobertura para esa version, y que NO encuentre match para los
# que legitimamente no la cubren (docs/QUERY_VARIANTS.md, config/capability-matrix.yaml).
#
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING (# 21, # 24 del prompt): usa
# scripts/lib/version.sh (compartida con tests/test_sql_static_validator.sh y los tests de
# saved-state) en vez de un vernum() local — evita el anti-patrón "tests PASS, resolver capability
# missing" nombrado explícitamente en ese prompt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="10.2"
EXPECTED_UNSUPPORTED="Q-DISC-RAC-001 Q-DISC-ASM-001 Q-RAC-TOPOLOGY-001 Q-RAC-SERVICES-001 Q-CDB-PDB-STATE-001 Q-CDB-PDB-SAVED-STATE-001 Q-CDB-PLUGIN-VIOLATIONS-001"

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$f")
  match=0
  while IFS= read -r r; do
    m=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    x=$(echo "$r" | grep -oE 'max: [^}]+' | sed -E 's/max: *"?//; s/"?$//')
    if version_in_range "$TARGET" "$m" "$x"; then match=1; fi
  done <<< "$ranges"

  is_expected_unsupported=0
  for u in $EXPECTED_UNSUPPORTED; do [ "$u" = "$qid" ] && is_expected_unsupported=1; done

  if [ "$match" -eq 1 ] && [ "$is_expected_unsupported" -eq 0 ]; then
    echo "[PASS] $qid — el Resolver encuentra una variante compatible para 10g"
  elif [ "$match" -eq 0 ] && [ "$is_expected_unsupported" -eq 1 ]; then
    echo "[PASS] $qid — sin variante para 10g, esperado (capability UNSUPPORTED/PARTIALLY_SUPPORTED documentado)"
  else
    echo "[FAIL] $qid — match=$match, esperado unsupported=$is_expected_unsupported (inconsistente con config/capability-matrix.yaml)"
    FAIL=1
  fi
done

exit $FAIL
