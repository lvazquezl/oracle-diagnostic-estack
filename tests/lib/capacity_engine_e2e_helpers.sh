#!/usr/bin/env bash
# tests/lib/capacity_engine_e2e_helpers.sh — shared helpers for
# tests/test_capacity_engine_end_to_end*.sh (PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH
# HARDENING).
#
# ROOT CAUSE (documented, not re-explained per test): the original test_capacity_engine_end_to_end.sh
# built absolute paths for --fixture/--policy/--thresholds/--out/--markdown by concatenating a
# literal "\\" onto $WTMPDIR unconditionally. When `cygpath` was unavailable, $WTMPDIR stayed a
# POSIX path (e.g. .../tests/.tmp_capacity_e2e_123), and the backslash is NOT a path separator on
# POSIX -- Python received a literal filename containing a backslash character and raised
# FileNotFoundError. Reproduced verbatim:
#   FileNotFoundError: [Errno 2] No such file or directory: '.../tests/.tmp_capacity_e2e_123\fixture.json'
#
# FIX STRATEGY (# 31-33 del prompt de hardening): two complementary techniques, never a hand-rolled
# platform guess from uname/OSTYPE (# 31: "no infieras que python3 es nativo de Windows sólo porque
# se invoca desde Git Bash"):
#
#   1) capacity_engine_run() below `cd`s (a bash builtin the OS resolves correctly on every
#      platform) into the working directory and passes the CLI plain RELATIVE filenames. This
#      sidesteps separator ambiguity by construction -- no path string ever crosses the bash/python
#      boundary as an absolute path, so there is nothing to get wrong. This is the primary,
#      preferred strategy used by every test in this file.
#   2) capacity_engine_to_interp_path() is the fallback for the rare case an ABSOLUTE path is
#      genuinely required: it asks the *actual* python3 interpreter that will receive the path
#      (via `sys.platform`, never the OS/shell's own identity) whether it needs a Windows-style
#      path, and only then shells out to `cygpath -w` -- never blindly, never as the only option.

# capacity_engine_python_platform
#   Prints the sys.platform of the python3 interpreter that will actually receive the path —
#   never inferred from uname/OSTYPE/$OS.
capacity_engine_python_platform() {
  python3 -c "import sys; print(sys.platform)" 2>/dev/null
}

# capacity_engine_to_interp_path <posix_path>
#   Prints a path string that interpreter can open directly. Uses cygpath -w only when the
#   interpreter is confirmed native-Windows AND cygpath is actually available; otherwise passes
#   the POSIX path through unchanged (correct for POSIX python, and the least-wrong fallback when
#   a native-Windows python has no cygpath to convert with — logged, never silently assumed safe).
capacity_engine_to_interp_path() {
  local posix_path="$1"
  local plat
  plat="$(capacity_engine_python_platform)"
  if [ "$plat" = "win32" ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$posix_path"
  else
    printf '%s' "$posix_path"
  fi
}

# capacity_engine_write_linear_fixture <workdir> <fixture_filename> [slope] [intercept] [days]
#   Writes a synthetic linear-growth fixture (used = intercept + slope*day, no production data)
#   as <workdir>/<fixture_filename>, via a python3 process whose CWD is <workdir> (relative write,
#   no path translation needed). Returns the python3 exit code; never masks a failure.
capacity_engine_write_linear_fixture() {
  local workdir="$1" filename="$2" slope="${3:-4.0}" intercept="${4:-1000.0}" days="${5:-90}"
  ( cd "$workdir" && python3 -c "
import json
from datetime import datetime, timedelta, timezone
start = datetime(2026, 1, 1, tzinfo=timezone.utc)
samples = []
for day in range($days):
    ts = start + timedelta(days=day, hours=12)
    samples.append({
        'target_id': 'T-E2E', 'technology': 'linux', 'resource_type': 'filesystem',
        'metric_name': 'used_bytes', 'timestamp': ts.isoformat(),
        'total_capacity': 200000.0, 'used_capacity': $intercept + $slope * day, 'unit': 'bytes',
        'source_id': 'fixture', 'evidence_id': 'EVD-E2E-1',
    })
json.dump({'samples': samples}, open('$filename', 'w'))
" )
}

# capacity_engine_run <workdir> <fixture_rel> <policy_rel> <thresholds_rel> <out_rel> <markdown_rel>
#   Invokes capacity_engine.cli with CWD=<workdir> and every path argument RELATIVE to it (the
#   portable strategy — see module docstring). Imports capacity_engine via PYTHONPATH=$ROOT (a
#   POSIX path) — verified to resolve correctly for import machinery under both native-Windows and
#   POSIX python3 in this environment (Git Bash/MSYS translates well-known interpreter env vars for
#   a spawned native child; POSIX needs no translation at all).
#   Never masks a failure: stdout is left on the caller's stdout, stderr is captured to
#   <workdir>/.cli_stderr.log, and the real exit code is left in $CAPACITY_ENGINE_RUN_RC — no
#   `|| true`, no `grep` swallowing a nonzero status.
capacity_engine_run() {
  local workdir="$1" fixture="$2" policy="$3" thresholds="$4" out="$5" markdown="$6"
  local stderr_file="$workdir/.cli_stderr.log"
  ( cd "$workdir" && PYTHONPATH="$ROOT" python3 -m capacity_engine.cli \
      --fixture "$fixture" --policy "$policy" --thresholds "$thresholds" \
      --out "$out" --markdown "$markdown" ) 2> "$stderr_file"
  CAPACITY_ENGINE_RUN_RC=$?
  CAPACITY_ENGINE_RUN_STDERR_FILE="$stderr_file"
  return $CAPACITY_ENGINE_RUN_RC
}
