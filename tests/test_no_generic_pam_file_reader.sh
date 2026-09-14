#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 10/46.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

UNGUARDED=0
while IFS=: read -r file line _; do
  [ -z "$file" ] && continue
  window=$(sed -n "$((line>3?line-3:1)),${line}p" "$file")
  if echo "$window" | grep -qiE 'nunca|no crea|no exponer|no crear|allowlisted|prohibi|genérico\)|forbidden'; then
    continue
  fi
  echo "[FAIL] $file:$line menciona un lector de archivo PAM genérico fuera de contexto de prohibición"
  UNGUARDED=1
done < <(grep -rnoiE '.*(read_pam_file\(|read_file\(|cat_file\(|grep_file\().*' "$ROOT/skills/os" "$ROOT/agents/os-platform-analyst" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" 2>/dev/null | cut -d: -f1,2)

if [ "$UNGUARDED" -eq 0 ]; then
  echo "[PASS] ningún artefacto os/* expone read_pam_file/read_file/cat_file/grep_file genérico fuera de contexto de prohibición"
else
  FAIL=1
fi

D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"
if grep -qi 'validados/allowlisted' "$D"; then
  echo "[PASS] declara que el collector PAM sólo inspecciona servicios allowlisted"
else
  echo "[FAIL] falta la declaración de allowlisting de servicios PAM"; FAIL=1
fi
exit $FAIL
