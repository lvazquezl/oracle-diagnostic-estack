#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/24.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/sbt-media-manager/SKILL.md"

grep -qi 'vendor_token.*MASK\|MASK/DROP' "$S" && echo "[PASS] rman/sbt-media-manager sanitiza vendor_token/PARMS" || { echo "[FAIL] falta la sanitización de vendor_token/PARMS"; FAIL=1; }
grep -qi 'nunca se envían credenciales al modelo' "$S" && echo "[PASS] documenta que nunca envía credenciales al modelo" || { echo "[FAIL] falta la prohibición de enviar credenciales"; FAIL=1; }

OUT=$(cd "$ROOT" && python -c "
from parsers.rman.show_all_parser import parse_show_all
text = \"CONFIGURE CHANNEL DEVICE TYPE SBT_TAPE PARMS 'SBT_LIBRARY=libobk.so ENV=(NSR_SERVER=backupsrv,SECRET=abc123)';\"
r = parse_show_all(text)
cfg = r.sections['configuration'][0]['config']
assert 'SECRET=abc123' not in cfg, cfg
assert 'PATH_TOKEN' in cfg, cfg
print('OK')
" 2>&1)
echo "$OUT"
echo "$OUT" | grep -q "^OK$" && echo "[PASS] parse_show_all tokeniza PARMS de canal SBT, nunca expone el valor crudo" || { echo "[FAIL] PARMS de canal SBT expuesto crudo"; FAIL=1; }

exit $FAIL
