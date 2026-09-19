#!/usr/bin/env bash
# PHASE 12 — SECURITY TEST COMPLETION: aislamiento del arnés de pruebas.
# Un módulo tests/p12/check_*.py debe ejecutar EXACTAMENTE los casos que define: importar otro módulo de checks
# (p. ej. para reutilizar un helper) no puede registrar ni ejecutar sus casos como efecto colateral, porque
# infla el conteo reportado y hace que una suite "lenta" ejecute trabajo ajeno. Además, los wrappers
# test_p12_*.sh deben transmitir la salida en vivo (sin acumularla en una variable de shell) para que una
# ejecución lenta sea distinguible de un bloqueo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
FAIL=0

for mod in check_contract check_change check_documents check_knowledge check_security check_cross_domain check_phase11_integration; do
  RES="$(PYTHONDONTWRITEBYTECODE=1 python3 - "$mod" <<'PYEOF' 2>/dev/null
import contextlib, importlib, io, re, sys
sys.path.insert(0, ".")
from tests.p12 import harness
mod = sys.argv[1]
importlib.import_module("tests.p12." + mod)
defined = len(harness._TESTS)
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = harness.run_all()
m = re.search(r"(\d+)/(\d+) checks OK", buf.getvalue())
ran = int(m.group(2)) if m else -1
print(f"{mod} defined={defined} ran={ran} rc={rc}")
sys.exit(0 if (defined == ran and rc == 0) else 1)
PYEOF
)"
  if [ $? -eq 0 ]; then echo "[PASS] $RES"; else echo "[FAIL] $RES (un módulo ejecutó casos que no define)"; FAIL=1; fi
done

# los wrappers no deben acumular toda la salida en una variable de shell
for w in "$ROOT"/tests/test_p12_*.sh; do
  b="$(basename "$w")"
  case "$b" in test_p12_agents_skills_registry.sh|test_p12_harness_isolation.sh) continue ;; esac
  if grep -q 'OUT="\$(' "$w"; then echo "[FAIL] $b acumula la salida en una variable de shell"; FAIL=1; else echo "[PASS] $b transmite su salida (sin variable de shell)"; fi
done
exit $FAIL
