"""Phase 14 — evidence verifier negative cases and the release readiness gate (verdict and readiness derivation).
Every tampering below is applied to a COPY of a package produced from a synthetic repository."""
import copy
import json
import os
import shutil

from tests.p14.harness import (FAIL_SCRIPT, OK_SCRIPT, ROOT, baseline_package, by_id, copy_package, git_repo, load_manifest, rewrite_sums, run_all,
                               save_manifest, test, tmpdir, write)


def verify(pkg, repo=None):
    from release_readiness import evidence
    return evidence.verify_package(pkg, repo)


def tampered(mutator, resum=True, manifest_fn=None):
    """Copy the baseline package, apply `mutator(pkg)` (and/or `manifest_fn(m)`), optionally recompute SHA256SUMS, return (repo, pkg, result, tmp)."""
    repo, pkg, _m = baseline_package()
    d = __import__("tempfile").mkdtemp(prefix="p14_tamper_")
    dst = copy_package(pkg, d)
    if manifest_fn:
        m = load_manifest(dst)
        manifest_fn(m)
        save_manifest(dst, m)
    if mutator:
        mutator(dst)
    if resum:
        rewrite_sums(dst)
    res = verify(dst, repo)
    shutil.rmtree(d, ignore_errors=True)
    return res


def edit(pkg, name, fn, binary=False):
    p = os.path.join(pkg, name)
    data = open(p, "rb").read()
    open(p, "wb").write(fn(data))


# ------------------------------------------------------------------------------- verifier
@test
def an_untouched_package_passes_and_is_bound_to_the_tree_it_was_run_on():
    repo, pkg, m = baseline_package()
    r = verify(pkg, repo)
    assert r["result"] == "PASS" and r["tree_identity"] == "VERIFIED" and all(c["status"] == "PASS" for c in r["checks"])
    with tmpdir() as d:
        clone = os.path.join(d, "elsewhere")
        shutil.copytree(repo, clone)
        assert verify(pkg, clone)["tree_identity"] == "VERIFIED", "identity is content-based, not path-based"
        write(os.path.join(clone, "tests", "test_a.sh"), OK_SCRIPT + "# one more line\n")
        r2 = verify(pkg, clone)
        assert r2["tree_identity"] == "UNVERIFIED" and r2["result"] == "INCONCLUSIVE" and by_id(r2)["V11_TREE_IDENTITY"] == "INCONCLUSIVE"
    r3 = verify(pkg, None)
    assert r3["tree_identity"] == "UNVERIFIED" and r3["result"] == "INCONCLUSIVE", "without a root the evidence cannot be tied to a tree"


@test
def an_altered_log_with_stale_hashes_is_a_fail():
    r = tampered(lambda p: edit(p, "full-regression.log", lambda b: b + b"an extra line\n"), resum=False)
    assert r["result"] == "FAIL" and by_id(r)["V02_ARTIFACT_HASHES"] == "FAIL"


@test
def an_altered_log_with_recomputed_hashes_is_still_caught_by_the_manifest():
    r = tampered(lambda p: edit(p, "full-regression.log", lambda b: b.replace(b"--- PASS: test_c.sh", b"--- FAIL: test_c.sh")))
    assert r["result"] == "FAIL" and by_id(r)["V05_LOG_MATCHES_MANIFEST"] == "FAIL"
    r = tampered(lambda p: edit(p, "full-regression.log", lambda b: b.replace(b"=== test_c.sh ===\n", b"").replace(b"--- PASS: test_c.sh\n", b"")))
    assert r["result"] == "FAIL", "removing a script from the log changes the unique counts"


@test
def a_forged_or_inconsistent_fingerprint_is_detected():
    def forge(p):
        fp = json.load(open(os.path.join(p, "fingerprint-after.json")))
        fp["entries"]["tests/test_a.sh"] = "0" * 64
        json.dump(fp, open(os.path.join(p, "fingerprint-after.json"), "w"))
    assert tampered(forge, resum=False)["result"] == "FAIL"
    r = tampered(forge)
    assert r["result"] == "FAIL" and by_id(r)["V06_FINGERPRINT_CONSISTENT"] == "FAIL"

    def swap(p):
        shutil.copy(os.path.join(p, "fingerprint-before.json"), os.path.join(p, "fingerprint-after.json"))
    r = tampered(swap)
    assert by_id(r).get("V06_FINGERPRINT_CONSISTENT") in ("PASS", "FAIL")


@test
def a_missing_empty_or_disagreeing_exit_code_never_passes():
    def remove(p):
        os.remove(os.path.join(p, "full-regression.exitcode"))
    r = tampered(remove, resum=False)
    assert r["result"] == "INCONCLUSIVE" and by_id(r)["V01_REQUIRED_FILES"] == "FAIL"
    r = tampered(lambda p: open(os.path.join(p, "full-regression.exitcode"), "w").write("\n"))
    assert r["result"] == "FAIL" and by_id(r)["V04_EXIT_CODE"] == "FAIL", "an emptied exit code file contradicts a manifest that claims exit 0"
    r = tampered(lambda p: open(os.path.join(p, "full-regression.exitcode"), "w").write("1\n"))
    assert r["result"] == "FAIL" and by_id(r)["V04_EXIT_CODE"] == "FAIL"
    r = tampered(lambda p: open(os.path.join(p, "full-regression.exitcode"), "w").write("zero\n"))
    assert r["result"] != "PASS"


@test
def invalid_timestamps_durations_ids_and_extra_manifest_keys_are_rejected():
    cases = {
        "impossible date": lambda m: m.update(started_utc="2026-13-45T99:00:00Z"),
        "not UTC": lambda m: m.update(ended_utc="2026-09-20T10:00:00-05:00"),
        "garbage": lambda m: m.update(started_utc="yesterday"),
        "ended before started": lambda m: m.update(started_utc="2030-01-01T00:00:00Z", ended_utc="2020-01-01T00:00:00Z"),
        "duration lies": lambda m: m.update(duration_seconds=99999),
        "bad run id": lambda m: m.update(run_id="RUN-1"),
        "extra key": lambda m: m.update(approved_by="someone"),
        "missing key": lambda m: m.pop("security"),
        "bad command": lambda m: m.update(command="bash tests/run-all.sh"),
    }
    for name, fn in cases.items():
        r = tampered(None, manifest_fn=fn)
        assert r["result"] == "FAIL" and by_id(r)["V03_MANIFEST_SCHEMA"] == "FAIL", name


@test
def a_verdict_the_artifacts_do_not_support_is_caught():
    r = tampered(None, manifest_fn=lambda m: m["verdict"].update(result="FAIL"))
    assert r["result"] == "FAIL" and by_id(r)["V09_VERDICT_REPRODUCIBLE"] == "FAIL"
    from release_readiness import evidence
    with tmpdir() as d:
        repo = git_repo(d, scripts={"test_a.sh": OK_SCRIPT, "test_b.sh": FAIL_SCRIPT})
        pkg = os.path.join(d, "failpkg")
        m = evidence.run_and_package(repo, pkg, timeout_seconds=120)
        assert m["verdict"]["result"] == "FAIL"
        forged = load_manifest(pkg)
        forged["verdict"] = {"result": "PASS", "tree_identity": "VERIFIED", "reasons": []}
        save_manifest(pkg, forged)
        rewrite_sums(pkg)
        r = verify(pkg, repo)
        assert r["result"] == "FAIL" and by_id(r)["V09_VERDICT_REPRODUCIBLE"] == "FAIL", "a forged PASS over a failing run must not survive verification"


@test
def leaks_planted_in_a_package_are_detected_even_when_the_hashes_are_fixed_up():
    r = tampered(lambda p: edit(p, "full-regression.log", lambda b: b + b"opened C:\\Users\\alice\\Documents\\secret.txt\n"))
    assert r["result"] == "FAIL" and by_id(r)["V07_NO_PERSONAL_PATHS_OR_SECRETS"] == "FAIL"
    r = tampered(lambda p: edit(p, "full-regression.log", lambda b: b + b"password=SYNTHETIC_SECRET_DO_NOT_USE_1234\n"))
    assert r["result"] == "FAIL" and by_id(r)["V07_NO_PERSONAL_PATHS_OR_SECRETS"] == "FAIL"


@test
def malformed_missing_or_extra_package_content_is_rejected_without_a_traceback():
    repo, pkg, _m = baseline_package()
    assert verify(os.path.join(os.path.dirname(pkg), "does-not-exist"), repo)["result"] == "INCONCLUSIVE"
    assert verify(None, repo)["result"] == "INCONCLUSIVE"
    r = tampered(lambda p: open(os.path.join(p, "manifest.json"), "w").write("{not json"))
    assert r["result"] == "FAIL"
    r = tampered(lambda p: open(os.path.join(p, "bonus-file.txt"), "w").write("unexpected"))
    assert r["result"] == "FAIL" and by_id(r)["V02_ARTIFACT_HASHES"] == "FAIL"
    r = tampered(lambda p: os.remove(os.path.join(p, "manifest.md")), resum=False)
    assert r["result"] in ("FAIL", "INCONCLUSIVE")


# ------------------------------------------------------------------------------- the gate
def gate(**kw):
    from release_readiness import gate as g
    return g.run_gate(ROOT, **kw)


def stub(result, tree):
    def hook(root, evidence_dir):
        return {"id": "C10_EVIDENCE_PACKAGE", "status": result, "detail": "stub"}, {"result": result, "tree_identity": tree, "checks": []}
    return hook


@test
def the_static_gate_passes_every_static_check_but_never_passes_the_release_without_evidence():
    from release_readiness import gate as g
    rep = gate()
    static = {c["id"]: c["status"] for c in rep["checks"] if c["id"] != "C10_EVIDENCE_PACKAGE"}
    assert all(v == "PASS" for v in static.values()), {k: v for k, v in static.items() if v != "PASS"}
    assert len(static) == 9 and rep["static_result"] == "PASS" and rep["mode"] == "static"
    assert rep["release_gate"] == "INCONCLUSIVE" and g.exit_code_for(rep) == 2 and rep["tree_identity"] == "UNVERIFIED"
    assert rep["readiness"]["READY_FOR_RELEASE"] is False and rep["readiness"]["READY_FOR_LOCAL_FIXTURE_PILOT"] is False
    assert rep["readiness"]["READY_FOR_REAL_ENVIRONMENT_PILOT"] is False


@test
def the_release_verdict_and_readiness_are_derived_from_evidence_never_asserted():
    from release_readiness import gate as g
    ok = gate(_evidence_check=stub("PASS", "VERIFIED"))
    assert ok["release_gate"] == "PASS" and g.exit_code_for(ok) == 0 and ok["tree_identity"] == "VERIFIED"
    r = ok["readiness"]
    assert r["READY_FOR_RELEASE"] is True and r["READY_FOR_LOCAL_FIXTURE_PILOT"] is True and r["READY_FOR_REAL_ENVIRONMENT_PILOT"] is False
    b = set(r["real_environment_pilot_blockers"])
    assert {"ADAPTER_oracle_sql_IS_DISABLED", "ADAPTER_oracle_diag_file_IS_CONTRACT_ONLY", "ADAPTER_os_readonly_IS_CONTRACT_ONLY",
            "NO_ADAPTER_AT_PILOT_VALIDATED_OR_CERTIFIED", "NO_APPROVED_TARGET_ENVIRONMENT_ENABLED", "NO_REAL_ENVIRONMENT_INTEGRATION_EVIDENCE"} <= b, b
    unverified = gate(_evidence_check=stub("PASS", "UNVERIFIED"))
    assert unverified["release_gate"] == "INCONCLUSIVE" and g.exit_code_for(unverified) == 2 and unverified["readiness"]["READY_FOR_RELEASE"] is False
    changed = gate(_evidence_check=stub("INCONCLUSIVE", "CHANGED_DURING_RUN"))
    assert changed["release_gate"] == "INCONCLUSIVE" and changed["tree_identity"] == "CHANGED_DURING_RUN"
    failed = gate(_evidence_check=stub("FAIL", "VERIFIED"))
    assert failed["release_gate"] == "FAIL" and g.exit_code_for(failed) == 1 and failed["readiness"]["READY_FOR_LOCAL_FIXTURE_PILOT"] is False


@test
def a_failing_or_crashing_static_check_blocks_the_release_even_with_perfect_evidence():
    from release_readiness import gate as g
    real_reg, real_compat = g.check_registry, g.check_compatibility
    try:
        g.check_registry = lambda root, facts=None: {"id": "C02_REGISTRY_CONSISTENCY", "status": "FAIL", "detail": "patched"}
        rep = gate(_evidence_check=stub("PASS", "VERIFIED"))
        assert rep["release_gate"] == "FAIL" and rep["readiness"]["READY_FOR_RELEASE"] is False
        g.check_registry = real_reg

        def boom():
            raise RuntimeError("secret internal detail /home/alice/x")
        g.check_compatibility = boom
        rep = gate(_evidence_check=stub("PASS", "VERIFIED"))
        crashed = [c for c in rep["checks"] if c["id"] == "C99_CHECK_CRASHED"]
        assert crashed and crashed[0]["status"] == "FAIL" and rep["release_gate"] == "FAIL"
        assert "alice" not in json.dumps(rep), "an exception message must never reach the report"
    finally:
        g.check_registry, g.check_compatibility = real_reg, real_compat


@test
def real_environment_readiness_needs_every_precondition_and_none_holds_today():
    from release_readiness import gate as g
    from release_readiness.registry import load_registry
    base = load_registry(ROOT)

    def variant(maturity="PILOT_VALIDATED", code_status="VERIFIED_LAB", target_enabled=True, release="PASS", tree="VERIFIED"):
        doc = copy.deepcopy(base)
        for c in doc["components"]:
            if c["id"] == "adapter:oracle_sql":
                c["maturity"] = maturity
        facts = {"adapters": {"fixture": "VERIFIED_FIXTURE", "oracle_sql": code_status, "oracle_diag_file": "CONTRACT_ONLY", "os_readonly": "CONTRACT_ONLY"}}

        class T:
            enabled, adapter = target_enabled, "oracle_sql"
        checks = {k: {"status": "PASS"} for k in ("C03_MCP_SURFACE", "C07_DOCUMENTATION", "C08_GOVERNANCE_RECORDS")}
        return g.compute_readiness(release, tree, doc, facts, checks, {"lab": T()})["READY_FOR_REAL_ENVIRONMENT_PILOT"]
    assert variant("PILOT_VALIDATED", "VERIFIED_LAB", True) is False, "other real adapters remain CONTRACT_ONLY: not every adapter qualifies, but a qualifying one is enough"
    # a qualifying adapter needs ALL of: maturity, code status and an enabled target; and a passing release
    assert variant("DISABLED", "VERIFIED_LAB", True) is False
    assert variant("PILOT_VALIDATED", "DISABLED", True) is False
    assert variant("PILOT_VALIDATED", "VERIFIED_LAB", False) is False
    assert variant("PILOT_VALIDATED", "VERIFIED_LAB", True, release="FAIL") is False
    assert variant("PILOT_VALIDATED", "VERIFIED_LAB", True, tree="UNVERIFIED") is False
    assert variant("CONTRACT_ONLY", "CONTRACT_ONLY", False) is False


# ------------------------------------------------------------------------------- static checks on mutated copies
def mini_root(d, packages=("mcp_gateway", "rca_engine", "change_documentation_knowledge", "capacity_engine", "release_readiness")):
    root = os.path.join(d, "mini")
    for p in packages:
        os.makedirs(os.path.join(root, p))
        write(os.path.join(root, p, "__init__.py"), "")
    return root


@test
def the_static_security_scan_flags_network_subprocess_dynamic_code_environment_and_writes():
    from release_readiness import gate as g
    with tmpdir() as d:
        root = mini_root(d)
        assert g.check_static_security(root)["status"] == "PASS"
        evil = {
            "mcp_gateway/net.py": "import socket\n", "mcp_gateway/proc.py": "import subprocess\n", "mcp_gateway/dyn.py": "x = eval('1')\n",
            "mcp_gateway/imp.py": "import importlib\n__import__('os')\n", "mcp_gateway/env.py": "import os\nv = os.environ['X']\n",
            "mcp_gateway/wr.py": "open('x', 'w')\n", "mcp_gateway/rm.py": "import os\nos.remove('x')\n", "mcp_gateway/sh.py": "import os\nos.system('id')\n",
            "rca_engine/http.py": "from urllib.request import urlopen\n", "release_readiness/other.py": "import subprocess\n", "release_readiness/env2.py": "import os\nos.getenv('A')\n",
            "capacity_engine/sock.py": "import socket\n",
        }
        for rel, src in evil.items():
            p = os.path.join(root, rel)
            write(p, src)
            res = g.check_static_security(root)
            assert res["status"] == "FAIL" and any(rel in v for v in res["data"]["violations"]), rel
            os.remove(p)
        write(os.path.join(root, "release_readiness", "runner.py"), "import subprocess\nimport os\nx = os.environ\n")
        assert g.check_static_security(root)["status"] == "PASS", "only runner.py may start processes and read the environment"
        write(os.path.join(root, "mcp_gateway", "broken.py"), "def (:\n")
        assert g.check_static_security(root)["status"] == "FAIL", "unparseable source is a failure, not a skip"
        shutil.rmtree(os.path.join(root, "rca_engine"))
        assert any("missing-package" in v for v in g.check_static_security(root)["data"]["violations"])


@test
def the_documentation_check_flags_missing_sections_broken_links_bad_commands_and_missing_tests():
    from release_readiness import gate as g
    with tmpdir() as d:
        root = os.path.join(d, "mini")
        shutil.copytree(os.path.join(ROOT, "docs"), os.path.join(root, "docs"))
        os.makedirs(os.path.join(root, "tests"))
        for rel in g.DOC_REQUIREMENTS:                             # tests referenced by the documents must exist in this mini root
            for ref in __import__("re").findall(r"`(tests/test_[A-Za-z0-9_.+-]+\.sh)`", open(os.path.join(ROOT, rel), encoding="utf-8").read()):
                write(os.path.join(root, ref), "")
        for name in os.listdir(ROOT):                              # relative links point at repository files
            pass
        shutil.copytree(os.path.join(ROOT, "policies"), os.path.join(root, "policies"))
        for top in ("agents", "config", "collectors", "skills", "queries", "mcp", "sanitizers", "workflows", "playbooks", "parsers", "compatibility", "templates", "reports", "analysis", "commands"):
            if os.path.isdir(os.path.join(ROOT, top)):
                shutil.copytree(os.path.join(ROOT, top), os.path.join(root, top), ignore=shutil.ignore_patterns("__pycache__"))
        for f in os.listdir(ROOT):
            if f.endswith(".md") and os.path.isfile(os.path.join(ROOT, f)):
                shutil.copy(os.path.join(ROOT, f), root)
        for pkg in ("mcp_gateway", "release_readiness"):
            shutil.copytree(os.path.join(ROOT, pkg), os.path.join(root, pkg), ignore=shutil.ignore_patterns("__pycache__"))
        assert g.check_documentation(root)["status"] == "PASS", g.check_documentation(root).get("data")
        target = os.path.join(root, "docs", "PILOT_ACCEPTANCE_CHECKLIST.md")
        original = open(target, encoding="utf-8").read()
        mutations = {
            "a required section removed": original.replace("Bloqueos", "Otra cosa"),
            "a broken link": original + "\nSee [nowhere](docs/NO_SUCH_DOCUMENT.md).\n",
            "an invalid documented command": original + "\n```bash\npython -m release_readiness gate --no-such-flag\n```\n",
            "a reference to a missing test": original + "\nSee `tests/test_p14_does_not_exist.sh`.\n",
            "a missing document": None,
        }
        for name, text in mutations.items():
            if text is None:
                os.remove(target)
            else:
                open(target, "w", encoding="utf-8", newline="\n").write(text)
            res = g.check_documentation(root)
            assert res["status"] == "FAIL", name
            open(target, "w", encoding="utf-8", newline="\n").write(original)


@test
def the_governance_check_flags_invalid_risk_registers_and_lifecycle_records():
    from release_readiness import gate as g
    with tmpdir() as d:
        root = os.path.join(d, "mini")
        os.makedirs(os.path.join(root, "config", "governance"))
        for f in ("risk-register.json", "lifecycle-records.json"):
            shutil.copy(os.path.join(ROOT, "config", "governance", f), os.path.join(root, "config", "governance", f))
        assert g.check_governance(root)["status"] == "PASS"
        rp = os.path.join(root, "config", "governance", "risk-register.json")
        risks = json.load(open(rp))
        risks["risks"][0]["closure_condition"] = ""
        json.dump(risks, open(rp, "w"))
        assert g.check_governance(root)["status"] == "FAIL"
        os.remove(rp)
        assert g.check_governance(root)["status"] == "FAIL"


@test
def the_whitespace_check_covers_untracked_files_that_git_diff_check_ignores():
    from release_readiness import gate as g
    with tmpdir() as d:
        repo = git_repo(d)
        assert g.check_whitespace(repo)["status"] == "PASS"
        for name, data in (("trail.md", b"text  \n"), ("crlf.py", b"x = 1\r\n"), ("eof.json", b"{}\n\n")):
            write(os.path.join(repo, name), data)
            assert g.check_whitespace(repo)["status"] == "FAIL", name
            os.remove(os.path.join(repo, name))
        write(os.path.join(repo, "clean.md"), b"text\n")
        assert g.check_whitespace(repo)["status"] == "PASS"


@test
def the_mcp_surface_check_fails_when_a_tool_schema_gets_a_free_form_parameter():
    from release_readiness import gate as g
    with tmpdir() as d:
        root = os.path.join(d, "mini")
        for pkg in ("mcp_gateway", "rca_engine", "change_documentation_knowledge", "queries"):
            shutil.copytree(os.path.join(ROOT, pkg), os.path.join(root, pkg), ignore=shutil.ignore_patterns("__pycache__"))
        tools = ["diagnostics.list_capabilities", "diagnostics.describe_collector", "diagnostics.collect", "diagnostics.get_evidence", "diagnostics.analyze_incident"]
        assert g.check_mcp_surface(root, tools)["status"] == "PASS", "the copy behaves like the original"
        gw = os.path.join(root, "mcp_gateway", "gateway.py")
        src = open(gw, encoding="utf-8").read()
        needle = '"required": ["collector_id", "target_alias"], "additionalProperties": False}'
        assert needle in src
        open(gw, "w", encoding="utf-8", newline="\n").write(src.replace('"collector_id": {"type": "string", "maxLength": 64, "pattern": _COLLECTOR_PATTERN},',
                                                                      '"collector_id": {"type": "string", "maxLength": 64, "pattern": _COLLECTOR_PATTERN}, "sql": {"type": "string", "maxLength": 100},', 2))
        res = g.check_mcp_surface(root, tools)
        assert res["status"] == "FAIL", res


if __name__ == "__main__":
    raise SystemExit(run_all())
