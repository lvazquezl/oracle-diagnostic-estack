#!/usr/bin/env bash
# Valida que performance/blocking y agents/oracle-performance-analyst/AGENT.md marquen
# cualquier comando de matar sesión como NOT_EXECUTED/HUMAN_REVIEW_REQUIRED, nunca de otra forma.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

S="$ROOT/skills/performance/blocking/SKILL.md"
grep -q 'NOT_EXECUTED' "$S" && echo "[PASS] performance/blocking marca NOT_EXECUTED" || { echo "[FAIL] performance/blocking no marca NOT_EXECUTED"; FAIL=1; }

A="$ROOT/agents/oracle-performance-analyst/AGENT.md"
grep -q 'NOT_EXECUTED' "$A" && grep -q 'HUMAN_REVIEW_REQUIRED' "$A" && echo "[PASS] AGENT.md documenta NOT_EXECUTED/HUMAN_REVIEW_REQUIRED" || { echo "[FAIL] AGENT.md no documenta NOT_EXECUTED/HUMAN_REVIEW_REQUIRED"; FAIL=1; }

exit $FAIL
