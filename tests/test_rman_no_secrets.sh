#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46.
# Nombre domain-prefixed (tests/test_no_secrets.sh ya existe, propiedad de Data Guard, scoped a
# queries/dataguard). Ningún artefacto RMAN expone passwords/wallets/credenciales de media manager.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='password\s*=|passwd\s*=|IDENTIFIED BY|SECRET\s*='

for f in $(find "$ROOT/queries/rman" "$ROOT/skills/rman" "$ROOT/parsers/rman" "$ROOT/agents/oracle-backup-recovery-analyst" -type f 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|never|sin credenciales|no expone|mask|drop|tokenize'; then
      echo "[FAIL] $f:$lineno contiene un patrón de credencial sin contexto de sanitización"
      FAIL=1
    fi
  done < <(grep -niE "$PATTERN" "$f")
done

grep -qi 'sin credenciales' "$ROOT/skills/rman/sbt-media-manager/SKILL.md" \
  && echo "[PASS] sbt-media-manager bloquea credenciales embebidas explícitamente" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto RMAN expone credenciales"
exit $FAIL
