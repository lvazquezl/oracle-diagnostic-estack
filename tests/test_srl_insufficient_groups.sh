#!/usr/bin/env bash
# dataguard/standby-redo-logs detecta grupos insuficientes; fixture correspondiente existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/standby-redo-logs/SKILL.md"

grep -q 'INSUFFICIENT' "$S" && echo "[PASS] SRL declara INSUFFICIENT" || { echo "[FAIL] falta INSUFFICIENT"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-insufficient-srl.yaml" ] && echo "[PASS] fixture de SRL insuficiente existe" || { echo "[FAIL] falta fixture"; FAIL=1; }
grep -qi 'sin aplicar una fórmula rígida sin contexto\|SRL Readiness Rule' "$S" && echo "[PASS] documenta la regla empleada sin fórmula rígida (# 18)" || { echo "[FAIL] falta la nota de # 18"; FAIL=1; }

exit $FAIL
