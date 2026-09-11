#!/usr/bin/env bash
# Valida que routing.yaml de oracle-backup-recovery-analyst declara activation_conditions y
# deactivation_rule.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
R="$ROOT/agents/oracle-backup-recovery-analyst/routing.yaml"

grep -q '^activation_conditions:' "$R" && echo "[PASS] declara activation_conditions" || { echo "[FAIL] falta activation_conditions"; FAIL=1; }
grep -q '^deactivation_rule:' "$R" && echo "[PASS] declara deactivation_rule" || { echo "[FAIL] falta deactivation_rule"; FAIL=1; }
grep -q '^delegates_to:' "$R" && echo "[PASS] declara delegates_to" || { echo "[FAIL] falta delegates_to"; FAIL=1; }
grep -q '^receives_from:' "$R" && echo "[PASS] declara receives_from" || { echo "[FAIL] falta receives_from"; FAIL=1; }

exit $FAIL
