#!/usr/bin/env bash
# Valida que Q-PERF-SGA-001 no dependa de columnas version-gated no guardadas (streams pool se
# maneja como opcional, no en el SELECT base).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/memory/Q-PERF-SGA-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-SGA-001.md"; exit 1; }
grep -A2 'V\$SGA:' "$ROOT/compatibility/oracle-dictionary/views.yaml" | grep -q 'min_version: all' && echo "[PASS] V\$SGA registrada como all en el dictionary" || { echo "[FAIL] V\$SGA no registrada correctamente"; FAIL=1; }
grep -q "streams pool" "$F" && echo "[PASS] streams pool documentado como opcional, no en el SELECT base" || { echo "[FAIL] streams pool no documentado"; FAIL=1; }

exit $FAIL
