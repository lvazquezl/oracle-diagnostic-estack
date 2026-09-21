"""Phase 14 — mutation-testing control. Each defense is disabled at runtime (in process, on synthetic data) and the
scenario that protects it MUST then fail; a scenario that still passes under its mutation would be decorative."""
import contextlib
import copy
import io
import os
import shutil
import sys

from tests.p13 import harness
from tests.p14.harness import ROOT, baseline_package, copy_package, git_repo, load_manifest, rewrite_sums, run_all, test, tmpdir, write, FAIL_SCRIPT, OK_SCRIPT, save_manifest

harness._TESTS.clear()

S = ["test_a.sh", "test_b.sh", "test_c.sh"]


@contextlib.contextmanager
def patched(*patches):
    saved = [(o, a, getattr(o, a)) for o, a, _ in patches]
    try:
        for o, a, r in patches:
            setattr(o, a, r)
        yield
    finally:
        for o, a, v in saved:
            setattr(o, a, v)


def must_fail_under(patches, scenario, label):
    scenario()                                     # sanity: on the real code the scenario passes
    with patched(*patches):
        try:
            scenario()
        except AssertionError:
            return                                 # the scenario noticed the mutation (a crash elsewhere would NOT count)
    raise AssertionError(f"MUTATION SURVIVED: {label} — '{scenario.__name__}' still passed with the defense disabled")


def log(scripts, summary=True, final=True):
    lines = []
    for s in scripts:
        lines += [f"=== {s} ===", "[PASS] x", f"--- PASS: {s}", ""]
    if summary:
        lines.append(f"RESUMEN: {len(scripts)}/{len(scripts)} tests OK, 0 fallaron")
    if final:
        lines.append("TODOS LOS TESTS PASARON")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------------------------------- scenarios
def scen_fingerprint_sees_content_changes():
    from release_readiness import fingerprint
    with tmpdir() as d:
        repo = git_repo(d, files={"data.txt": "one\n"})
        a = fingerprint.take(repo)
        write(os.path.join(repo, "data.txt"), "two\n")
        assert a["aggregate_sha256"] != fingerprint.take(repo)["aggregate_sha256"]


def scen_a_nonzero_exit_code_is_a_fail():
    from release_readiness import runlog
    assert runlog.judge(runlog.parse(log(S)), 1, S)[0] == "FAIL"


def scen_omitted_scripts_are_a_fail():
    from release_readiness import runlog
    assert runlog.judge(runlog.parse(log(S[:2])), 0, S)[0] == "FAIL"


def scen_a_truncated_log_is_inconclusive():
    from release_readiness import runlog
    assert runlog.judge(runlog.parse(log(S, summary=False, final=False)), 0, S)[0] == "INCONCLUSIVE"


def scen_altered_artifacts_are_caught_by_their_hashes():
    from release_readiness import evidence
    repo, pkg, _m = baseline_package()
    with tmpdir() as d:
        dst = copy_package(pkg, d)
        with open(os.path.join(dst, "full-regression.log"), "ab") as f:
            f.write(b"an extra line\n")
        assert evidence.verify_package(dst, repo)["result"] == "FAIL"


_FAILING = {}


def failing_package():
    if "v" not in _FAILING:
        from release_readiness import evidence
        d = __import__("tempfile").mkdtemp(prefix="p14_mut_")
        repo = git_repo(d, scripts={"test_a.sh": OK_SCRIPT, "test_b.sh": FAIL_SCRIPT})
        pkg = os.path.join(d, "pkg")
        evidence.run_and_package(repo, pkg, timeout_seconds=120)
        _FAILING["v"] = (repo, pkg, d)
    return _FAILING["v"]


def scen_a_forged_pass_over_a_failing_run_is_detected():
    from release_readiness import evidence
    repo, pkg, _d = failing_package()
    with tmpdir() as dd:
        dst = copy_package(pkg, dd)
        m = load_manifest(dst)
        m["verdict"] = {"result": "PASS", "tree_identity": "VERIFIED", "reasons": []}
        save_manifest(dst, m)
        rewrite_sums(dst)
        assert evidence.verify_package(dst, repo)["result"] == "FAIL"


def scen_evidence_for_a_different_tree_is_not_accepted():
    from release_readiness import evidence
    repo, pkg, _m = baseline_package()
    with tmpdir() as d:
        clone = os.path.join(d, "clone")
        shutil.copytree(repo, clone)
        write(os.path.join(clone, "tests", "test_a.sh"), OK_SCRIPT + "# changed\n")
        r = evidence.verify_package(pkg, clone)
        assert r["tree_identity"] != "VERIFIED" and r["result"] != "PASS"


def scen_personal_paths_are_redacted():
    from release_readiness import redact
    out = redact.redact_text("opened C:\\Users\\bob\\x and /home/carol/y", "C:/nonexistent/root")
    assert "bob" not in out and "carol" not in out


def scen_overstated_adapter_maturity_is_reported():
    from release_readiness import registry
    doc = copy.deepcopy(registry.load_registry(ROOT))
    for c in doc["components"]:
        if c["id"] == "adapter:oracle_sql":
            c["maturity"] = "TESTED_WITH_SYNTHETIC_FIXTURES"
    assert "REG_MATURITY_OVERSTATED" in {f["code"] for f in registry.verify_registry(ROOT, registry=doc)["findings"]}


def scen_a_maturity_claim_needs_evidence():
    from release_readiness import registry
    doc = copy.deepcopy(registry.load_registry(ROOT))
    for c in doc["components"]:
        if c["id"] == "collector:Q-DISC-IDENTITY-001":
            c["test_refs"] = []
    assert "REG_EVIDENCE_MISSING" in {f["code"] for f in registry.verify_registry(ROOT, registry=doc)["findings"]}


def _record():
    hist = [{"state": "PROPOSED", "at_utc": "2026-09-10T10:00:00Z", "actor_id": "REV-PROPOSER01"}, {"state": "REVIEWED", "at_utc": "2026-09-11T10:00:00Z", "actor_id": "REV-PROPOSER01"}]
    return {"record_id": "GOV-MUT-001", "artifact_type": "skill", "artifact_id": "oracle/example", "semver": "1.0.0", "state": "REVIEWED", "change_class": "NORMAL",
            "owner_role": "estack-maintainer", "proposer_id": "REV-PROPOSER01", "sources": ["docs/x.md"], "evidence_refs": [],
            "compatibility": {"oracle_versions": [], "platforms": [], "breaking": False}, "history": hist, "revalidate_by_utc": "2027-03-01T00:00:00Z"}


def scen_the_proposer_cannot_review_their_own_change():
    from release_readiness import governance
    assert "GOV_SELF_APPROVAL" in {f["code"] for f in governance.validate_record(_record(), "2026-09-20T00:00:00Z")}


def scen_the_static_scan_finds_a_network_import():
    from release_readiness import gate
    with tmpdir() as d:
        root = os.path.join(d, "mini")
        for p in ("mcp_gateway", "rca_engine", "change_documentation_knowledge", "capacity_engine", "release_readiness"):
            write(os.path.join(root, p, "__init__.py"), "")
        write(os.path.join(root, "mcp_gateway", "net.py"), "import socket\n")
        assert gate.check_static_security(root)["status"] == "FAIL"


def scen_versions_are_compared_numerically():
    from mcp_gateway import versions
    assert versions.compare_versions("9.2", "10.1") == -1 and versions.compare_versions("11.2.0.10", "11.2.0.4") == 1


def scen_missing_version_metadata_supports_no_version():
    from mcp_gateway import catalog
    spec = {"collector_id": "Q-MUT-TEST-001", "kind": "sql_query", "domain": "oracle", "title": "t", "row_limit": 5, "params": {},
            "output_fields": {"a": {"type": "integer", "policy": "KEEP"}}, "adapters": {}}
    assert catalog.Collector(spec, {}).supported_oracle_versions == []


def scen_limits_above_the_ceiling_refuse_startup():
    from mcp_gateway import cli
    real_stdin = sys.stdin
    sys.stdin = type("S", (), {"buffer": io.BytesIO(b"")})()
    try:
        with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.TextIOWrapper(io.BytesIO())):
            rc = cli.main(["--max-rows", "999"])
    finally:
        sys.stdin = real_stdin
    assert rc == 2


def scen_release_tooling_cannot_run_mutating_git_commands():
    from release_readiness import runner
    from release_readiness.common import ReadinessError
    with tmpdir() as d:
        repo = git_repo(d)
        try:
            runner.git(repo, "add", "-A")
        except ReadinessError:
            return
        raise AssertionError("`git add` was allowed")


def scen_the_package_cannot_be_written_inside_the_repository():
    from release_readiness import evidence
    from release_readiness.common import ReadinessError
    with tmpdir() as d:
        repo = git_repo(d)
        try:
            evidence.run_and_package(repo, os.path.join(repo, "evidence-inside"), timeout_seconds=120)
        except ReadinessError as e:
            assert e.code == "E_OUTPUT_DIR"
            return
        raise AssertionError("a package was written inside the repository")


def scen_a_report_with_secret_shaped_text_is_withheld():
    from release_readiness import gate
    rep = {"schema_version": "1.0.0", "release_gate": "PASS", "checks": [{"id": "X", "status": "PASS", "detail": "password=SYNTHETIC_SECRET_DO_NOT_USE_1234"}]}
    assert gate.sanitize_report(rep, ROOT).get("note") == "REPORT_WITHHELD_BY_SANITIZATION"


def scen_documented_commands_are_checked_against_the_real_parsers():
    from release_readiness import gate
    text = "```bash\npython -m release_readiness gate --no-such-flag\n```\n"
    assert gate.validate_documented_commands(text) != []


# ------------------------------------------------------------------------------------------- mutations
@test
def fingerprint_content_sensitivity_is_protected():
    from release_readiness import fingerprint
    must_fail_under([(fingerprint, "_entry", lambda root, rel: "constant")], scen_fingerprint_sees_content_changes, "file hashing")


@test
def exit_code_handling_is_protected():
    from release_readiness import runlog
    real = runlog.judge
    must_fail_under([(runlog, "judge", lambda parsed, exit_code, expected_scripts=None, timed_out=False: real(parsed, 0, expected_scripts, timed_out))],
                    scen_a_nonzero_exit_code_is_a_fail, "exit code")


@test
def omitted_script_detection_is_protected():
    from release_readiness import runlog
    real = runlog.judge
    must_fail_under([(runlog, "judge", lambda parsed, exit_code, expected_scripts=None, timed_out=False: real(parsed, exit_code, None, timed_out))],
                    scen_omitted_scripts_are_a_fail, "omitted scripts")


@test
def truncated_log_detection_is_protected():
    from release_readiness import runlog
    real = runlog.parse

    def lenient(text):
        p = real(text)
        p["final_line"] = p["final_line"] or "TODOS LOS TESTS PASARON"
        p["reported_summary"] = p["reported_summary"] or {"passed": len(p["passed_scripts"]), "total": len(p["unique_scripts"]), "failed": len(p["failed_scripts"])}
        return p
    must_fail_under([(runlog, "parse", lenient)], scen_a_truncated_log_is_inconclusive, "truncated log")


@test
def artifact_hash_verification_is_protected():
    from release_readiness import evidence
    real = evidence.sha256_file

    def trusting(path):
        name = os.path.basename(path)
        with open(os.path.join(os.path.dirname(path), "SHA256SUMS.txt"), encoding="utf-8") as f:
            for line in f:
                if line.rstrip("\n").endswith("  " + name):
                    return line.split("  ")[0]
        return real(path)
    must_fail_under([(evidence, "sha256_file", trusting)], scen_altered_artifacts_are_caught_by_their_hashes, "SHA256SUMS verification")


@test
def verdict_re_derivation_is_protected():
    from release_readiness import evidence
    must_fail_under([(evidence, "decide", lambda *a, **k: ("PASS", "VERIFIED", []))], scen_a_forged_pass_over_a_failing_run_is_detected, "verdict recomputation")


@test
def tree_identity_verification_is_protected():
    from release_readiness import evidence
    repo, pkg, _m = baseline_package()
    import json
    after = json.load(open(os.path.join(pkg, "fingerprint-after.json"), encoding="utf-8"))
    must_fail_under([(evidence.fingerprint, "take", lambda root: after)], scen_evidence_for_a_different_tree_is_not_accepted, "current tree comparison")


@test
def personal_path_redaction_is_protected():
    from release_readiness import redact
    must_fail_under([(redact, "_HOME_PATTERNS", ())], scen_personal_paths_are_redacted, "home path redaction")


@test
def registry_maturity_checks_are_protected():
    from release_readiness import registry
    must_fail_under([(registry, "_verify_adapters", lambda *a, **k: None)], scen_overstated_adapter_maturity_is_reported, "adapter maturity comparison")
    must_fail_under([(registry, "_verify_maturity", lambda *a, **k: None)], scen_a_maturity_claim_needs_evidence, "evidence requirement")


@test
def segregation_of_duties_is_protected():
    from release_readiness import governance
    real = governance.validate_record
    must_fail_under([(governance, "validate_record", lambda r, now=None: [f for f in real(r, now) if f["code"] != "GOV_SELF_APPROVAL"])],
                    scen_the_proposer_cannot_review_their_own_change, "self-approval check")


@test
def the_static_security_scan_is_protected():
    from release_readiness import gate
    must_fail_under([(gate, "_scan_file", lambda *a, **k: [])], scen_the_static_scan_finds_a_network_import, "AST scan")


@test
def numeric_version_comparison_is_protected():
    from mcp_gateway import versions
    must_fail_under([(versions, "compare_versions", lambda a, b: (a > b) - (a < b))], scen_versions_are_compared_numerically, "numeric comparison")


@test
def fail_closed_version_metadata_is_protected():
    from mcp_gateway import catalog
    must_fail_under([(catalog, "_effective_versions", lambda spec, meta: list(catalog.ORACLE_VERSIONS))], scen_missing_version_metadata_supports_no_version, "fail-closed metadata")


@test
def limit_ceilings_are_protected():
    from mcp_gateway import cli
    must_fail_under([(cli, "bounded_limit", lambda name, value: value)], scen_limits_above_the_ceiling_refuse_startup, "limit ceilings")


@test
def the_read_only_git_allowlist_is_protected():
    from release_readiness import runner
    must_fail_under([(runner, "GIT_READ_ONLY", frozenset(runner.GIT_READ_ONLY | {"add"}))], scen_release_tooling_cannot_run_mutating_git_commands, "git allowlist")


@test
def the_output_outside_the_repository_rule_is_protected():
    from release_readiness import evidence
    must_fail_under([(evidence, "_inside", lambda path, root: False)], scen_the_package_cannot_be_written_inside_the_repository, "output location rule")


@test
def report_sanitization_is_protected():
    from change_documentation_knowledge import safety
    must_fail_under([(safety, "audit_strings", lambda obj, _depth=0: None)], scen_a_report_with_secret_shaped_text_is_withheld, "final audit")


@test
def documented_command_validation_is_protected():
    from release_readiness import gate
    must_fail_under([(gate, "_fenced_commands", lambda text: [])], scen_documented_commands_are_checked_against_the_real_parsers, "documented command parsing")


def _cleanup():
    if "v" in _FAILING:
        shutil.rmtree(_FAILING["v"][2], ignore_errors=True)


import atexit  # noqa: E402
atexit.register(_cleanup)

if __name__ == "__main__":
    raise SystemExit(run_all())
