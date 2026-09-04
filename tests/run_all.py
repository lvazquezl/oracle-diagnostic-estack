#!/usr/bin/env python3
"""Portable test runner for tests/test_*.sh (# 43 OPTIONAL PYTHON TEST RUNNER).

Standard-library only, no third-party dependencies. This is a convenience
wrapper for environments where invoking tests/run-all.sh directly is
inconvenient (e.g. a Windows workstation shell that isn't Git Bash) — it
still requires a `bash` executable on PATH to actually execute the test
scripts, since the tests themselves are bash, not Python. This script does
NOT replace tests/run-all.sh; both must report the same pass/fail set for
the same tree, and run-all.sh remains the primary/canonical runner referenced
by CI and docs.

Usage: python3 tests/run_all.py
Exit code: 0 if all tests passed, 1 if at least one failed or bash/tests
were not found.
"""
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    tests_dir = Path(__file__).resolve().parent
    bash = shutil.which("bash")
    if bash is None:
        print("[FAIL] no se encontró 'bash' en PATH — instale Git for Windows, "
              "WSL, o ejecute en Linux/CI (ver docs/PHASE_3_COMPLETION_HARDENING.md#portability).")
        return 1

    test_scripts = sorted(tests_dir.glob("test_*.sh"))
    if not test_scripts:
        print(f"[FAIL] no se encontraron test_*.sh en {tests_dir}")
        return 1

    total = 0
    passed = 0
    failed_tests = []

    for script in test_scripts:
        total += 1
        print(f"=== {script.name} ===")
        result = subprocess.run([bash, str(script)])
        if result.returncode == 0:
            print(f"--- PASS: {script.name}")
            passed += 1
        else:
            print(f"--- FAIL: {script.name}")
            failed_tests.append(script.name)
        print()

    print("=" * 64)
    print(f"RESUMEN: {passed}/{total} tests OK, {len(failed_tests)} fallaron")
    if failed_tests:
        print("Tests fallidos:")
        for name in failed_tests:
            print(f"  - {name}")
    print("=" * 64)

    overall = 0 if not failed_tests else 1
    print("TODOS LOS TESTS PASARON" if overall == 0 else "AL MENOS UN TEST FALLÓ")
    return overall


if __name__ == "__main__":
    sys.exit(main())
