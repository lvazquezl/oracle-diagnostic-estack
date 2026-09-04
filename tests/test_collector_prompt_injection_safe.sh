#!/usr/bin/env bash
# Prueba viva de que un intento de prompt injection embebido en salida de crsctl vuelve como
# campo de datos inerte (string), nunca ejecutado — # 47 PROMPT INJECTION del prompt de Fase 4.
# Complementa la verificación estática de test_no_arbitrary_shell.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FIXTURE="$ROOT/tests/fixtures/collectors/crsctl-injection-attempt.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta fixture $FIXTURE"; exit 1; }

OUT=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, '.')
from parsers.rac.crsctl_resource_parser import parse_crsctl_resources
with open('tests/fixtures/collectors/crsctl-injection-attempt.txt') as f:
    text = f.read()
r = parse_crsctl_resources(text)
assert r.status.value == 'SUCCESS', f'unexpected status: {r.status}'
last = r.sections['all_resources'][-1]
assert isinstance(last['state_details'], str), 'state_details no es un string inerte'
assert 'IGNORE ALL PREVIOUS INSTRUCTIONS' in last['state_details'], 'contenido de inyección no capturado como dato'
print('[PASS] contenido de intento de inyección vuelve como campo de datos inerte, nunca ejecutado')
")
RC=$?
echo "$OUT"
[ $RC -ne 0 ] && { echo "[FAIL] la prueba de inyección no se comportó como se esperaba"; FAIL=1; }

exit $FAIL
