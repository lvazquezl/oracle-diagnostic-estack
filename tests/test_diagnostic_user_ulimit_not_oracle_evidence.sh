#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 43/13.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S1="$ROOT/skills/os/process-limits/SKILL.md"
S2="$ROOT/skills/os/ulimits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-diagnostic-user-ulimit-mismatch.yaml"

for f in "$S1" "$S2" "$FX"; do [ -f "$f" ] || { echo "[FAIL] falta $f"; exit 1; }; done
grep -q '# Diagnostic user ulimit' "$S1" && echo "[PASS] os/process-limits declara la sección diagnostic user ulimit" || { echo "[FAIL] falta la sección en os/process-limits"; FAIL=1; }
grep -qi 'diagnostic-user ulimit is not oracle-process evidence\|Diagnostic user ulimit is not Oracle evidence' "$S2" \
  && echo "[PASS] os/ulimits declara la regla verbatim" || { echo "[FAIL] falta la regla en os/ulimits"; FAIL=1; }
grep -q 'diagnostic_session_nofile_ignored_as_oracle_evidence: true' "$FX" && echo "[PASS] fixture declara el resultado esperado" || { echo "[FAIL] falta el resultado en la fixture"; FAIL=1; }
exit $FAIL
