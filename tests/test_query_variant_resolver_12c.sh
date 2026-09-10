#!/usr/bin/env bash
# Valida que el Query Variant Resolver encuentre una variante compatible para Oracle 12c
# (representado como 12.1) en cada logical query que declara cobertura para esa version, y que NO
# encuentre match para los que legitimamente no la cubren (docs/QUERY_VARIANTS.md,
# config/capability-matrix.yaml).
#
# PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION (# 5-6, # 11 del prompt): usa
# scripts/lib/version.sh (única implementación de comparación autorizada) en vez de un vernum()
# local.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/version.sh"
FAIL=0
TARGET="12.1"
# Q-CDB-PDB-SAVED-STATE-001 requiere patch level real 12.1.0.2 (PDB Saved State no existe en
# 12.1.0.0/12.1.0.1) — el alias de marketing "12c" representa el piso 12.1.0.0.0, por debajo de
# ese mínimo real. Con el comparador 2-tier anterior (vernum, ignoraba patch level) esto pasaba
# desapercibido -- descubierto al migrar a scripts/lib/version.sh (patch-level-aware), PHASE 6 —
# VERSION RESOLVER CONSOLIDATION FINALIZATION. Comportamiento nuevo correcto, no una regresión.
EXPECTED_UNSUPPORTED="Q-CDB-PDB-SAVED-STATE-001"

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
    echo "[PASS] $qid — el Resolver encuentra una variante compatible para 12c"
  elif [ "$match" -eq 0 ] && [ "$is_expected_unsupported" -eq 1 ]; then
    echo "[PASS] $qid — sin variante para 12c, esperado (capability UNSUPPORTED/PARTIALLY_SUPPORTED documentado)"
  else
    echo "[FAIL] $qid — match=$match, esperado unsupported=$is_expected_unsupported (inconsistente con config/capability-matrix.yaml)"
    FAIL=1
  fi
done

exit $FAIL
