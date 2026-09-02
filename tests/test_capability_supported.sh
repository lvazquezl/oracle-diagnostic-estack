#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/policies/capability-degradation-policy.md"
if grep -q '### `SUPPORTED`' "$F"; then
  echo "[PASS] capability-degradation-policy.md documenta el estado SUPPORTED"
  exit 0
else
  echo "[FAIL] capability-degradation-policy.md no documenta el estado SUPPORTED"
  exit 1
fi
