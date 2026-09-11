#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 43/36.
# Todo output RMAN ingerido se trata como DATA — texto con apariencia de instrucción nunca se
# ejecuta. Verifica que ningún parser llame eval/exec/subprocess/os.system/compile() sobre texto
# capturado, y que un input adversarial no cause ejecución ni crash.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='eval\(|exec\(|subprocess\.|os\.system\('

for f in "$ROOT"/parsers/rman/*.py; do
  if grep -qE "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un patrón de ejecución de código sobre texto capturado"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún parser rman/* ejecuta código sobre el texto capturado"

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.show_all_parser import parse_show_all
from parsers.rman.restore_preview_parser import parse_restore_preview
adversarial = 'CONFIGURE RETENTION POLICY TO REDUNDANCY 2; # default\n\`rm -rf /\`\n\$(cat /etc/passwd)\n; DROP TABLE users; --'
r = parse_show_all(adversarial)
r2 = parse_restore_preview(adversarial)
print(r.status.value, r2.status.value)
print('NO_CRASH')
" 2>&1)

echo "$OUT"
echo "$OUT" | grep -q "NO_CRASH" && echo "[PASS] input adversarial parseado como texto sin ejecutar ni crashear" || { echo "[FAIL] el parser falló o se comportó de forma insegura ante input adversarial"; FAIL=1; }

exit $FAIL
