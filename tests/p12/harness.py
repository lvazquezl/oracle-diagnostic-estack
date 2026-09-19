"""
tests/p12/harness.py — tiny assertion runner + helpers for the Phase 12 functional tests
(change_documentation_knowledge). Each tests/test_p12_*.sh wrapper runs one tests/p12/check_*.py module
built on this harness; every check asserts on REAL CLI/JSON/Markdown/KB results, never on grep of docs.

Synthetic authorization records: the engine never creates approvals (by design). The tests below need a
record to prove the engine ACCEPTS a matching one and REJECTS a wrong one, so `make_auth()` builds a
clearly synthetic record (reviewer `REV-TESTREV…`) OUTSIDE the engine, from the digest the engine printed.
It is test data, not an approval of anything real.
"""
import contextlib
import json
import os
import subprocess
import sys
import tempfile
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)
RCA_FIX = os.path.join(ROOT, "tests", "fixtures", "rca_engine")
P12_FIX = os.path.join(ROOT, "tests", "fixtures", "p12")
T = "2026-03-11T16:00:00Z"
MARKER = "SYNTHETIC_SECRET_DO_NOT_USE"
MARKER2 = "SYNTHETIC-SECRET-DO-NOT-USE"

_TESTS = []


class Skip(Exception):
    pass


def test(fn):
    _TESTS.append(fn)
    return fn


def run_all() -> int:
    """Runs exactly the checks THIS module defined (snapshot taken before the first check runs): importing another
    check module for a helper can never make a suite execute foreign cases. Opt-in diagnostics: set P12_TIMING=1 to
    print `[TIME] <case> <seconds>` per case (case name and duration only — never arguments, paths or content)."""
    import time
    cases = list(_TESTS)
    timing = os.environ.get("P12_TIMING") == "1"
    failed = 0
    for fn in cases:
        t0 = time.time()
        try:
            fn()
            print(f"[PASS] {fn.__name__}")
        except Skip as e:
            print(f"[SKIP] {fn.__name__}: {e}")
        except AssertionError as e:
            failed += 1
            print(f"[FAIL] {fn.__name__}: {e}")
        except Exception:
            failed += 1
            print(f"[FAIL] {fn.__name__}: unexpected exception")
            traceback.print_exc()
        if timing:
            print(f"[TIME] {fn.__name__} {time.time() - t0:.2f}s")
    print(f"{len(cases) - failed}/{len(cases)} checks OK")
    return 1 if failed else 0


@contextlib.contextmanager
def tmpdir():
    d = tempfile.mkdtemp(prefix="p12_")
    try:
        yield d
    finally:
        import shutil
        shutil.rmtree(d, ignore_errors=True)


def cli(*args, cwd=None):
    env = dict(os.environ)
    env["PYTHONPATH"] = ROOT
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run([sys.executable, "-m", "change_documentation_knowledge.cli", *args], cwd=cwd,
                       capture_output=True, text=True, encoding="utf-8", env=env, timeout=120)
    return p.returncode, p.stdout, p.stderr


def rca_cli(*args, cwd=None):
    env = dict(os.environ)
    env["PYTHONPATH"] = ROOT
    p = subprocess.run([sys.executable, "-m", "rca_engine.cli", *args], cwd=cwd, capture_output=True, text=True,
                       encoding="utf-8", env=env, timeout=120)
    return p.returncode, p.stdout, p.stderr


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2)


def fx(name):
    return os.path.join(RCA_FIX, name)


def p12fx(name):
    return os.path.join(P12_FIX, name)


def rca_result(fixture_path, rules_path=None):
    from rca_engine.engine import run_rca
    result, _token_map = run_rca(read_json(fixture_path), rules_path)
    return result


def catalog(rules_path=None):
    from rca_engine.engine import DEFAULT_RULES_PATH
    from rca_engine.rules import load_rules
    return load_rules(rules_path or DEFAULT_RULES_PATH)


def view_of(fixture_path, rules_path=None):
    from change_documentation_knowledge.schema import adapt_rca_result
    return adapt_rca_result(rca_result(fixture_path, rules_path), catalog(rules_path))


def all_text(directory) -> str:
    parts = []
    for dp, _dn, fns in os.walk(directory):
        for fn in sorted(fns):
            with open(os.path.join(dp, fn), encoding="utf-8", errors="replace") as f:
                parts.append(f.read())
    return "\n".join(parts)


def make_auth(artifact_id, digest, version="1", reviewer="REV-TESTREV01", decision="APPROVED",
              auth_id="AUTH-T0001", at="2026-03-12T09:00:00Z", notes="synthetic test record"):
    return {"authorization_id": auth_id, "artifact_id": artifact_id, "decision": decision, "reviewer_id": reviewer,
            "decision_at_utc": at, "artifact_digest": digest, "version": version, "review_notes_sanitized": notes}


def expect_error(fn, code):
    from change_documentation_knowledge.common import AdvisoryError
    try:
        fn()
    except AdvisoryError as e:
        assert e.code == code, f"expected {code}, got {e.code}"
        return e
    raise AssertionError(f"expected {code}, no error raised")


def make_published(root, c=None, first_auth=("AUTH-T0001", "AUTH-T0002"), reviewer="REV-TESTREV01"):
    """Drive one candidate CANDIDATE -> DRAFT -> PENDING_HUMAN_REVIEW -> APPROVED_BY_HUMAN -> PUBLISHED in the KB at
    `root` using SYNTHETIC external authorization records built here (outside the engine). Shared helper so that no
    check module has to import another one (which used to register/execute foreign cases)."""
    from change_documentation_knowledge import kb_store
    from change_documentation_knowledge.knowledge import build_kb_candidate
    if c is None:
        c = build_kb_candidate(view_of(fx("positive_confirmed.json")), catalog(), read_json(p12fx("change_context_all_pass.json")),
                               read_json(p12fx("candidate_input_basic.json")), T)
    r = kb_store.add_candidate(root, c, T)
    kb_id, v = r["kb_id"], r["version"]
    kb_store.transition(root, kb_id, v, "DRAFT", "2026-03-11T16:01:00Z")
    kb_store.transition(root, kb_id, v, "PENDING_HUMAN_REVIEW", "2026-03-11T16:02:00Z")
    digest = kb_store.load_manifest(root)["entries"][kb_id]["versions"][v]["digest"]
    kb_store.transition(root, kb_id, v, "APPROVED_BY_HUMAN", "2026-03-12T09:01:00Z",
                        make_auth(kb_id, digest, v, reviewer, "APPROVED", first_auth[0], "2026-03-12T09:00:00Z"))
    kb_store.transition(root, kb_id, v, "PUBLISHED", "2026-03-12T09:11:00Z",
                        make_auth(kb_id, digest, v, reviewer, "APPROVED", first_auth[1], "2026-03-12T09:10:00Z"))
    return kb_id, v, digest
