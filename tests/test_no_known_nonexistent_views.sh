#!/usr/bin/env bash
# CHG-ESTACK-ORA19C-LAB-007: views confirmed NOT to exist (Oracle documentation 19c + real 19c catalog through
# Q-DICT-VERIFY) must never appear in a certified SQL block again. tests/test_sql_static_validator.sh is permissive
# for views absent from the dictionary by design, so removing them from views.yaml alone would not stop a comeback.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import glob, re, sys
from mcp_gateway import catalog
NONEXISTENT = {                       # name → evidence
    "GV$ASM_INSTANCE": "not in ASM Administrator's Guide 19c; VIEW_NOT_FOUND in the 19c lab (ASM in use)",
    "V$ASM_INSTANCE": "same view family as GV$ASM_INSTANCE",
    "GV$GCS_STATISTICS": "no page in Oracle Database Reference 19c; VIEW_NOT_FOUND in the 19c lab",
    "V$GCS_STATISTICS": "no page in Oracle Database Reference 19c",
}
fail = []
for f in glob.glob("queries/**/Q-*.md", recursive=True):
    if f.startswith("queries/oracle/dictionary/"):
        continue                      # generated from views.yaml, which no longer lists them
    for block in catalog.sql_blocks(open(f, encoding="utf-8").read()):
        code = re.sub(r"--[^\n]*", "", block).upper()
        for v in NONEXISTENT:
            if re.search(r"(?<![A-Z0-9_$#])" + re.escape(v) + r"(?![A-Z0-9_$#])", code):
                fail.append(f"{f}: uses {v} ({NONEXISTENT[v]})")
dictionary = open("compatibility/oracle-dictionary/views.yaml", encoding="utf-8").read()
for v in NONEXISTENT:
    if re.search(r"^  " + re.escape(v) + r":\s*$", dictionary, re.M):
        fail.append(f"compatibility/oracle-dictionary/views.yaml declares {v}")
for x in fail:
    print("[FAIL] " + x)
if fail:
    sys.exit(1)
print("[PASS] no certified SQL block or dictionary entry uses a view confirmed not to exist (%d names)" % len(NONEXISTENT))
PY
