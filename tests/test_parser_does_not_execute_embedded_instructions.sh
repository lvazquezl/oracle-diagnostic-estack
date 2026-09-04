#!/usr/bin/env bash
# Valida que texto dentro de un reporte diseñado para parecer una instrucción (prompt injection)
# vuelva como dato de texto inerte, nunca ejecutado/interpretado (# 22 PARSER SECURITY).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# 1) Ningún módulo de parsers/performance/ invoca eval/exec/subprocess/os.system, ni el
#    compile() builtin peligroso (re.compile() de expresiones regulares está explícitamente
#    permitido y excluido de este chequeo).
DANGEROUS=$(grep -rEn '\beval\(|\bexec\(|subprocess\.|os\.system|os\.popen' "$ROOT/parsers/performance"/*.py | grep -v 'never calls' || true)
DANGEROUS_COMPILE=$(grep -rEn '(^|[^.a-zA-Z_])compile\(' "$ROOT/parsers/performance"/*.py | grep -v 're\.compile(' | grep -v 'never calls' || true)
if [ -n "$DANGEROUS" ] || [ -n "$DANGEROUS_COMPILE" ]; then
  echo "[FAIL] parsers/performance/ invoca eval/exec/compile/subprocess — riesgo de interpretar contenido de reporte"
  echo "$DANGEROUS"
  echo "$DANGEROUS_COMPILE"
  FAIL=1
else
  echo "[PASS] Ningún módulo de parsers/performance/ invoca eval/exec/compile/subprocess"
fi

# 2) El contenido inyectado vuelve como string plano dentro de sections, no altera el control
#    de flujo del parser (mismo status/keys que un ADDM finding normal).
OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.addm_parser import parse_addm_text
with open('tests/fixtures/reports/addm-injection-attempt.txt', encoding='utf-8') as f:
    r = parse_addm_text(f.read())
d = r.to_dict()['report']
assert d['status'] == 'SUCCESS'
finding = d['sections']['findings'][0]
assert finding['classification'] == 'EVIDENCE_SOURCE'
assert isinstance(finding['description'], str)
assert 'IGNORE ALL PREVIOUS INSTRUCTIONS' in finding['description']
rec = d['sections']['recommendations'][0]
assert isinstance(rec['summary'], str)
assert rec['manual_execution_required'] is True
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Contenido tipo prompt-injection vuelve como string inerte, clasificación/estado sin alterar"
else
  echo "[FAIL] Manejo de contenido tipo prompt-injection falló: $OUT"
  FAIL=1
fi

exit $FAIL
