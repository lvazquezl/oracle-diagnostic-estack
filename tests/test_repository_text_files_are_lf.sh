#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, secciones 20-23.
# Test general de portabilidad: ningún archivo de texto crítico (*.sh, *.bash, *.py, *.yaml,
# *.yml, *.json, *.md) debe contener CRLF — un checkout/ZIP en Windows sin honrar .gitattributes
# puede reintroducir CRLF y romper silenciosamente bash/awk/parsers (ver la regresión real
# encontrada y corregida en compatibility/oracle-dictionary/views.yaml durante este hardening).
# Implementado con Python stdlib (no depende sólo de comportamiento de shell/grep, más portable
# entre Windows Git Bash / WSL / Linux CI — # 23 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PYEOF'
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

root = sys.argv[1]
extensions = ('.sh', '.bash', '.py', '.yaml', '.yml', '.json', '.md')
excluded_dirs = {'.git', '__pycache__', 'node_modules'}

# Excepciones documentadas donde CRLF es intencional (ninguna hoy — # 22: "excluir únicamente
# archivos donde CRLF sea intencional y documentado"). Rutas relativas a ROOT, con "/" siempre.
DOCUMENTED_CRLF_EXCEPTIONS = set()

offenders = []
scanned = 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in excluded_dirs]
    for fn in filenames:
        if not fn.endswith(extensions):
            continue
        full = os.path.join(dirpath, fn)
        rel = os.path.relpath(full, root).replace(os.sep, '/')
        if rel in DOCUMENTED_CRLF_EXCEPTIONS:
            continue
        scanned += 1
        try:
            with open(full, 'rb') as f:
                data = f.read()
        except OSError as e:
            print(f"[FAIL] no se pudo leer {rel}: {e}")
            offenders.append(rel)
            continue
        if b'\r\n' in data:
            offenders.append(rel)

if offenders:
    for rel in offenders:
        print(f"[FAIL] {rel} contiene CRLF — debe ser LF (ver .gitattributes)")
    print(f"[FAIL] {len(offenders)} de {scanned} archivos de texto críticos tienen CRLF")
    sys.exit(1)
else:
    print(f"[PASS] Los {scanned} archivos de texto críticos (*.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md) están en LF")
    sys.exit(0)
PYEOF
exit $?
