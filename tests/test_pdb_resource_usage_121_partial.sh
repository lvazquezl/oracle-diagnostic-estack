#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 11-12, # 39, # 46.
# Valida que la degradación de 12.1 es EXPLÍCITA (capability_status: PARTIALLY_SUPPORTED con razón),
# no una simple ausencia silenciosa.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
SKILL="$ROOT/skills/multitenant/resource-usage/SKILL.md"

grep -qi 'capability_status: PARTIALLY_SUPPORTED' "$SKILL" && echo "[PASS] resource-usage/SKILL.md declara capability_status: PARTIALLY_SUPPORTED para 12.1" || { echo "[FAIL] falta capability_status: PARTIALLY_SUPPORTED"; FAIL=1; }

grep -qi 'reason:.*V\$RSRCPDBMETRIC no certificada en 12.1' "$SKILL" && echo "[PASS] resource-usage/SKILL.md declara una razón explícita para la degradación 12.1" || { echo "[FAIL] falta razón explícita de degradación 12.1"; FAIL=1; }

grep -qi 'no se inventa una alternativa\|sin fuente equivalente certificada' "$SKILL" && echo "[PASS] SKILL.md documenta que no se inventó una fuente alternativa para 12.1" || { echo "[FAIL] SKILL.md no documenta la ausencia de alternativa inventada"; FAIL=1; }

exit $FAIL
