#!/usr/bin/env bash
# Valida que el Query Variant Resolver encuentre una variante compatible para Oracle 23ai
# (representado como 23.0) en cada logical query que declara cobertura para esa version, y que NO
# encuentre match para los que legitimamente no la cubren (docs/QUERY_VARIANTS.md,
# config/capability-matrix.yaml).
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 5-6, # 11 del prompt): usa
# scripts/lib/version.sh en vez de un vernum() local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="23.0"
EXPECTED_UNSUPPORTED="Q-DICT-VERIFY-001 Q-DICT-VERIFY-002 Q-DICT-VERIFY-003 Q-DICT-VERIFY-004 Q-DICT-VERIFY-005"
# CHG-ESTACK-ORA19C-LAB-006: Q-DICT-VERIFY-00N se generan desde views.yaml SÓLO para 19c (la lista embebida
# depende de la versión); otra versión requiere su propia variante generada (CHG-REQ-LAB-MULTIVERSION).

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
    echo "[PASS] $qid — el Resolver encuentra una variante compatible para 23ai"
  elif [ "$match" -eq 0 ] && [ "$is_expected_unsupported" -eq 1 ]; then
    echo "[PASS] $qid — sin variante para 23ai, esperado (capability UNSUPPORTED/PARTIALLY_SUPPORTED documentado)"
  else
    echo "[FAIL] $qid — match=$match, esperado unsupported=$is_expected_unsupported (inconsistente con config/capability-matrix.yaml)"
    FAIL=1
  fi
done

exit $FAIL
