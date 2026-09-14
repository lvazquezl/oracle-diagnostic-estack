#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 74/87. Ningún collector/skill del
# dominio OS requiere root/privileged shell.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -qi "root/sudo/privileged shell" "$ROOT/agents/os-platform-analyst/manifest.yaml" \
  && echo "[PASS] manifest prohíbe root/sudo/privileged shell" \
  || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }

grep -qi "sin.*root.*sudo.*Administrator" "$ROOT/docs/OS_READONLY_PRIVILEGES.md" \
  && echo "[PASS] docs/OS_READONLY_PRIVILEGES.md declara identidad sin root/sudo/Administrator" \
  || { echo "[FAIL] falta la declaración en OS_READONLY_PRIVILEGES.md"; FAIL=1; }

for f in $(find "$ROOT/skills/os" -name 'SKILL.md' 2>/dev/null); do
  if grep -qiE '\brequires?\s+root\b|\bas root\b|sudo -u root' "$f"; then
    echo "[FAIL] $f sugiere requerir root"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún skill os/* requiere root"
exit $FAIL
