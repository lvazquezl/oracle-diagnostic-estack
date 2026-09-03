#!/usr/bin/env bash
# Alias/wrapper: la validación real vive en test_sql_static_validator.sh (fuente única del
# chequeo columna-por-versión). Este test existe como nombre requerido por la sección 24 del
# prompt de Compatibility Hardening, y delega para no duplicar la lógica de validación.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/tests/test_sql_static_validator.sh"
