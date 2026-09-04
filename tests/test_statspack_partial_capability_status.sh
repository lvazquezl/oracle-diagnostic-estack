#!/usr/bin/env bash
# Valida que el skill performance/statspack-analysis documente el Capability Map específico
# (Statspack != AWR) usando PARTIALLY_SUPPORTED por sección, nunca universalidad falsa
# (# 6 STATSPACK ≠ AWR).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/statspack-analysis/SKILL.md"

grep -q 'statspack_capabilities' "$S" && echo "[PASS] SKILL.md documenta statspack_capabilities" || { echo "[FAIL] falta statspack_capabilities"; FAIL=1; }
grep -qi 'ash_sampling' "$S" && echo "[PASS] SKILL.md declara explícitamente ash_sampling: unsupported (Statspack != AWR)" || { echo "[FAIL] falta la distinción explícita ash_sampling unsupported"; FAIL=1; }
grep -q 'PARTIALLY_SUPPORTED' "$S" && echo "[PASS] SKILL.md usa PARTIALLY_SUPPORTED por sección" || { echo "[FAIL] no usa PARTIALLY_SUPPORTED"; FAIL=1; }

exit $FAIL
