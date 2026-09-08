#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 18.
# La validación real ya vive en test_dataguard_24_or_future_not_auto_supported.sh (Fase 5
# Compatibility Hardening) — comprueba que el Query Variant Resolver nunca resuelve una major
# futura desconocida como compatible para ninguna query Data Guard, incluidas las variantes
# legacy/modern de Q-DG-MANAGED-PROCESS-001. Este test delega en vez de duplicar la lógica.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/tests/test_dataguard_24_or_future_not_auto_supported.sh"
