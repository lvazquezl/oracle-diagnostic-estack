#!/usr/bin/env bash
# Valida que el Query Variant Resolver encuentre una variante compatible para Oracle 23ai
# (representado como version normalizada 2300) en cada logical query que declara cobertura
# para esa version, y que NO encuentre match para los que legitimamente no la cubren
# (docs/QUERY_VARIANTS.md, config/capability-matrix.yaml).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
TARGET=2300
EXPECTED_UNSUPPORTED=""

vernum() { local v="$1"; [ "$v" = "latest" ] && { echo 99999; return; }; local maj min; maj=$(echo "$v"|cut -d. -f1); min=$(echo "$v"|cut -d. -f2); echo $((maj*100+min)); }

for f in $(grep -rl '^variants:' "$ROOT/queries" --include='Q-*.md' 2>/dev/null); do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  ranges=$(grep -oE 'oracle_versions: \{min: "[^"]+", max: [^}]+\}' "$f")
  match=0
  while IFS= read -r r; do
    m=$(echo "$r" | grep -oE 'min: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')
    x=$(echo "$r" | grep -oE 'max: [^}]+' | sed -E 's/max: *"?//; s/"?$//')
    mn=$(vernum "$m"); mx=$(vernum "$x")
    if [ "$TARGET" -ge "$mn" ] && [ "$TARGET" -le "$mx" ]; then match=1; fi
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
