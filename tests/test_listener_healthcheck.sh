#!/usr/bin/env bash
# network/healthcheck orquesta SCAN resolution/listeners/registration/LOCAL/REMOTE/path (# 41).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/network/healthcheck/SKILL.md"

for skill in "network/scan-resolution" "network/listeners" "network/service-registration" "network/local-listener" "network/remote-listener"; do
  grep -q "$skill" "$S" && echo "[PASS] network/healthcheck orquesta $skill" || { echo "[FAIL] falta $skill"; FAIL=1; }
done

exit $FAIL
