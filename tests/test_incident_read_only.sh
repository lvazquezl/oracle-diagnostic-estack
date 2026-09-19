#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident-root-cause-analyst declara
# security_mode READ_ONLY_ALWAYS y ningún skill/manifest del dominio incident declara una
# operación de escritura como soportada.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

MANIFEST="$ROOT/agents/incident-root-cause-analyst/manifest.yaml"
[ -f "$MANIFEST" ] || { echo "[FAIL] falta $MANIFEST"; FAIL=1; }

grep -q 'security_mode: READ_ONLY_ALWAYS' "$MANIFEST" \
  && echo "[PASS] incident-root-cause-analyst declara security_mode: READ_ONLY_ALWAYS" \
  || { echo "[FAIL] falta security_mode: READ_ONLY_ALWAYS en el manifest"; FAIL=1; }

for f in $(find "$ROOT/skills/incident" -name 'manifest.yaml' 2>/dev/null); do
  grep -qE '^\s*mutation_capable:\s*true' "$f" \
    && { echo "[FAIL] $f declara mutation_capable: true"; FAIL=1; }
  grep -qE '^\s*read_only:\s*false' "$f" \
    && { echo "[FAIL] $f declara read_only: false"; FAIL=1; }
done

[ $FAIL -eq 0 ] && echo "[PASS] Todos los skills incident/* son read_only, ningún mutation_capable: true"
exit $FAIL
