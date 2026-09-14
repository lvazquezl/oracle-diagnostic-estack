#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 36/47.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

UNGUARDED=0
while IFS=: read -r file line _; do
  [ -z "$file" ] && continue
  window=$(sed -n "$((line>3?line-3:1)),${line}p" "$file")
  if echo "$window" | grep -qiE 'nunca|no crea|no exponer|no crear|allowlisted|genérico\)|forbidden|prohibi'; then
    continue
  fi
  echo "[FAIL] $file:$line menciona un lector de /proc/archivo genérico fuera de contexto de prohibición"
  UNGUARDED=1
done < <(grep -rnoiE '.*(read_proc\(|read_file\(|cat_file\().*' "$ROOT/skills/os" "$ROOT/agents/os-platform-analyst" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" 2>/dev/null | cut -d: -f1,2)

if [ "$UNGUARDED" -eq 0 ]; then
  echo "[PASS] ningún artefacto os/* expone read_proc/read_file/cat_file genérico fuera de contexto de prohibición"
else
  FAIL=1
fi

D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"
grep -qi 'PID-scoped' "$D" && echo "[PASS] get_process_effective_limits está acotado por PID, no por path arbitrario" || { echo "[FAIL] falta la declaración PID-scoped"; FAIL=1; }
exit $FAIL
