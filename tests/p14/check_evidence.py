"""Phase 14 — tree fingerprint, run-log parser and the evidence packager, exercised on SYNTHETIC git repositories
(a temp directory, never the real repository)."""
import os
import time

from tests.p14.harness import (FAIL_SCRIPT, OK_SCRIPT, ROOT, baseline_package, by_id, git_repo, load_manifest, run_all, sh, test, tmpdir, write)

RUNNER_DONE = "\n".join(["RESUMEN: {p}/{t} tests OK, 0 fallaron", "TODOS LOS TESTS PASARON", ""])


def pack(d, scripts=None, files=None, runner=None, security=(), timeout=120, pre=None):
    from release_readiness import evidence
    repo = git_repo(d, scripts=scripts, files=files)
    if pre:
        pre(repo)
    out = os.path.join(d, "pkg")
    kw = {"runner_rel": runner} if runner else {}
    m = evidence.run_and_package(repo, out, security_scripts=security, timeout_seconds=timeout, **kw)
    return repo, out, m


def verify(pkg, repo):
    from release_readiness import evidence
    return evidence.verify_package(pkg, repo)


# ------------------------------------------------------------------------------------------ fingerprint
@test
def the_fingerprint_is_deterministic_content_sensitive_and_independent_of_head():
    from release_readiness import fingerprint
    with tmpdir() as d:
        repo = git_repo(d, files={"data.txt": "one\n", "ignored/x.txt": "ignored\n"})
        a, b = fingerprint.take(repo), fingerprint.take(repo)
        assert a["aggregate_sha256"] == b["aggregate_sha256"] and fingerprint.verify_self_consistency(a)
        write(os.path.join(repo, "ignored", "y.txt"), "still ignored\n")
        assert fingerprint.take(repo)["aggregate_sha256"] == a["aggregate_sha256"], "ignored files are not part of the tree identity"
        write(os.path.join(repo, "data.txt"), "two\n")
        c = fingerprint.take(repo)
        assert c["aggregate_sha256"] != a["aggregate_sha256"] and fingerprint.diff(a, c)["changed"] == ["data.txt"]
        write(os.path.join(repo, "new_untracked.txt"), "x\n")
        e = fingerprint.take(repo)
        assert fingerprint.diff(c, e)["added"] == ["new_untracked.txt"]
        sh(repo, "add", "-A")
        sh(repo, "commit", "-q", "-m", "second")
        assert fingerprint.take(repo)["aggregate_sha256"] == e["aggregate_sha256"], "committing the same files must not change the identity"
        os.remove(os.path.join(repo, "data.txt"))
        f = fingerprint.take(repo)
        assert f["entries"]["data.txt"] == "DELETED" and f["deleted_count"] == 1 and f["aggregate_sha256"] != e["aggregate_sha256"]


@test
def a_hand_edited_fingerprint_is_detected():
    from release_readiness import fingerprint
    with tmpdir() as d:
        fp = fingerprint.take(git_repo(d))
        assert fingerprint.verify_self_consistency(fp)
        forged = dict(fp, entries=dict(fp["entries"], **{"tests/test_a.sh": "0" * 64}))
        assert not fingerprint.verify_self_consistency(forged)
        assert not fingerprint.verify_self_consistency(dict(fp, aggregate_sha256="0" * 64))
        assert not fingerprint.verify_self_consistency({"entries": "x"})


@test
def symlinks_contribute_their_target_text_and_are_never_followed():
    from release_readiness import fingerprint
    with tmpdir() as d:
        repo = git_repo(d)
        link = os.path.join(repo, "link.txt")
        write(link, "content that must not be hashed\n")
        real_islink, real_readlink = os.path.islink, os.readlink
        fingerprint.os.path.islink = lambda p: p.endswith("link.txt") or real_islink(p)          # simulate a symlink portably
        fingerprint.os.readlink = lambda p: "../outside/target.txt" if p.endswith("link.txt") else real_readlink(p)
        try:
            fp = fingerprint.take(repo)
            assert fp["entries"]["link.txt"].startswith("symlink:")
            write(link, "the pointed-to content changed\n")
            assert fingerprint.take(repo)["aggregate_sha256"] == fp["aggregate_sha256"], "only the link text is part of the identity"
        finally:
            fingerprint.os.path.islink, fingerprint.os.readlink = real_islink, real_readlink
        real = os.path.join(d, "real_link.txt")
        try:                                   # a genuine symlink too, when this system permits creating one
            os.symlink(os.path.join(d, "outside.txt"), real)
        except (OSError, NotImplementedError):
            return
        fp = fingerprint.take(repo)
        assert fp["entries"].get("link.txt") is not None


# ------------------------------------------------------------------------------------------ run-log parser
def log(scripts, terminals=None, summary="RESUMEN: {p}/{t} tests OK, {f} fallaron", final="TODOS LOS TESTS PASARON", inner=5):
    lines = []
    for s in scripts:
        lines.append(f"=== {s} ===")
        lines += [f"[PASS] assertion {i} of {s}" for i in range(inner)]
        lines.append(f"--- {(terminals or {}).get(s, 'PASS')}: {s}")
        lines.append("")
    passed = sum(1 for s in scripts if (terminals or {}).get(s, "PASS") == "PASS")
    if summary:
        lines.append(summary.format(p=passed, t=len(scripts), f=len(scripts) - passed))
    if final:
        lines.append(final)
    return "\n".join(lines) + "\n"


@test
def scripts_are_counted_uniquely_and_inner_pass_lines_are_never_counted():
    from release_readiness import runlog
    p = runlog.parse(log(["test_a.sh", "test_b.sh", "test_c.sh"], inner=40))
    assert len(p["unique_scripts"]) == 3 and len(p["passed_scripts"]) == 3 and p["reported_summary"] == {"passed": 3, "total": 3, "failed": 0}
    assert sum(1 for h in p["headers"]) == 3, "120 inner [PASS] lines must not become 120 scripts"
    dup = runlog.parse(log(["test_a.sh", "test_a.sh"]))
    assert dup["duplicate_headers"] == ["test_a.sh"] and dup["duplicate_terminals"] == ["test_a.sh"]


@test
def the_log_judge_is_fail_closed_for_every_incomplete_or_inconsistent_log():
    from release_readiness import runlog
    S = ["test_a.sh", "test_b.sh", "test_c.sh"]
    j = lambda text, code=0, exp=S, to=False: runlog.judge(runlog.parse(text), code, exp, to)
    assert j(log(S)) == ("PASS", [])
    assert j(log(S), None)[0] == "INCONCLUSIVE" and "EXIT_CODE_MISSING" in j(log(S), None)[1]
    assert j(log(S), 0, S, True)[0] == "INCONCLUSIVE" and "TIMEOUT" in j(log(S), 0, S, True)[1]
    assert "LOG_TRUNCATED" in j(log(S, summary=None, final=None))[1] and j(log(S, summary=None, final=None))[0] == "INCONCLUSIVE"
    assert j("")[0] == "INCONCLUSIVE" and "LOG_EMPTY" in j("")[1]
    assert j(log(S, summary="RESUMEN: 9/9 tests OK, 0 fallaron"))[0] == "INCONCLUSIVE", "a summary that disagrees with the terminals is not trusted"
    missing_terminal = log(S).replace("--- PASS: test_c.sh\n", "")
    assert j(missing_terminal)[0] == "INCONCLUSIVE" and "SCRIPTS_WITHOUT_TERMINAL_LINE" in j(missing_terminal)[1]
    assert j(log(S[:2]), 0, S)[0] == "FAIL" and "TESTS_OMITTED" in j(log(S[:2]), 0, S)[1]
    failing = log(S, terminals={"test_b.sh": "FAIL"}, final="AL MENOS UN TEST FALLÓ")
    assert j(failing, 1)[0] == "FAIL" and "TESTS_FAILED" in j(failing, 1)[1]
    assert j(failing, 0)[0] == "FAIL" and "EXIT_CODE_INCONSISTENT_WITH_FAILURES" in j(failing, 0)[1]
    assert j(log(S), 1)[0] == "FAIL" and "EXIT_CODE_NONZERO" in j(log(S), 1)[1]
    assert j(log(S) + "[SKIP] something skipped\n")[0] == "FAIL" and "SKIPPED_TESTS_PRESENT" in j(log(S) + "[SKIP] x\n")[1]


# ------------------------------------------------------------------------------------------ packager
@test
def the_packager_writes_a_complete_verifiable_package_outside_the_repository():
    from release_readiness import evidence
    repo, pkg, m = baseline_package()
    assert set(os.listdir(pkg)) == set(evidence.REQUIRED_FILES)
    assert m["verdict"] == {"result": "PASS", "tree_identity": "VERIFIED", "reasons": []} and m["exit_code"] == 0 and m["timed_out"] is False
    assert m["results"]["reported"] == {"passed": 3, "total": 3, "failed": 0}
    v = m["results"]["verified"]
    assert (v["unique_scripts"], v["passed"], v["failed"], v["skip_lines"], v["expected_scripts_on_disk"], v["omitted_scripts"]) == (3, 3, 0, 0, 3, [])
    assert m["fingerprint"]["identical"] and m["fingerprint"]["before_sha256"] == m["fingerprint"]["after_sha256"] and m["fingerprint"]["changed_paths"] is None
    assert m["security"]["all_passed"] and m["git_diff_check"]["exit_code"] == 0 and m["command"] == ["bash", "tests/run-all.sh"]
    assert m["run_id"].startswith("RUN-") and m["started_utc"].endswith("Z") and m["environment"]["python"]
    assert not os.path.normcase(os.path.realpath(pkg)).startswith(os.path.normcase(os.path.realpath(repo)))
    r = verify(pkg, repo)
    assert r["result"] == "PASS" and r["tree_identity"] == "VERIFIED", [c for c in r["checks"] if c["status"] != "PASS"]


@test
def the_published_log_has_no_personal_paths_while_the_raw_log_is_kept_privately():
    from release_readiness.redact import residual_personal_paths
    repo, pkg, m = baseline_package()
    published = open(os.path.join(pkg, "full-regression.log"), "rb").read()
    raw = open(os.path.join(pkg + ".private", "full-regression.raw.log"), "rb").read()
    assert b"<REPO_ROOT>" in published and residual_personal_paths(published) == 0
    assert m["redaction"]["replaced_lines"] >= 3 and m["redaction"]["residual_personal_path_lines"] == 0
    assert os.path.basename(os.path.dirname(repo)).encode() in raw or b"repo" in raw
    from release_readiness.common import sha256_bytes
    assert m["redaction"]["raw_log_sha256"] == sha256_bytes(raw) and m["redaction"]["published_log_sha256"] == sha256_bytes(published)
    for name in os.listdir(pkg):
        assert residual_personal_paths(open(os.path.join(pkg, name), "rb").read()) == 0, name


@test
def redaction_covers_every_spelling_of_the_root_and_generic_home_paths():
    from release_readiness.redact import redact_text, residual_personal_paths
    with tmpdir() as d:
        root = os.path.join(d, "repo")
        os.makedirs(root)
        variants = {root, root.replace("\\", "/"), root.replace("/", "\\")}
        drive = os.path.splitdrive(root)[0]
        if drive:
            variants.add("/" + drive[0].lower() + root[len(drive):].replace("\\", "/"))
        for v in variants:
            out = redact_text(f"opened {v}/tests/x.sh ok", root)
            assert v not in out and "<REPO_ROOT>" in out, v
        samples = ["C:\\Users\\alice\\Documents\\x", "C:/Users/bob/y", "/home/carol/z", "/Users/dave/w", "/c/Users/erin/v", "/mnt/c/Users/frank/u"]
        for s in samples:
            out = redact_text("path=" + s, root)
            assert not any(n in out for n in ("alice", "bob", "carol", "dave", "erin", "frank")), out
            assert residual_personal_paths(out.encode()) == 0
        assert residual_personal_paths(b"leftover C:\\Users\\zed\\x") == 1


@test
def the_packager_refuses_unsafe_output_locations_commands_and_roots():
    from release_readiness import evidence
    from release_readiness.common import ReadinessError
    with tmpdir() as d:
        repo = git_repo(d)

        def refuses(code, *a, **k):
            try:
                evidence.run_and_package(*a, **k)
            except ReadinessError as e:
                assert e.code == code, (e.code, code)
                return
            raise AssertionError(f"accepted an unsafe request expecting {code}")
        refuses("E_OUTPUT_DIR", repo, os.path.join(repo, "evidence"))
        refuses("E_OUTPUT_DIR", repo, os.path.join(d, "no", "such", "parent", "pkg"))
        os.makedirs(os.path.join(d, "full"))
        write(os.path.join(d, "full", "x"), "x")
        refuses("E_OUTPUT_DIR", repo, os.path.join(d, "full"))
        os.makedirs(os.path.join(d, "taken.private"))
        refuses("E_OUTPUT_DIR", repo, os.path.join(d, "taken"))
        for bad in ("../run.sh", "/etc/run.sh", "tests/missing.sh", "tests/run-all.txt", "..\\run.sh"):
            refuses("E_COMMAND", repo, os.path.join(d, "o" + str(abs(hash(bad)))), runner_rel=bad)
        for bad in (0, -5, 10 ** 7, True, "60"):
            refuses("E_USAGE", repo, os.path.join(d, "t" + str(abs(hash(str(bad))))), timeout_seconds=bad)
        plain = os.path.join(d, "not_a_repo")
        os.makedirs(plain)
        refuses("E_ROOT", plain, os.path.join(d, "p"))
        sub = os.path.join(repo, "tests")
        refuses("E_ROOT", sub, os.path.join(d, "s"))


@test
def a_failing_test_gives_fail_and_a_nonzero_exit_code():
    with tmpdir() as d:
        repo, pkg, m = pack(d, scripts={"test_a.sh": OK_SCRIPT, "test_b.sh": FAIL_SCRIPT, "test_c.sh": OK_SCRIPT})
        assert m["verdict"]["result"] == "FAIL" and m["exit_code"] == 1
        assert {"TESTS_FAILED", "EXIT_CODE_NONZERO"} <= set(m["verdict"]["reasons"]) and m["results"]["failed_scripts"] == ["test_b.sh"]
        assert verify(pkg, repo)["result"] == "FAIL"


@test
def a_timeout_is_inconclusive_kills_the_run_and_leaves_no_exit_code():
    sleeper = "#!/usr/bin/env bash\nsleep 120\nexit 0\n"
    with tmpdir() as d:
        t0 = time.time()
        repo, pkg, m = pack(d, scripts={"test_a.sh": sleeper, "test_b.sh": OK_SCRIPT}, timeout=4)
        assert time.time() - t0 < 60, "the whole process tree must be ended at the deadline"
        assert m["verdict"]["result"] == "INCONCLUSIVE" and m["timed_out"] is True and m["exit_code"] is None and "TIMEOUT" in m["verdict"]["reasons"]
        assert open(os.path.join(pkg, "full-regression.exitcode")).read().strip() == ""
        r = verify(pkg, repo)
        assert r["result"] == "INCONCLUSIVE" and by_id(r)["V04_EXIT_CODE"] == "INCONCLUSIVE"


@test
def a_tree_that_changes_during_the_run_is_reported_and_never_passes():
    mutator = "#!/usr/bin/env bash\necho changed-during-run >> data.txt\necho x > created_during_run.txt\nexit 0\n"
    with tmpdir() as d:
        repo, pkg, m = pack(d, scripts={"test_a.sh": OK_SCRIPT, "test_b.sh": mutator}, files={"data.txt": "start\n"})
        assert m["verdict"]["result"] == "INCONCLUSIVE" and m["verdict"]["tree_identity"] == "CHANGED_DURING_RUN" and "CHANGED_DURING_RUN" in m["verdict"]["reasons"]
        assert not m["fingerprint"]["identical"] and m["fingerprint"]["changed_paths"]["changed"] == ["data.txt"] and m["fingerprint"]["changed_paths"]["added"] == ["created_during_run.txt"]
        r = verify(pkg, repo)
        assert r["tree_identity"] == "CHANGED_DURING_RUN" and r["result"] == "INCONCLUSIVE"


@test
def omitted_scripts_skip_lines_missing_summaries_and_empty_logs_are_never_a_pass():
    full = "".join(f"echo '=== test_{n}.sh ==='\necho '--- PASS: test_{n}.sh'\necho\n" for n in "abc")
    runners = {
        "tests/run-partial.sh": ("echo '=== test_a.sh ==='\necho '--- PASS: test_a.sh'\necho\n"
                                 "echo 'RESUMEN: 1/1 tests OK, 0 fallaron'\necho 'TODOS LOS TESTS PASARON'\n"),
        "tests/run-skip.sh": full + "echo '[SKIP] pretend this was skipped'\necho 'RESUMEN: 3/3 tests OK, 0 fallaron'\necho 'TODOS LOS TESTS PASARON'\n",
        "tests/run-empty.sh": "exit 0\n",
        "tests/run-truncated.sh": full,
    }
    expect = {"tests/run-partial.sh": ("FAIL", "TESTS_OMITTED"), "tests/run-skip.sh": ("FAIL", "SKIPPED_TESTS_PRESENT"),
              "tests/run-empty.sh": ("INCONCLUSIVE", "LOG_EMPTY"), "tests/run-truncated.sh": ("INCONCLUSIVE", "LOG_TRUNCATED")}
    for rel, (want, reason) in expect.items():
        with tmpdir() as d:
            repo, pkg, m = pack(d, files={rel: runners[rel]}, runner=rel)
            assert m["verdict"]["result"] == want and reason in m["verdict"]["reasons"], (rel, m["verdict"])
            assert verify(pkg, repo)["result"] in (want, "FAIL"), rel


@test
def git_diff_check_and_security_scripts_decide_the_verdict():
    def dirty(repo):
        write(os.path.join(repo, "notes.txt"), "trailing whitespace   \n")
    with tmpdir() as d:
        repo, pkg, m = pack(d, files={"notes.txt": "clean\n"}, pre=dirty)
        assert m["verdict"]["result"] == "FAIL" and "GIT_DIFF_CHECK_FAILED" in m["verdict"]["reasons"] and m["git_diff_check"]["exit_code"] != 0
    with tmpdir() as d:
        repo, pkg, m = pack(d, scripts={"test_a.sh": OK_SCRIPT, "test_b.sh": FAIL_SCRIPT}, security=("tests/test_b.sh",))
        assert "SECURITY_SCRIPT_FAILED" in m["verdict"]["reasons"] and m["security"]["all_passed"] is False
    with tmpdir() as d:
        repo, pkg, m = pack(d, security=("tests/test_not_in_the_log.sh",))
        assert m["verdict"]["result"] == "INCONCLUSIVE" and "SECURITY_SCRIPT_NOT_RUN" in m["verdict"]["reasons"]


@test
def secret_shaped_output_is_withheld_from_the_published_log():
    leaky = "#!/usr/bin/env bash\necho 'connecting with password=SYNTHETIC_SECRET_DO_NOT_USE_1234 to db'\nexit 0\n"
    with tmpdir() as d:
        repo, pkg, m = pack(d, scripts={"test_a.sh": OK_SCRIPT, "test_b.sh": leaky})
        assert m["verdict"]["result"] == "INCONCLUSIVE" and "SECRET_PATTERN_IN_LOG" in m["verdict"]["reasons"] and m["redaction"]["secret_pattern_lines"] >= 1
        text = b"".join(open(os.path.join(pkg, n), "rb").read() for n in os.listdir(pkg))
        assert b"SYNTHETIC_SECRET_DO_NOT_USE_1234" not in text and b"LOG WITHHELD" in text
        assert b"SYNTHETIC_SECRET_DO_NOT_USE_1234" in open(os.path.join(pkg + ".private", "full-regression.raw.log"), "rb").read()


@test
def release_tooling_can_only_run_read_only_git_commands():
    from release_readiness import runner
    from release_readiness.common import ReadinessError
    with tmpdir() as d:
        repo = git_repo(d)
        for args in (("add", "-A"), ("commit", "-m", "x"), ("tag", "v9.9.9"), ("branch", "new-branch"), ("checkout", "-b", "x"), ("push", "origin", "main"),
                     ("merge", "x"), ("reset", "--hard"), ("config", "user.name", "x"), ("clean", "-fd"), ("stash",), ("rm", "-r", "."), ()):
            try:
                runner.git(repo, *args)
            except ReadinessError as e:
                assert e.code == "E_COMMAND", args
                continue
            raise AssertionError(f"git {args} was allowed")
        for args in (("diff", "--output=leak.txt"), ("log", "--output", "x"), ("diff", "--ext-diff"), ("show", "--textconv"), ("status", "--exec-path=/x")):
            try:
                runner.git(repo, *args)
            except ReadinessError as e:
                assert e.code == "E_COMMAND", args
                continue
            raise AssertionError(f"git {args} was allowed")
        assert not os.path.exists(os.path.join(repo, "leak.txt"))
        assert runner.git(repo, "branch", "--show-current").returncode == 0 and runner.git(repo, "tag", "--list").returncode == 0
        write(os.path.join(repo, "tests", "test_a.sh"), OK_SCRIPT + "changed\n")
        assert runner.git(repo, "diff", "--check").returncode == 0, "the hardened diff still works"
        assert runner.git(repo, "rev-parse", "HEAD").stdout.strip()
        sh(repo, "status", "--short")
        try:
            runner.run_to_file([], repo, os.path.join(d, "l.log"), 5)
        except ReadinessError as e:
            assert e.code == "E_COMMAND"
        else:
            raise AssertionError("an empty argv was accepted")


if __name__ == "__main__":
    raise SystemExit(run_all())
