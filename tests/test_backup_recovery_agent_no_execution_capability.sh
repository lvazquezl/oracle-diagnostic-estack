#!/usr/bin/env bash
# Valida que oracle-backup-recovery-analyst no tiene ninguna capacidad real de ejecución RMAN
# (BACKUP/RESTORE/RECOVER/DELETE/CROSSCHECK/CHANGE/CONFIGURE/CATALOG/UNCATALOG/DUPLICATE/
# SWITCH DATABASE/ALLOCATE CHANNEL/RELEASE CHANNEL).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -q '^security_mode: READ_ONLY_ALWAYS' "$M" && echo "[PASS] security_mode: READ_ONLY_ALWAYS" || { echo "[FAIL] security_mode no es READ_ONLY_ALWAYS"; FAIL=1; }

for verb in BACKUP RESTORE RECOVER DELETE CROSSCHECK CHANGE CONFIGURE CATALOG UNCATALOG DUPLICATE "SWITCH DATABASE" "ALLOCATE CHANNEL" "RELEASE CHANNEL"; do
  grep -qF "$verb" "$M" && echo "[PASS] manifest menciona la prohibición de: $verb" || { echo "[FAIL] falta la prohibición de: $verb"; FAIL=1; }
done

exit $FAIL
