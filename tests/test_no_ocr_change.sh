#!/usr/bin/env bash
# Ningún collector/parser declara ocrconfig de escritura (replace/restore/import/export/add).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq 'ocrconfig' "$f"; then
    echo "[FAIL] $f menciona ocrconfig (herramienta de escritura de OCR) — sólo ocrcheck (lectura) está permitido"
    FAIL=1
  fi
done

grep -qi 'no reemplaza/restaura ocr, no modifica su configuración' "$ROOT/skills/rac/gi-ocr-status/SKILL.md" \
  && echo "[PASS] rac/gi-ocr-status prohíbe explícitamente reemplazo/restauración de OCR" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara ocrconfig (escritura de OCR)"
exit $FAIL
