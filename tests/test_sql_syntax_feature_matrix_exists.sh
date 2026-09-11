#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FEATURES="$ROOT/compatibility/oracle-sql-syntax/features.yaml"

[ -f "$FEATURES" ] || { echo "[FAIL] $FEATURES no existe"; exit 1; }
echo "[PASS] compatibility/oracle-sql-syntax/features.yaml existe"

for fid in FETCH_FIRST OFFSET_ROWS; do
  grep -q "^  ${fid}:" "$FEATURES" && echo "[PASS] declara feature $fid" || { echo "[FAIL] falta feature $fid"; FAIL=1; }
done

grep -q 'min_version: "12.1"' "$FEATURES" && echo "[PASS] declara min_version explícito (no latest)" || { echo "[FAIL] falta min_version explícito"; FAIL=1; }
# "latest" sólo puede aparecer en prosa explicando la prohibición (ej. "nunca 'latest'") — nunca
# como valor real de min_version/max_certified_version. Mismo patrón de ventana de contexto que
# tests/test_no_create_pdb.sh (Fase 6).
latest_bad=0
while IFS=: read -r lineno _; do
  [ -z "$lineno" ] && continue
  window=$(sed -n "${lineno}p" "$FEATURES")
  if ! echo "$window" | grep -qiE 'nunca|never|prohibid|no marcar'; then
    echo "[FAIL] $FEATURES:$lineno menciona 'latest' sin contexto de prohibición"
    latest_bad=1
  fi
done < <(grep -niE '\blatest\b' "$FEATURES")
[ "$latest_bad" -eq 0 ] && echo "[PASS] 'latest' nunca aparece como valor real, sólo en prosa de prohibición" || FAIL=1

for field in feature_id syntax_patterns min_version validation; do
  grep -q "$field" "$FEATURES" && echo "[PASS] declara campo $field" || { echo "[FAIL] falta campo $field"; FAIL=1; }
done

grep -q 'compatibility/oracle-dictionary' "$FEATURES" | true
grep -qi 'nunca se mezcla\|separación deliberada\|no se mezcla' "$ROOT/docs/ORACLE_SQL_SYNTAX_COMPATIBILITY_MODEL.md" && echo "[PASS] documentado como separado del dictionary de vistas/columnas" || { echo "[FAIL] falta la separación documentada del dictionary"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] SQL Syntax Feature Compatibility Model completo"
exit $FAIL
