#!/usr/bin/env bash
# tests/lib/rca_engine_e2e_helpers.sh — shared helpers for tests/test_rca_*.sh
# (PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING).
#
# Same portable-path strategy already proven and documented for capacity_engine (see
# tests/lib/capacity_engine_e2e_helpers.sh for the full root-cause writeup): native-Windows
# python3's open() does NOT get the Git-Bash/MSYS path translation that bash/ls/cat receive for
# free, so passing an absolute POSIX path like /tmp/... across the bash/python boundary breaks
# with FileNotFoundError under native-Windows python3, even though ls/cat see the same file fine.
# Reproduced and confirmed for rca_engine.cli during this hardening (identical failure mode to the
# one documented for capacity_engine.cli).
#
# FIX: rca_engine_run() below `cd`s into the working directory (a bash builtin the OS resolves
# correctly on every platform) and passes the CLI plain RELATIVE filenames — no absolute path with
# a guessed separator ever crosses the bash/python boundary.

# rca_engine_run <workdir> <fixture_rel> [rules_rel] [policy_rel] [out_rel] [markdown_rel] [manifest_rel] [token_map_rel]
#   Invokes rca_engine.cli with CWD=<workdir> and every path argument RELATIVE to it. Imports
#   rca_engine via PYTHONPATH=$ROOT (a POSIX path — verified to resolve correctly for import
#   machinery under both native-Windows and POSIX python3 in this environment, same as
#   capacity_engine_run()). Never masks a failure: stderr is captured to
#   <workdir>/.rca_cli_stderr.log, and the real exit code is left in $RCA_ENGINE_RUN_RC.
rca_engine_run() {
  local workdir="$1" fixture="$2" rules="${3:-}" policy="${4:-}" out="${5:-}" markdown="${6:-}" manifest="${7:-}" token_map="${8:-}"
  local stderr_file="$workdir/.rca_cli_stderr.log"
  local args=(--fixture "$fixture")
  [ -n "$rules" ] && args+=(--rules "$rules")
  [ -n "$policy" ] && args+=(--policy "$policy")
  [ -n "$out" ] && args+=(--out "$out")
  [ -n "$markdown" ] && args+=(--markdown "$markdown")
  [ -n "$manifest" ] && args+=(--manifest "$manifest")
  [ -n "$token_map" ] && args+=(--token-map "$token_map")
  ( cd "$workdir" && PYTHONPATH="$ROOT" python3 -m rca_engine.cli "${args[@]}" ) 2> "$stderr_file"
  RCA_ENGINE_RUN_RC=$?
  RCA_ENGINE_RUN_STDERR_FILE="$stderr_file"
  return $RCA_ENGINE_RUN_RC
}

# rca_engine_read_json <workdir> <file_rel> <python_expr...>
#   Runs a short python3 -c snippet with CWD=<workdir> so json.load('<file_rel>') resolves
#   correctly regardless of platform. Prints the snippet's stdout; caller checks $? and output.
rca_engine_read_json() {
  local workdir="$1"; shift
  ( cd "$workdir" && PYTHONPATH="$ROOT" python3 -c "$1" )
}
