#!/usr/bin/env bash
# dataguard/lag mide apply_lag por separado de transport_lag, siempre como OBSERVATION (# 56).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/lag/SKILL.md"

grep -q 'APPLY_LAG' "$S" && echo "[PASS] lag declara APPLY_LAG" || { echo "[FAIL] falta APPLY_LAG"; FAIL=1; }
grep -qi 'es una OBSERVACIÓN, no una causa raíz' "$S" && echo "[PASS] apply_lag tratado como OBSERVATION, no causa raíz" || { echo "[FAIL] falta la regla # 56"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-apply-lag.yaml" ] && echo "[PASS] fixture de apply lag existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
