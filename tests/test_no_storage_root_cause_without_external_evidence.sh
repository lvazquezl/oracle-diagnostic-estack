#!/usr/bin/env bash
# Valida que performance/io/Q-PERF-IO-FILESTAT-001 nunca confirme un problema de storage sin
# evidencia OS/storage externa (# 27. I/O del prompt de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/io/SKILL.md"
Q="$ROOT/queries/performance/io/Q-PERF-IO-FILESTAT-001.md"

grep -qi 'OBSERVATION.*no confirmación\|nunca confirma\|nunca.*problema de storage' "$S" && echo "[PASS] performance/io nunca confirma un problema de storage sin evidencia externa" || { echo "[FAIL] no declara la regla de no confirmar sin evidencia externa"; FAIL=1; }
grep -qi 'OBSERVATION' "$Q" && echo "[PASS] Q-PERF-IO-FILESTAT-001 documenta el nivel OBSERVATION" || { echo "[FAIL] Q-PERF-IO-FILESTAT-001 no documenta OBSERVATION"; FAIL=1; }

exit $FAIL
