#!/usr/bin/env bash
# CHG-ESTACK-TDE-POSTURE-001 — toda revisión evalúa la postura TDE, sin licencia para leer.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/tde-awareness/SKILL.md"
M="$ROOT/skills/security/tde-awareness/manifest.yaml"
COLLECTORS="Q-SEC-TDE-WALLET-001 Q-SEC-ENCRYPTED-TABLESPACES-001 Q-SEC-ENCRYPTED-COLUMNS-001 Q-SEC-TDE-MASTER-KEYS-001 Q-SEC-SECURITY-PARAMETERS-001"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; FAIL=1; }

for st in NOT_APPLICABLE NOT_CONFIGURED CONFIGURED_NOT_IN_USE IN_USE UNDETERMINED; do
  grep -qF "$st" "$S" && pass "postura $st declarada" || fail "falta la postura $st"
done

# Cada código de hallazgo con su categoría y severidad (una fila de la tabla por código)
row() { grep -E "^\| \`$1\` \|" "$S"; }
check_row() {  # código categoría severidad
  local r; r="$(row "$1")"
  [ -n "$r" ] || { fail "falta la fila $1"; return; }
  grep -qE "\| $2 \|" <<<"$r" && grep -qF "$3" <<<"$r" && pass "$1: $2 / $3" || fail "$1 no es $2 / $3"
}
check_row TDE-01 RISK CRITICAL
check_row TDE-02 RISK HIGH
check_row TDE-03 RISK MEDIUM
check_row TDE-04 IMPROVEMENT LOW
check_row TDE-05 IMPROVEMENT MEDIUM
check_row TDE-06 IMPROVEMENT MEDIUM
check_row TDE-07 MISCONFIGURATION HIGH
check_row TDE-08 MISCONFIGURATION MEDIUM
check_row TDE-09 IMPROVEMENT LOW
check_row TDE-10 IMPROVEMENT LOW
check_row TDE-11 IMPROVEMENT INFO
check_row TDE-12 LICENSE_REVIEW MEDIUM
check_row TDE-13 MISCONFIGURATION LOW

grep -qF "LICENSE_CHECK_REQUIRED" <<<"$(row TDE-12)" && pass "TDE-12 pide LICENSE_CHECK_REQUIRED" || fail "TDE-12 sin LICENSE_CHECK_REQUIRED"
grep -qF "nunca se reporta \`NOT_CONFIGURED\` por falta de datos" "$S" && pass "sin evidencia → UNDETERMINED, nunca NOT_CONFIGURED" || fail "falta la regla de evidencia ausente"
grep -qE "^license_requirements: none" "$M" && pass "manifest: leer la postura no requiere licencia" || fail "manifest con gate de licencia"

for q in $COLLECTORS; do
  grep -qF "query_id: $q" "$M" && pass "manifest exige $q" || fail "manifest no exige $q"
  f="$(find "$ROOT/queries" -name "$q.md" | head -1)"
  grep -qE "^license_requirements: none" "$f" && pass "$q: license_requirements none" || fail "$q con licencia"
  grep -qF "\"collector_id\": \"$q\"" "$ROOT/mcp_gateway/catalog/collectors.factory.json" && pass "$q expuesto por el gateway" || fail "$q no está en el catálogo"
done

for wf in assessment healthcheck; do
  W="$ROOT/workflows/$wf.md"
  grep -qF "Postura TDE (paso fijo, CHG-ESTACK-TDE-POSTURE-001)" "$W" && pass "$wf: paso fijo de postura TDE" || fail "$wf sin paso fijo"
  for q in $COLLECTORS; do
    grep -qF "$q" "$W" || fail "$wf no nombra $q"
  done
  grep -qF "nunca se marcan \`LICENSE_RESTRICTED\`" "$W" && pass "$wf: nunca LICENSE_RESTRICTED" || fail "$wf podría restringir la postura por licencia"
done

grep -qF "Leer el estado de una opción no es usarla" "$ROOT/policies/licensing-awareness-policy.md" \
  && pass "política de licencias: leer no es usar" || fail "falta la regla en la política de licencias"

exit $FAIL
