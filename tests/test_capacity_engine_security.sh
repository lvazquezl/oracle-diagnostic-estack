#!/usr/bin/env bash
# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING, sección 10/caso 16
# (# 159, # 166-168 del prompt): sin acceso a red/PROD, sin SQL/shell arbitrarios, sin
# resize/extensión/mutación.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# Grep estático: ningún módulo de capacity_engine importa sockets/subprocess/os.system/requests/
# urllib ni ejecuta eval/exec — el motor trabaja exclusivamente con datos ya en memoria (fixtures/
# evidencia ya recolectada), nunca abre una conexión ni ejecuta comandos.
FORBIDDEN='import socket|import subprocess|os\.system\(|os\.popen\(|import requests|import urllib|paramiko|\beval\(|\bexec\(|execute_sql|execute_shell|cx_Oracle|oracledb|import ftplib|import telnetlib'
HITS=$(grep -rEn "$FORBIDDEN" "$ROOT/capacity_engine" --include='*.py' || true)
if [ -z "$HITS" ]; then
  echo "[PASS] ningún módulo de capacity_engine importa red/subprocess/eval/exec/SQL-shell arbitrario"
else
  echo "[FAIL] capacity_engine contiene patrones prohibidos:"
  echo "$HITS"
  FAIL=1
fi

# Import allowlist: solo stdlib (verificado ejecutando el paquete en un entorno sin paquetes de
# terceros no sería práctico aquí; en su lugar se enumeran los imports de primer nivel y se
# comparan contra una lista conocida de módulos stdlib).
OUT=$(cd "$ROOT" && python3 -c "
import ast, sys, pathlib

STDLIB_ALLOWLIST = {
    'math', 'statistics', 'datetime', 'enum', 'dataclasses', 'typing', 'json', 'argparse',
    'sys', 'random', '__future__', 'capacity_engine',
}
bad = []
for path in pathlib.Path('capacity_engine').glob('*.py'):
    tree = ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                top = alias.name.split('.')[0]
                if top not in STDLIB_ALLOWLIST:
                    bad.append((str(path), top))
        elif isinstance(node, ast.ImportFrom):
            if node.module and not node.level:
                top = node.module.split('.')[0]
                if top not in STDLIB_ALLOWLIST:
                    bad.append((str(path), top))
assert not bad, bad
print('ENGINE_OK')
")
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] capacity_engine sólo importa la librería estándar de Python (sin dependencias externas)"
else
  echo "[FAIL] import no permitido detectado: $OUT"
  FAIL=1
fi

# Ningún módulo del motor declara una función de mutación (resize/extend/alter/create/grant/etc.)
MUTATION_VERBS='def resize|def extend_|def alter_|def create_datafile|def add_disk|def modify_vmware|def execute_'
HITS2=$(grep -rEn "$MUTATION_VERBS" "$ROOT/capacity_engine" --include='*.py' || true)
if [ -z "$HITS2" ]; then
  echo "[PASS] ningún módulo de capacity_engine declara una función de mutación de infraestructura"
else
  echo "[FAIL] función de mutación encontrada en capacity_engine:"
  echo "$HITS2"
  FAIL=1
fi

exit $FAIL
