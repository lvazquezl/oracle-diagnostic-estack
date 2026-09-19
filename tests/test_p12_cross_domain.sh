#!/usr/bin/env bash
# PHASE 12 — CHANGE ADVISORY, DOCUMENTATION & KNOWLEDGE LIFECYCLE: RAC/ASM/Data Guard/Multitenant/RMAN/Network/OS/Security/Capacity con el rca_engine real
# Test funcional: ejecuta tests/p12/check_cross_domain.py, que afirma sobre resultados REALES del CLI/JSON/Markdown/KB
# (nunca sobre grep de documentación). La salida se TRANSMITE en vivo (no se acumula en una variable de shell)
# y se conserva en un temporal acotado que se elimina al salir; así una ejecución lenta se distingue de un
# bloqueo. Diagnóstico opt-in: P12_TIMING=1 imprime `[TIME] <caso> <segundos>` (sólo nombre y duración).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 -m tests.p12.check_cross_domain 2>&1 | tee "$LOG" | grep --line-buffered -E '^\[(PASS|FAIL|SKIP|TIME)\]|checks OK|MUTATION SURVIVED|Error'
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
  tail -n 40 "$LOG"
  echo "[FAIL] check_cross_domain (exit $RC)"
  exit 1
fi
echo "[PASS] check_cross_domain"
exit 0
