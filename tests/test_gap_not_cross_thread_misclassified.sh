#!/usr/bin/env bash
# Regla explícita # 15/# 58: nunca comparar secuencias entre threads como si fueran una sola serie.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/archive-gaps/SKILL.md"
Q="$ROOT/queries/dataguard/Q-DG-ARCHIVE-GAP-001.md"

grep -qi 'nunca compara secuencias entre threads' "$S" && echo "[PASS] archive-gaps declara la regla explícitamente" || { echo "[FAIL] falta la regla"; FAIL=1; }
grep -qi 'nunca reordena/combina secuencias entre threads' "$Q" && echo "[PASS] Q-DG-ARCHIVE-GAP-001 documenta la regla" || { echo "[FAIL] falta la regla en la query"; FAIL=1; }

exit $FAIL
