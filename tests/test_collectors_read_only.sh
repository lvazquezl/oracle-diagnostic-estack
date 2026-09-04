#!/usr/bin/env bash
# Valida que docs/GI_READONLY_COLLECTORS.md declara side_effect_class: READ_ONLY como el único
# valor habilitado (el schema permite BLOCKED para lo que no pueda garantizarse, nunca otro).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/GI_READONLY_COLLECTORS.md"

grep -q 'side_effect_class: READ_ONLY|BLOCKED' "$DOC" && echo "[PASS] side_effect_class declarado como READ_ONLY|BLOCKED" || { echo "[FAIL] falta la declaración de side_effect_class"; FAIL=1; }
grep -q 'side_effect_class.*es siempre .READ_ONLY. para todo collector habilitado' "$DOC" && echo "[PASS] regla explícita: READ_ONLY para todo collector habilitado" || { echo "[FAIL] falta la regla explícita de READ_ONLY por defecto"; FAIL=1; }

exit $FAIL
