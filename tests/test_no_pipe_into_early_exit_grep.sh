#!/usr/bin/env bash
# CHG-ESTACK-TEST-SIGPIPE-001: with `set -o pipefail`, `PRODUCER | grep -q ...` (or `grep -m N`) can fail at random:
# grep exits on the first match, the producer gets SIGPIPE writing the rest, and the whole pipeline reports failure
# (seen on the macOS CI runner: "echo: write error: Broken pipe"). Tests must use `grep -q ... <<<"$var"` or
# `PRODUCER | grep -c ... >/dev/null` (reads all input, same exit status). This guard keeps the pattern out.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import glob, re, sys
BAD = re.compile(r'(?<!\|)\|\s*(?!\|)grep\s+(-[A-Za-z]*q[A-Za-z]*|-m\s*\d+|-[A-Za-z]*m\d*)\b')
hits = []
for f in sorted(glob.glob("tests/*.sh")):
    if f.endswith("test_no_pipe_into_early_exit_grep.sh"):
        continue                                    # its own self-check strings
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        code = line.split(" #", 1)[0] if not line.lstrip().startswith("#") else ""
        if BAD.search(code):
            hits.append(f"{f}:{n}: {line.strip()[:140]}")
for h in hits:
    print("[FAIL] pipe into an early-exit grep: " + h)
if hits:
    sys.exit(1)
assert BAD.search('echo "$x" | grep -qi foo') and BAD.search("cmd | grep -m1 x") and not BAD.search('a || grep -q x f') \
    and not BAD.search('grep -q x <<<"$v"') and not BAD.search("cmd | grep -c x >/dev/null"), "guard self-check"
print("[PASS] no test pipes into grep -q / grep -m (SIGPIPE-safe under pipefail)")
PY
