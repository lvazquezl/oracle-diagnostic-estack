#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 23/44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/channel-contention/SKILL.md"
SCHEMA="$ROOT/agents/oracle-backup-recovery-analyst/output-schema.yaml"

grep -qi 'nunca asum' "$S" && echo "[PASS] rman/channel-contention documenta que nunca asume causa Oracle única" || { echo "[FAIL] falta la prohibición explícita"; FAIL=1; }
grep -q 'single_cause_asserted: false' "$SCHEMA" && echo "[PASS] output-schema fuerza single_cause_asserted: false" || { echo "[FAIL] falta single_cause_asserted: false en el schema"; FAIL=1; }
grep -qi 'media manager\|media-manager' "$S" && echo "[PASS] correlaciona con concurrencia de media manager" || { echo "[FAIL] falta correlación con media manager"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] channel contention nunca asume causa Oracle única"
exit $FAIL
