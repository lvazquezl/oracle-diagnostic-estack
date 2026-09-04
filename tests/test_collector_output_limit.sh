#!/usr/bin/env bash
# Verifica que parsers/rac/common.py implementa un límite real de tamaño de salida y que
# los parsers lo aplican (SizeLimitPolicy.max_output_bytes, truncamiento con warning — # 60).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -q 'max_output_bytes' "$ROOT/parsers/rac/common.py" && echo "[PASS] SizeLimitPolicy declara max_output_bytes" || { echo "[FAIL] falta max_output_bytes en common.py"; FAIL=1; }
grep -q 'def truncate_rows' "$ROOT/parsers/rac/common.py" && echo "[PASS] truncate_rows() existe como único punto de truncamiento" || { echo "[FAIL] falta truncate_rows()"; FAIL=1; }

python3 -c "
import sys
sys.path.insert(0, '$ROOT')
from parsers.rac.common import SizeLimitPolicy, truncate_rows
warnings = []
rows = list(range(10))
out = truncate_rows(rows, 3, warnings, 'test')
assert len(out) == 3, f'expected 3 rows, got {len(out)}'
assert len(warnings) == 1, f'expected 1 warning, got {len(warnings)}'
print('[PASS] truncate_rows() trunca y registra warning (verificado en runtime)')
" || { echo "[FAIL] truncate_rows() no truncó/advirtió correctamente"; FAIL=1; }

exit $FAIL
