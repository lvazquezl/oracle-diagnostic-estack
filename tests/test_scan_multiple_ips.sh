#!/usr/bin/env bash
# El fixture 19c-scan-healthy declara 3 IPs SCAN configuradas y resueltas consistentemente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/19c-scan-healthy.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta fixture 19c-scan-healthy.yaml"; exit 1; }
grep -q 'configured_ips: 3' "$FX" && echo "[PASS] fixture declara 3 IPs SCAN configuradas" || { echo "[FAIL] fixture no declara 3 IPs"; FAIL=1; }
grep -q 'resolved_ip_count: 3' "$FX" && echo "[PASS] fixture declara resolución consistente con 3 respuestas" || { echo "[FAIL] falta resolved_ip_count"; FAIL=1; }

exit $FAIL
