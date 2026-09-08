#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 12.
# La validación real ya vive en test_dataguard_process_modern_uses_supported_columns.sh (fuente
# única del chequeo columna-por-columna contra compatibility/oracle-dictionary/views.yaml). Este
# test existe como nombre requerido por la sección 12 del prompt de Final Process-View Hardening,
# y delega para no duplicar la lógica de validación — mismo patrón que
# test_no_variant_references_unknown_column.sh (Fase 5 Compatibility Hardening).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/tests/test_dataguard_process_modern_uses_supported_columns.sh"
