#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46 — wrapper que delega la comprobación real
# a tests/test_no_channel_allocation_execution.sh (sección 44), mismo patrón "alias" que
# tests/test_no_variant_references_unknown_column.sh delegando a test_sql_static_validator.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/tests/test_no_channel_allocation_execution.sh"
