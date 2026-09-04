#!/usr/bin/env bash
# Todo collector externo debe tener timeout_seconds/max_output_bytes declarados (# 59).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/GI_READONLY_COLLECTORS.md"

grep -q 'timeout_seconds: number' "$DOC" && echo "[PASS] Collector Contract declara timeout_seconds" || { echo "[FAIL] falta timeout_seconds"; FAIL=1; }
grep -q 'max_output_bytes: number' "$DOC" && echo "[PASS] Collector Contract declara max_output_bytes" || { echo "[FAIL] falta max_output_bytes"; FAIL=1; }

exit $FAIL
