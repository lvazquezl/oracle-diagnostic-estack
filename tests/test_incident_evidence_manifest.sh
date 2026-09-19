#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: el reporte de incidente incluye un
# evidence-manifest trazable, consistente con el resto del e-stack (evidence-manifest.json).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -qi 'evidence-manifest.json' "$ROOT/workflows/healthcheck.md" \
  && echo "[PASS] evidence-manifest.json es un artefacto estándar del e-stack" \
  || { echo "[FAIL] falta evidence-manifest.json como referencia en workflows/healthcheck.md"; FAIL=1; }

grep -qi 'no_raw_logs_to_model' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara no_raw_logs_to_model en su evidence_policy" \
  || { echo "[FAIL] falta no_raw_logs_to_model en el manifest del agente"; FAIL=1; }

grep -qi 'no_secrets' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara no_secrets en su evidence_policy" \
  || { echo "[FAIL] falta no_secrets en el manifest del agente"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Evidence manifest del dominio incident consistente"
exit $FAIL
