#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 68/61.
# UNIFIED_AUDIT_TRAIL/DBA_AUDIT_TRAIL nunca se consultan completos por defecto — siempre filtros.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q1="$ROOT/queries/security/Q-SEC-UNIFIED-AUDIT-TRAIL-001.md"
Q2="$ROOT/queries/security/Q-SEC-TRADITIONAL-AUDIT-001.md"

# CHG-ESTACK-SEC-QUERIES-001: the bound is checked in the certified SQL itself (every block), not in prose: a fixed
# time window of at most 31 days, a row cap of at most 500, aggregation (counts, never raw audit rows) and no SQL text.
for Q in "$Q1" "$Q2"; do
  if python3 - "$Q" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"```sql\n(.*?)```", text, re.S)
ok = bool(blocks)
for sql in blocks:
    win = re.search(r"(?i)(SYSDATE|SYSTIMESTAMP)\s*-\s*(INTERVAL\s*'(\d+)'\s*DAY|(\d+)\b)", sql)
    days = int(win.group(3) or win.group(4)) if win else 0
    cap = re.search(r"(?i)(FETCH\s+FIRST\s+(\d+)\s+ROWS\s+ONLY|ROWNUM\s*<=\s*(\d+)\b)", sql)
    rows = int(cap.group(2) or cap.group(3)) if cap else 0
    ok &= 1 <= days <= 31 and 1 <= rows <= 500
    ok &= bool(re.search(r"(?i)GROUP\s+BY", sql)) and not re.search(r"(?i)sql_text|sql_binds|(?<![:\w]):[a-z_]+", sql)
sys.exit(0 if ok else 1)
PY
  then
    echo "[PASS] $(basename "$Q") acota por tiempo (<= 31 días) y filas (<= 500), agrega y no expone texto SQL ni binds"
  else
    echo "[FAIL] $(basename "$Q") no acota por tiempo/filas o devuelve filas crudas"; FAIL=1
  fi
done

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q1")
grep -qi "^\s*SELECT \* FROM\s*unified_audit_trail\s*;" <<<"$block" \
  && { echo "[FAIL] Q-SEC-UNIFIED-AUDIT-TRAIL-001 selecciona la tabla completa sin filtro"; FAIL=1; } \
  || echo "[PASS] Q-SEC-UNIFIED-AUDIT-TRAIL-001 no selecciona la tabla completa sin filtro"

exit $FAIL
