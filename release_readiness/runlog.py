"""
release_readiness.runlog — independent parsing and judgement of a `tests/run-all.sh` log.

The runner prints, per script, `=== test_x.sh ===` ... `--- PASS: test_x.sh` | `--- FAIL: test_x.sh`, and a final
`RESUMEN: P/T tests OK, F fallaron`. This module does NOT trust that summary: it counts UNIQUE scripts itself and
compares. Inner `[PASS]` lines (one per assertion) are never counted as scripts.

Verdicts are fail-closed:
  INCONCLUSIVE — timeout, missing exit code, truncated log, summary/terminal mismatch, duplicate or orphan lines
  FAIL         — a failed script, non-zero exit, omitted scripts, `[SKIP]` lines
  PASS         — complete, consistent, exit 0, zero failures/skips/omissions
"""
from __future__ import annotations

import re

from .common import FAIL, INCONCLUSIVE, PASS

_HEADER = re.compile(r'^=== (test_[A-Za-z0-9_.+-]+\.sh) ===\Z')
_TERMINAL = re.compile(r'^--- (PASS|FAIL): (test_[A-Za-z0-9_.+-]+\.sh)\Z')
_SUMMARY = re.compile(r'^RESUMEN: ([0-9]+)/([0-9]+) tests OK, ([0-9]+) fallaron\Z')
_FINAL_OK = "TODOS LOS TESTS PASARON"
_FINAL_BAD = "AL MENOS UN TEST FALLÓ"
_SKIP = re.compile(r'^\[SKIP\]|^--- SKIP', re.IGNORECASE)


def parse(text: str) -> dict:
    headers, terminals, summary, final, skip_lines = [], [], None, None, 0
    for line in text.replace("\r\n", "\n").split("\n"):
        m = _HEADER.match(line)
        if m:
            headers.append(m.group(1))
            continue
        m = _TERMINAL.match(line)
        if m:
            terminals.append((m.group(2), m.group(1)))
            continue
        m = _SUMMARY.match(line)
        if m:
            summary = {"passed": int(m.group(1)), "total": int(m.group(2)), "failed": int(m.group(3))}
            continue
        if line in (_FINAL_OK, _FINAL_BAD):
            final = line
            continue
        if _SKIP.match(line):
            skip_lines += 1
    header_set, term_scripts = set(headers), [s for s, _ in terminals]
    status = {}
    for s, st in terminals:
        status.setdefault(s, []).append(st)
    return {
        "headers": headers, "unique_scripts": sorted(header_set),
        "duplicate_headers": sorted({h for h in headers if headers.count(h) > 1}),
        "passed_scripts": sorted(s for s, v in status.items() if v == ["PASS"]),
        "failed_scripts": sorted(s for s, v in status.items() if "FAIL" in v),
        "scripts_without_terminal": sorted(header_set - set(term_scripts)),
        "orphan_terminals": sorted(set(term_scripts) - header_set),
        "duplicate_terminals": sorted(s for s, v in status.items() if len(v) > 1),
        "skip_lines": skip_lines, "reported_summary": summary, "final_line": final,
    }


def judge(parsed: dict, exit_code, expected_scripts=None, timed_out: bool = False) -> tuple:
    """(verdict, reasons). `expected_scripts`: names of the test scripts that exist in the tree (from the fingerprint)."""
    reasons = []
    if timed_out:
        reasons.append("TIMEOUT")
    if exit_code is None and not timed_out:
        reasons.append("EXIT_CODE_MISSING")
    if not parsed["headers"]:
        reasons.append("LOG_EMPTY")
    rep = parsed["reported_summary"]
    if rep is None or parsed["final_line"] is None:
        reasons.append("LOG_TRUNCATED")
    if parsed["scripts_without_terminal"]:
        reasons.append("SCRIPTS_WITHOUT_TERMINAL_LINE")
    if parsed["orphan_terminals"] or parsed["duplicate_terminals"] or parsed["duplicate_headers"]:
        reasons.append("LOG_STRUCTURE_INCONSISTENT")
    verified_pass, verified_fail, unique = len(parsed["passed_scripts"]), len(parsed["failed_scripts"]), len(parsed["unique_scripts"])
    if rep is not None and (rep["total"] != unique or rep["passed"] != verified_pass or rep["failed"] != verified_fail):
        reasons.append("SUMMARY_MISMATCH")
    if any(r in reasons for r in ("TIMEOUT", "EXIT_CODE_MISSING", "LOG_EMPTY", "LOG_TRUNCATED", "SCRIPTS_WITHOUT_TERMINAL_LINE",
                                  "LOG_STRUCTURE_INCONSISTENT", "SUMMARY_MISMATCH")):
        return INCONCLUSIVE, reasons
    if expected_scripts is not None:
        omitted = sorted(set(expected_scripts) - set(parsed["unique_scripts"]))
        if omitted:
            reasons.append("TESTS_OMITTED")
    if verified_fail:
        reasons.append("TESTS_FAILED")
    if exit_code != 0:
        reasons.append("EXIT_CODE_NONZERO")
    if exit_code == 0 and verified_fail:
        reasons.append("EXIT_CODE_INCONSISTENT_WITH_FAILURES")
    if parsed["skip_lines"]:
        reasons.append("SKIPPED_TESTS_PRESENT")
    if reasons:
        return FAIL, reasons
    return PASS, []
