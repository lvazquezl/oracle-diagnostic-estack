#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 72/57.
# Nombre domain-prefixed (tests/test_no_secrets.sh ya existe, propiedad de Data Guard — mismo
# patrón que tests/test_rman_no_secrets.sh en Fase 7). Ningún artefacto Security expone
# plaintext passwords/hashes/verifiers/wallet keys/private keys/secret values.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='password\s*=|passwd\s*=|IDENTIFIED BY|SECRET\s*=|wallet.?password|private.?key.*value'

for f in $(find "$ROOT/queries/security" "$ROOT/skills/security" "$ROOT/agents/oracle-security-analyst" -type f 2>/dev/null); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    # Ventana hacia atrás Y hacia adelante — un manual_action largo suele envolver el comando en
    # una línea y la cláusula "siempre NOT_EXECUTED" en la línea siguiente (# 73/74 del prompt).
    window=$(sed -n "$((lineno>3?lineno-3:1)),$((lineno+2))p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|sin credenciales|no expone|mask|drop|tokenize|ningún|ningun|no solicita|NOT_EXECUTED'; then
      echo "[FAIL] $f:$lineno contiene un patrón de credencial sin contexto de sanitización"
      FAIL=1
    fi
  done < <(grep -niE "$PATTERN" "$f")
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto Security expone credenciales"

exit $FAIL
