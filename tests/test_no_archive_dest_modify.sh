#!/usr/bin/env bash
# Ningún skill/agente Data Guard modifica LOG_ARCHIVE_DEST_n.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -qi 'no modifica .LOG_ARCHIVE_DEST_n' "$ROOT/skills/dataguard/transport/SKILL.md" \
  && echo "[PASS] dataguard/transport prohíbe explícitamente modificar destinos" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }
grep -q 'ALTER SYSTEM SET LOG_ARCHIVE_DEST_n' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente" \
  || { echo "[FAIL] falta en manifest.yaml"; FAIL=1; }

exit $FAIL
