"""
tests/p14/harness.py — helpers for the Phase 14 (production readiness & governance) tests.

Re-exports the Phase 13 MCP clients/assertion runner and adds:
  git_repo()        a SYNTHETIC git repository in a temp directory (never the real repository) with the real
                    tests/run-all.sh and tiny test scripts, so the packager/verifier run for real in seconds
  baseline_package() one packaged run of that synthetic repository (cached per process) and tamper helpers
Everything here uses synthetic data; nothing touches Oracle, the network or the real repository's history.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from tests.p13.harness import (  # noqa: F401  (re-exported for the check modules)
    MARKER, MARKER2, PRIMARY, ROOT, InProcClient, ProcClient, Skip, all_output, default_targets, leaks, make_fixture_dir,
    make_targets_file, run_all as _run_all, test, tmpdir, write_json,
)

if os.environ.get("P14_TIMING") == "1":
    os.environ["P13_TIMING"] = "1"
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

GIT_ENV = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
OK_SCRIPT = "#!/usr/bin/env bash\necho \"[PASS] synthetic assertion in $(pwd)\"\nexit 0\n"
FAIL_SCRIPT = "#!/usr/bin/env bash\necho \"[FAIL] synthetic assertion\"\nexit 1\n"


def run_all() -> int:
    return _run_all()


def sh(repo, *args, check=True):
    p = subprocess.run(["git", *args], cwd=repo, capture_output=True, env=GIT_ENV)
    if check and p.returncode != 0:
        raise AssertionError("git failed: " + " ".join(args))
    return p


def write(path, data, binary=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data if isinstance(data, bytes) else data.encode("utf-8"))


def git_repo(d, scripts=None, files=None, commit=True, gitignore="ignored/\n__pycache__/\n"):
    """Create <d>/repo as a real git repository containing tests/run-all.sh (the real one) and tests/test_*.sh."""
    repo = os.path.join(d, "repo")
    os.makedirs(os.path.join(repo, "tests"))
    sh(repo, "init", "-q", ".")
    for k, v in (("user.email", "synthetic@example.invalid"), ("user.name", "synthetic"), ("core.autocrlf", "false"), ("commit.gpgsign", "false")):
        sh(repo, "config", k, v)
    with open(os.path.join(ROOT, "tests", "run-all.sh"), "rb") as f:
        write(os.path.join(repo, "tests", "run-all.sh"), f.read().replace(b"\r\n", b"\n"))
    for name, body in (scripts if scripts is not None else {"test_a.sh": OK_SCRIPT, "test_b.sh": OK_SCRIPT, "test_c.sh": OK_SCRIPT}).items():
        write(os.path.join(repo, "tests", name), body)
    write(os.path.join(repo, ".gitignore"), gitignore)
    for rel, body in (files or {}).items():
        write(os.path.join(repo, rel), body)
    if commit:
        sh(repo, "add", "-A")
        sh(repo, "commit", "-q", "-m", "synthetic")
    return repo


_BASELINE = {}


def baseline_package(security=("tests/test_a.sh",)):
    """(repo, package_dir, manifest) for one PASSing run of a synthetic repository, cached for the process lifetime."""
    if "v" not in _BASELINE:
        from release_readiness import evidence
        d = tempfile.mkdtemp(prefix="p14_base_")
        repo = git_repo(d)
        pkg = os.path.join(d, "pkg")
        manifest = evidence.run_and_package(repo, pkg, security_scripts=security, timeout_seconds=180)
        _BASELINE["v"] = (repo, pkg, manifest, d)
    repo, pkg, manifest, _d = _BASELINE["v"]
    return repo, pkg, manifest


def copy_package(pkg, into):
    dst = os.path.join(into, "pkgcopy")
    shutil.copytree(pkg, dst)
    return dst


def rewrite_sums(pkg):
    """Recompute SHA256SUMS.txt after a deliberate tampering (so the tamper is only visible to deeper checks)."""
    from release_readiness.common import sha256_file
    names = sorted(n for n in os.listdir(pkg) if n != "SHA256SUMS.txt")
    with open(os.path.join(pkg, "SHA256SUMS.txt"), "w", encoding="utf-8", newline="\n") as f:
        for n in names:
            f.write(f"{sha256_file(os.path.join(pkg, n))}  {n}\n")


def load_manifest(pkg):
    with open(os.path.join(pkg, "manifest.json"), encoding="utf-8") as f:
        return json.load(f)


def save_manifest(pkg, m):
    with open(os.path.join(pkg, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, indent=2, sort_keys=True)
        f.write("\n")


def by_id(result):
    return {c["id"]: c["status"] for c in result["checks"]}


def cleanup_baseline():
    if "v" in _BASELINE:
        shutil.rmtree(_BASELINE["v"][3], ignore_errors=True)
        _BASELINE.clear()


import atexit  # noqa: E402
atexit.register(cleanup_baseline)
