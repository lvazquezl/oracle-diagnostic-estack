#!/usr/bin/env bash
# CHG-ESTACK-AWR-BIND-QUERIES-001. DBA_HIST_SYS_TIME_MODEL and DBA_HIST_SYSTEM_EVENT hold values cumulative since
# instance startup: every certified AWR query that reads them must compute deltas per startup (LAG or MAX - MIN,
# partitioned by startup_time), never SUM the raw counters; join DBA_HIST_SNAPSHOT on dbid; turn interval lengths into
# seconds through CAST AS DATE (an INTERVAL times 86400 is still an INTERVAL); and keep con_dbid only in 12.1+ blocks.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for Q in "$ROOT"/queries/performance/*/*.md; do
  grep -qiE 'dba_hist_sys_time_model|dba_hist_system_event' "$Q" || continue
  grep -qiE '^\s*(from|join)\s+dba_hist_(sys_time_model|system_event)\b' "$Q" || continue
  if out=$(python3 - "$Q" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
fm = text.split("\n---\n", 1)[0]
labels = re.findall(r'sql_block:\s*"([^"]+)"', fm)
mins = {l: m for l, m in zip(labels, re.findall(r'oracle_versions:\s*\{min:\s*"([\d.]+)"', fm))}
blocks = re.findall(r"# Statement / procedure \(read-only\)(?: — (.*?))?\n\n```sql\n(.*?)```", text, re.S)
bad = []
for label, sql in blocks:
    s = re.sub(r"--[^\n]*", "", sql).lower()
    name = label or "single"
    if re.search(r"sum\s*\(\s*\w+\.(value|time_waited_micro(_fg)?|total_waits(_fg)?)\b", s):
        bad.append(f"{name}: SUM over a cumulative counter")
    lags = re.findall(r"lag\s*\(.*?\)\s*over\s*\(([^)]*)\)", s, re.S)
    if lags:
        if not all(re.search(r"partition\s+by[^)]*startup_time", w) for w in lags):
            bad.append(f"{name}: a LAG not partitioned by startup_time")
    elif not (re.search(r"max\s*\(", s) and re.search(r"group\s+by[^;]*startup_time", s)):
        bad.append(f"{name}: no per-startup delta")
    if re.search(r"join\s+dba_hist_snapshot", s) and not re.search(r"s\.dbid\s*=\s*\w+\.dbid", s):
        bad.append(f"{name}: snapshot join without dbid")
    if re.search(r"(end|begin)_interval_time\s*\)\s*\*\s*86400", s) and "as date" not in s:
        bad.append(f"{name}: INTERVAL multiplied by 86400")
    m = mins.get(label)
    if "con_dbid" in s and m and tuple(map(int, m.split("."))) < (12, 1):
        bad.append(f"{name}: con_dbid before 12.1")
print("; ".join(bad))
sys.exit(1 if bad or not blocks else 0)
PY
  ); then
    echo "[PASS] $(basename "$Q") calcula deltas por arranque, une por dbid y da segundos numéricos"
  else
    echo "[FAIL] $(basename "$Q") — $out"; FAIL=1
  fi
done

exit $FAIL
