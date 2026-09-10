#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 12, # 39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-RESOURCE-USAGE-001.md"

grep -q '^status: active' "$Q" && echo "[PASS] Q-CDB-RESOURCE-USAGE-001 está activa (12.2+ soportado)" || { echo "[FAIL] Q-CDB-RESOURCE-USAGE-001 no está activa"; FAIL=1; }

grep -qi 'objects_accessed: \[V\$RSRCPDBMETRIC\]' "$Q" && echo "[PASS] objects_accessed declara V\$RSRCPDBMETRIC" || { echo "[FAIL] objects_accessed no declara V\$RSRCPDBMETRIC"; FAIL=1; }

exit $FAIL
