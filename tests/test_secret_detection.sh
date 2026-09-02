#!/usr/bin/env bash
# Valida que no haya secretos reales en el repositorio distribuible (excluye evidence/analysis/reports, que están gitignored).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='-----BEGIN (RSA |EC )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|password\s*=\s*[^<'"'"'"[:space:]][^[:space:]]*'

MATCHES=$(grep -RIn --include='*.md' --include='*.yaml' --include='*.yml' --include='*.sh' --include='*.ps1' \
  --exclude-dir=evidence --exclude-dir=analysis --exclude-dir=reports \
  -E -e "$PATTERN" "$ROOT" | grep -viE 'password: *<|password *= *<DBA_TO_SUPPLY|placeholder|example|nunca.*credencial' || true)

if [ -n "$MATCHES" ]; then
  echo "[FAIL] Posibles secretos encontrados:"
  echo "$MATCHES"
  FAIL=1
else
  echo "[PASS] No se detectaron secretos en el repositorio distribuible"
fi

exit $FAIL
