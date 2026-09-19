#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: ningún artefacto del dominio incident
# aplica cambios de seguridad (grants, roles, wallet, TLS, desbloqueo de cuentas).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='GRANT\s|REVOKE\s|ALTER\s+USER.*ACCOUNT\s+UNLOCK|ADMINISTER KEY MANAGEMENT|CREATE\s+ROLE|DROP\s+ROLE'

for f in $(find "$ROOT/skills/incident" "$ROOT/agents/incident-root-cause-analyst" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead|NOT_EXECUTED'; then
      echo "[FAIL] $f:$lineno contiene un patrón de cambio de seguridad sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE "$PATTERN" "$f")
done

grep -qi 'aplicar cambios de seguridad' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara explícitamente la prohibición de cambios de seguridad" \
  || { echo "[FAIL] falta la prohibición explícita de cambios de seguridad"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto de incident aplica cambios de seguridad"
exit $FAIL
