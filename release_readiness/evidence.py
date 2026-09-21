"""
release_readiness.evidence — run the repository's test runner and package verifiable evidence; verify a package.

`run_and_package` records, for one run: run id, UTC timestamps, branch, HEAD, tracked/untracked state, the
fingerprint of the working tree BEFORE and AFTER, the exact command, environment versions, duration, exit code,
unique per-script counts (independently parsed), security-script results, `git diff --check`, and the SHA-256 of
every artifact. The package lives OUTSIDE the repository so writing it cannot change the fingerprint.

`verify_package` re-derives every claim from the delivered files instead of trusting the manifest, and answers
PASS / FAIL / INCONCLUSIVE plus a tree identity of VERIFIED / UNVERIFIED / CHANGED_DURING_RUN.

Integrity, not authenticity: hashes detect accidental or careless alteration; anyone able to rewrite the log AND
the manifest AND SHA256SUMS consistently is not stopped by this tool. Independent human review remains required.
"""
from __future__ import annotations

import json
import os
import platform
import re
import sys

from . import fingerprint, runlog
from .common import (FAIL, INCONCLUSIVE, NOT_APPLICABLE, PASS, SCHEMA_VERSION, TOOL_VERSION, TREE_CHANGED, TREE_UNVERIFIED, TREE_VERIFIED,
                     ReadinessError, dumps_pretty, new_run_id, now_utc, parse_utc, sha256_bytes, sha256_file, worst)
from .redact import redact_bytes, residual_personal_paths
from .runner import git, run_to_file, version_line

REQUIRED_FILES = ("manifest.json", "manifest.md", "full-regression.log", "full-regression.exitcode", "fingerprint-before.json",
                  "fingerprint-after.json", "git-diff-check.txt", "SHA256SUMS.txt")
_HASHED_ARTIFACTS = ("full-regression.log", "full-regression.exitcode", "fingerprint-before.json", "fingerprint-after.json", "git-diff-check.txt")
_RUN_ID = re.compile(r'^RUN-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}\Z')
_SHA = re.compile(r'^[0-9a-f]{64}\Z')
_TEST_SCRIPT = re.compile(r'^tests/(test_[^/]+\.sh)\Z')
MAX_LOG_BYTES = 64 * 1024 * 1024
_HEX64 = re.compile(r'[0-9a-f]{64}')


def _secret_pattern_lines(data: bytes) -> int:
    """Lines of a log that still look secret-shaped (structured patterns; SHA-256 digests are ignored)."""
    from change_documentation_knowledge.safety import contains_structured_secret
    return sum(1 for line in data.decode("utf-8", "replace").splitlines() if contains_structured_secret(_HEX64.sub("", line)))
DEFAULT_TIMEOUT_SECONDS = 6 * 3600
MANIFEST_KEYS = {"schema_version", "tool_version", "run_id", "started_utc", "ended_utc", "duration_seconds", "command", "timeout_seconds",
                 "timed_out", "exit_code", "git", "fingerprint", "environment", "results", "security", "git_diff_check", "verdict",
                 "redaction", "artifacts", "limitations"}


# --- helpers ---------------------------------------------------------------------------------------
def _same_path(a: str, b: str) -> bool:
    return os.path.normcase(os.path.realpath(a)) == os.path.normcase(os.path.realpath(b))


def _inside(path: str, root: str) -> bool:
    p, r = os.path.normcase(os.path.realpath(path)), os.path.normcase(os.path.realpath(root))
    return p == r or p.startswith(r + os.sep)


def _write_new(path: str, data: bytes) -> None:
    with open(path, "xb") as f:                               # exclusive create: never overwrites
        f.write(data)


def _git_state(root: str) -> dict:
    status = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all").stdout
    entries = [e for e in status.split(b"\0") if e]
    untracked = sum(1 for e in entries if e.startswith(b"??"))
    deleted = sum(1 for e in entries if len(e) > 1 and b"D" in e[:2])
    tags = git(root, "tag", "--list", "--points-at", "HEAD").stdout.decode("utf-8", "replace").split()
    return {"branch": git(root, "branch", "--show-current").stdout.decode("utf-8", "replace").strip() or "DETACHED",
            "head": git(root, "rev-parse", "HEAD").stdout.decode("ascii", "replace").strip(),
            "tags_at_head": sorted(tags), "status_entries": len(entries), "untracked_count": untracked,
            "deleted_count": deleted, "modified_count": len(entries) - untracked - deleted}


def _environment() -> dict:
    return {"platform": platform.system(), "platform_release": platform.release(), "machine": platform.machine(),
            "python": platform.python_version(), "git": version_line("git"), "bash": version_line("bash"), "runner_environment": "inherited"}


def _expected_scripts(entries: dict) -> list:
    out = []
    for path, sha in entries.items():
        m = _TEST_SCRIPT.match(path)
        if m and sha != "DELETED":
            out.append(m.group(1))
    return sorted(out)


def _security_results(parsed: dict, scripts) -> dict:
    rows = []
    for s in sorted(set(scripts)):
        name = os.path.basename(s)
        state = "PASS" if name in parsed["passed_scripts"] else "FAIL" if name in parsed["failed_scripts"] else "NOT_RUN"
        rows.append({"script": name, "status": state})
    return {"scripts": rows, "all_passed": bool(rows) and all(r["status"] == "PASS" for r in rows)}


def _check_security_scripts(sec: dict) -> tuple:
    """(result, reasons) for a security section."""
    if not sec["scripts"]:
        return NOT_APPLICABLE, []
    if any(r["status"] == "FAIL" for r in sec["scripts"]):
        return FAIL, ["SECURITY_SCRIPT_FAILED"]
    if any(r["status"] == "NOT_RUN" for r in sec["scripts"]):
        return INCONCLUSIVE, ["SECURITY_SCRIPT_NOT_RUN"]
    return PASS, []


def decide(parsed, exit_code, timed_out, fp_before, fp_after, security, diff_check_exit) -> tuple:
    """Single decision function shared by the packager and the verifier: (result, tree_identity, reasons)."""
    tree = TREE_VERIFIED if fp_before["aggregate_sha256"] == fp_after["aggregate_sha256"] else TREE_CHANGED
    result, reasons = runlog.judge(parsed, exit_code, _expected_scripts(fp_after["entries"]), timed_out)
    reasons = list(reasons)
    if tree == TREE_CHANGED:
        reasons.append("CHANGED_DURING_RUN")
        result = FAIL if result == FAIL else INCONCLUSIVE
    sec_result, sec_reasons = _check_security_scripts(security)
    reasons += sec_reasons
    if sec_result == FAIL:
        result = FAIL
    elif sec_result == INCONCLUSIVE and result == PASS:
        result = INCONCLUSIVE
    if diff_check_exit != 0:
        reasons.append("GIT_DIFF_CHECK_FAILED")
        result = FAIL
    return result, tree, reasons


# --- package ---------------------------------------------------------------------------------------
def run_and_package(root: str, out_dir: str, *, runner_rel: str = "tests/run-all.sh", timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
                    security_scripts=(), command: list = None) -> dict:
    """Run the test runner at `root`, write the evidence package to `out_dir` (outside `root`) and return its manifest.
    A raw (unredacted) copy of the log is kept in the sibling directory `<out_dir>.private`, never inside the package."""
    if not isinstance(root, str) or not os.path.isdir(root):
        raise ReadinessError("E_ROOT")
    try:
        top = git(root, "rev-parse", "--show-toplevel").stdout.decode("utf-8", "replace").strip()
    except ReadinessError:
        raise ReadinessError("E_ROOT")                        # not a git working tree
    if not _same_path(top, root):
        raise ReadinessError("E_ROOT")
    root = os.path.realpath(root)
    out_dir = os.path.abspath(out_dir)
    private = out_dir + ".private"
    if _inside(out_dir, root) or _inside(private, root) or os.path.lexists(private) or os.path.islink(out_dir):
        raise ReadinessError("E_OUTPUT_DIR")
    if os.path.isdir(out_dir) and os.listdir(out_dir):
        raise ReadinessError("E_OUTPUT_DIR")
    if not os.path.isdir(os.path.dirname(out_dir)):
        raise ReadinessError("E_OUTPUT_DIR")
    if command is None:
        if (not isinstance(runner_rel, str) or os.path.isabs(runner_rel) or ".." in runner_rel.replace("\\", "/").split("/")
                or not runner_rel.endswith(".sh") or not os.path.isfile(os.path.join(root, runner_rel))):
            raise ReadinessError("E_COMMAND")
        command = ["bash", runner_rel.replace("\\", "/")]
    if not isinstance(timeout_seconds, (int, float)) or isinstance(timeout_seconds, bool) or not (1 <= timeout_seconds <= 86400):
        raise ReadinessError("E_USAGE")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(private)

    run_id = new_run_id()
    state_before = _git_state(root)
    fp_before = fingerprint.take(root)
    started = now_utc()
    raw_log = os.path.join(private, "full-regression.raw.log")
    res = run_to_file(command, root, raw_log, timeout_seconds)
    ended = now_utc()
    fp_after = fingerprint.take(root)
    check = git(root, "diff", "--check", check=False)
    check_text = (check.stdout + check.stderr).decode("utf-8", "replace")

    with open(raw_log, "rb") as f:
        raw = f.read(MAX_LOG_BYTES + 1)
    truncated_capture = len(raw) > MAX_LOG_BYTES
    raw = raw[:MAX_LOG_BYTES]
    redacted, replaced_lines = redact_bytes(raw, root)
    leak = residual_personal_paths(redacted)
    secret_lines = _secret_pattern_lines(redacted)
    parsed = runlog.parse(raw.decode("utf-8", errors="replace"))
    security = _security_results(parsed, security_scripts)
    exit_code = res["exit_code"]
    result, tree, reasons = decide(parsed, exit_code, res["timed_out"], fp_before, fp_after, security, check.returncode)
    if leak or truncated_capture or secret_lines:
        reasons.append("PERSONAL_PATH_LEAK" if leak else "SECRET_PATTERN_IN_LOG" if secret_lines else "LOG_CAPTURE_TRUNCATED")
        result = FAIL if result == FAIL else INCONCLUSIVE
    published_log = redacted if not (leak or secret_lines) else b"LOG WITHHELD: personal path or secret-shaped content after redaction\n"

    _write_new(os.path.join(out_dir, "full-regression.log"), published_log)
    _write_new(os.path.join(out_dir, "full-regression.exitcode"), (str(exit_code) if exit_code is not None else "").encode() + b"\n")
    _write_new(os.path.join(out_dir, "fingerprint-before.json"), dumps_pretty(fp_before).encode())
    _write_new(os.path.join(out_dir, "fingerprint-after.json"), dumps_pretty(fp_after).encode())
    diff_out = check_text if not residual_personal_paths(check_text.encode()) else "withheld\n"
    _write_new(os.path.join(out_dir, "git-diff-check.txt"), f"exit_code: {check.returncode}\n{diff_out}".encode())

    ended_dt, started_dt = parse_utc(ended), parse_utc(started)
    manifest = {
        "schema_version": SCHEMA_VERSION, "tool_version": TOOL_VERSION, "run_id": run_id, "started_utc": started, "ended_utc": ended,
        "duration_seconds": int((ended_dt - started_dt).total_seconds()), "command": list(command), "timeout_seconds": timeout_seconds,
        "timed_out": bool(res["timed_out"]), "exit_code": exit_code,
        "git": {"before_run": state_before, "after_run": _git_state(root)},
        "fingerprint": {"algorithm": fingerprint.ALGORITHM, "before_sha256": fp_before["aggregate_sha256"], "after_sha256": fp_after["aggregate_sha256"],
                        "file_count_before": fp_before["file_count"], "file_count_after": fp_after["file_count"],
                        "identical": fp_before["aggregate_sha256"] == fp_after["aggregate_sha256"],
                        "changed_paths": (fingerprint.diff(fp_before, fp_after) if fp_before["aggregate_sha256"] != fp_after["aggregate_sha256"] else None)},
        "environment": _environment(),
        "results": {"reported": parsed["reported_summary"],
                    "verified": {"unique_scripts": len(parsed["unique_scripts"]), "passed": len(parsed["passed_scripts"]),
                                 "failed": len(parsed["failed_scripts"]), "skip_lines": parsed["skip_lines"],
                                 "scripts_without_terminal": len(parsed["scripts_without_terminal"]),
                                 "duplicate_scripts": len(parsed["duplicate_headers"]) + len(parsed["duplicate_terminals"]),
                                 "expected_scripts_on_disk": len(_expected_scripts(fp_after["entries"])),
                                 "omitted_scripts": sorted(set(_expected_scripts(fp_after["entries"])) - set(parsed["unique_scripts"]))},
                    "failed_scripts": parsed["failed_scripts"]},
        "security": security,
        "git_diff_check": {"exit_code": check.returncode},
        "verdict": {"result": result, "tree_identity": tree, "reasons": sorted(set(reasons))},
        "redaction": {"raw_log_sha256": sha256_bytes(raw), "published_log_sha256": sha256_bytes(published_log), "replaced_lines": replaced_lines,
                      "residual_personal_path_lines": leak, "secret_pattern_lines": secret_lines,
                      "note": "The raw log is kept outside the package; the published log has personal paths replaced by placeholders."},
        "artifacts": [{"path": n, "bytes": os.path.getsize(os.path.join(out_dir, n)), "sha256": sha256_file(os.path.join(out_dir, n))} for n in _HASHED_ARTIFACTS],
        "limitations": ["Tree identity compares the fingerprint taken before and after the run; it does not prove the tree was unchanged at every instant in between.",
                        "Hashes give integrity, not authenticity: they do not identify who produced the package.",
                        "A passing verdict describes tests against synthetic fixtures; it is not a certification of any real environment."],
    }
    _write_new(os.path.join(out_dir, "manifest.json"), dumps_pretty(manifest).encode())
    _write_new(os.path.join(out_dir, "manifest.md"), render_manifest_md(manifest).encode("utf-8"))
    sums = "".join(f"{sha256_file(os.path.join(out_dir, n))}  {n}\n" for n in sorted(REQUIRED_FILES) if n != "SHA256SUMS.txt")
    _write_new(os.path.join(out_dir, "SHA256SUMS.txt"), sums.encode())
    return manifest


def _md(v) -> str:
    return str(v).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def render_manifest_md(m: dict) -> str:
    r, v, s = m["results"], m["verdict"], m["security"]
    L = [f"# Evidence manifest {m['run_id']}", "",
         "> Tests against synthetic fixtures. Not a certification of any real environment. Integrity (hashes), not authenticity.", "",
         "| Field | Value |", "|---|---|",
         f"| Verdict | **{_md(v['result'])}** |", f"| Tree identity | {_md(v['tree_identity'])} |", f"| Reasons | {_md(', '.join(v['reasons']) or 'none')} |",
         f"| Started (UTC) | {_md(m['started_utc'])} |", f"| Ended (UTC) | {_md(m['ended_utc'])} |", f"| Duration (s) | {m['duration_seconds']} |",
         f"| Command | `{_md(' '.join(m['command']))}` |", f"| Exit code | {_md(m['exit_code'])} |", f"| Timed out | {m['timed_out']} |",
         f"| Branch | {_md(m['git']['before_run']['branch'])} |", f"| HEAD | {_md(m['git']['before_run']['head'])} |",
         f"| Tree state (before) | modified {m['git']['before_run']['modified_count']}, untracked {m['git']['before_run']['untracked_count']}, deleted {m['git']['before_run']['deleted_count']} |",
         f"| Fingerprint before | `{m['fingerprint']['before_sha256']}` ({m['fingerprint']['file_count_before']} files) |",
         f"| Fingerprint after | `{m['fingerprint']['after_sha256']}` ({m['fingerprint']['file_count_after']} files) |",
         f"| Reported summary | {_md(r['reported'])} |",
         f"| Verified (unique scripts) | {r['verified']['unique_scripts']} run, {r['verified']['passed']} passed, {r['verified']['failed']} failed, {r['verified']['skip_lines']} skip lines, {len(r['verified']['omitted_scripts'])} omitted (disk: {r['verified']['expected_scripts_on_disk']}) |",
         f"| Security scripts | {'all passed' if s['all_passed'] else 'NOT all passed'} ({len(s['scripts'])}) |",
         f"| git diff --check | exit {m['git_diff_check']['exit_code']} |",
         f"| Environment | {_md(m['environment'])} |", "", "## Security scripts", "", "| Script | Status |", "|---|---|"]
    L += [f"| {_md(x['script'])} | {_md(x['status'])} |" for x in s["scripts"]] or ["| _none declared_ | |"]
    L += ["", "## Artifacts", "", "| Path | Bytes | SHA-256 |", "|---|---|---|"]
    L += [f"| {_md(a['path'])} | {a['bytes']} | `{a['sha256']}` |" for a in m["artifacts"]]
    L += ["", "## Limitations"] + [f"- {_md(x)}" for x in m["limitations"]] + [""]
    return "\n".join(L)


# --- verification ----------------------------------------------------------------------------------
def _check(cid: str, status: str, detail: str) -> dict:
    return {"id": cid, "status": status, "detail": detail}


def verify_package(pkg_dir: str, root: str = None) -> dict:
    """Independently verify a package. Never raises for a malformed package: it reports FAIL/INCONCLUSIVE checks."""
    checks = []
    if not isinstance(pkg_dir, str) or not os.path.isdir(pkg_dir):
        return {"result": INCONCLUSIVE, "tree_identity": TREE_UNVERIFIED, "checks": [_check("V01_PACKAGE_PRESENT", INCONCLUSIVE, "package directory not found")]}
    missing = [n for n in REQUIRED_FILES if not os.path.isfile(os.path.join(pkg_dir, n))]
    checks.append(_check("V01_REQUIRED_FILES", FAIL if missing else PASS, f"missing: {missing}" if missing else "all required files present"))
    if missing:
        return {"result": INCONCLUSIVE if "full-regression.exitcode" in missing else FAIL, "tree_identity": TREE_UNVERIFIED, "checks": checks}

    # V02 hashes
    listed = {}
    for line in open(os.path.join(pkg_dir, "SHA256SUMS.txt"), encoding="utf-8", errors="replace").read().splitlines():
        m = re.match(r'^([0-9a-f]{64})  ([A-Za-z0-9_.-]+)$', line)
        if m:
            listed[m.group(2)] = m.group(1)
    actual = {n: sha256_file(os.path.join(pkg_dir, n)) for n in REQUIRED_FILES if n != "SHA256SUMS.txt"}
    mism = sorted(n for n in actual if listed.get(n) != actual[n])
    extra = sorted(n for n in os.listdir(pkg_dir) if n not in REQUIRED_FILES)
    checks.append(_check("V02_ARTIFACT_HASHES", FAIL if (mism or extra) else PASS,
                         f"hash mismatch/unlisted: {mism}; unexpected files: {extra}" if (mism or extra) else "SHA256SUMS matches every artifact"))
    try:
        manifest = json.load(open(os.path.join(pkg_dir, "manifest.json"), encoding="utf-8"))
        assert isinstance(manifest, dict)
    except Exception:
        checks.append(_check("V03_MANIFEST_SCHEMA", FAIL, "manifest.json is not a valid JSON object"))
        return {"result": FAIL, "tree_identity": TREE_UNVERIFIED, "checks": checks}

    # V03 schema, timestamps
    problems = []
    if set(manifest) != MANIFEST_KEYS:
        problems.append("manifest keys differ from the schema")
    if not isinstance(manifest.get("run_id"), str) or not _RUN_ID.match(manifest.get("run_id", "")):
        problems.append("run_id malformed")
    sd, ed = parse_utc(manifest.get("started_utc")), parse_utc(manifest.get("ended_utc"))
    if sd is None or ed is None:
        problems.append("timestamps are not valid UTC")
    else:
        if ed < sd:
            problems.append("ended before started")
        elif not isinstance(manifest.get("duration_seconds"), int) or abs(manifest["duration_seconds"] - (ed - sd).total_seconds()) > 2:
            problems.append("duration inconsistent with timestamps")
    if not (isinstance(manifest.get("command"), list) and manifest["command"] and all(isinstance(c, str) for c in manifest["command"])):
        problems.append("command malformed")
    checks.append(_check("V03_MANIFEST_SCHEMA", FAIL if problems else PASS, "; ".join(problems) or "manifest schema, run id, timestamps and duration are valid"))
    if problems and ("timestamps are not valid UTC" in problems or "manifest keys differ from the schema" in problems):
        return {"result": FAIL, "tree_identity": TREE_UNVERIFIED, "checks": checks}

    # V04 exit code file
    raw_code = open(os.path.join(pkg_dir, "full-regression.exitcode"), encoding="utf-8", errors="replace").read().strip()
    exit_code = int(raw_code) if re.fullmatch(r'-?[0-9]{1,4}', raw_code) else None
    consistent = exit_code == manifest.get("exit_code")
    checks.append(_check("V04_EXIT_CODE", (INCONCLUSIVE if exit_code is None else PASS) if consistent else FAIL,
                         "exit code file is empty (run did not finish)" if exit_code is None else "exit code file matches the manifest" if consistent else "exit code file differs from the manifest"))

    # V05 log
    log_bytes = open(os.path.join(pkg_dir, "full-regression.log"), "rb").read()
    parsed = runlog.parse(log_bytes.decode("utf-8", errors="replace"))
    ver = manifest.get("results", {}).get("verified", {}) if isinstance(manifest.get("results"), dict) else {}
    same_counts = (ver.get("unique_scripts") == len(parsed["unique_scripts"]) and ver.get("passed") == len(parsed["passed_scripts"])
                   and ver.get("failed") == len(parsed["failed_scripts"]))
    checks.append(_check("V05_LOG_MATCHES_MANIFEST", PASS if same_counts else FAIL,
                         "counts re-derived from the delivered log equal the manifest" if same_counts else "counts re-derived from the log differ from the manifest"))

    # V06 fingerprints
    try:
        fpb = json.load(open(os.path.join(pkg_dir, "fingerprint-before.json"), encoding="utf-8"))
        fpa = json.load(open(os.path.join(pkg_dir, "fingerprint-after.json"), encoding="utf-8"))
        fp_ok = fingerprint.verify_self_consistency(fpb) and fingerprint.verify_self_consistency(fpa)
    except Exception:
        fpb = fpa = None
        fp_ok = False
    fp_ok = fp_ok and isinstance(manifest.get("fingerprint"), dict) and manifest["fingerprint"].get("before_sha256") == (fpb or {}).get("aggregate_sha256") \
        and manifest["fingerprint"].get("after_sha256") == (fpa or {}).get("aggregate_sha256")
    checks.append(_check("V06_FINGERPRINT_CONSISTENT", PASS if fp_ok else FAIL,
                         "fingerprints are self-consistent and match the manifest" if fp_ok else "fingerprint files are inconsistent or altered"))
    if not fp_ok:
        return {"result": FAIL, "tree_identity": TREE_UNVERIFIED, "checks": checks}

    # V07 privacy
    leak = sum(residual_personal_paths(open(os.path.join(pkg_dir, n), "rb").read()) for n in REQUIRED_FILES if n != "SHA256SUMS.txt")
    secrets_in_log = _secret_pattern_lines(log_bytes)
    checks.append(_check("V07_NO_PERSONAL_PATHS_OR_SECRETS", FAIL if (leak or secrets_in_log) else PASS,
                         f"{leak} line(s) with personal paths, {secrets_in_log} secret-shaped log line(s)" if (leak or secrets_in_log) else "no personal absolute paths or secret-shaped content in the artifacts"))

    # V08 git diff --check
    try:
        dc = int(open(os.path.join(pkg_dir, "git-diff-check.txt"), encoding="utf-8").readline().split(":")[1])
    except Exception:
        dc = None
    checks.append(_check("V08_GIT_DIFF_CHECK", PASS if dc == 0 else FAIL if dc is not None else INCONCLUSIVE,
                         "git diff --check exit 0" if dc == 0 else "git diff --check reported problems" if dc is not None else "git diff --check result missing"))

    # V09 verdict recomputation
    sec = manifest.get("security") if isinstance(manifest.get("security"), dict) and isinstance(manifest["security"].get("scripts"), list) else {"scripts": [], "all_passed": False}
    sec_names = [r.get("script", "") for r in sec["scripts"] if isinstance(r, dict)]
    recomputed_sec = _security_results(parsed, sec_names)
    result, tree, reasons = decide(parsed, exit_code, bool(manifest.get("timed_out")), fpb, fpa, recomputed_sec, dc if dc is not None else 1)
    claimed = manifest.get("verdict", {}).get("result") if isinstance(manifest.get("verdict"), dict) else None
    reproducible = claimed == result
    checks.append(_check("V09_VERDICT_REPRODUCIBLE", PASS if reproducible else FAIL,
                         f"verdict re-derived from the artifacts: {result}" if reproducible else f"manifest claims {claimed} but the artifacts give {result} ({','.join(reasons)})"))
    checks.append(_check("V10_RUN_OUTCOME", result, ",".join(reasons) or "complete run, exit 0, zero failures/skips/omissions, security scripts passed"))

    # V11 identity against the CURRENT tree
    if tree == TREE_CHANGED:
        checks.append(_check("V11_TREE_IDENTITY", INCONCLUSIVE, "the tree changed while the run was executing"))
        identity = TREE_CHANGED
    elif root is None:
        checks.append(_check("V11_TREE_IDENTITY", INCONCLUSIVE, "no repository root given: evidence cannot be tied to the current tree"))
        identity = TREE_UNVERIFIED
    else:
        current = fingerprint.take(root)
        if current["aggregate_sha256"] == fpa["aggregate_sha256"]:
            checks.append(_check("V11_TREE_IDENTITY", PASS, "current tree fingerprint equals the fingerprint captured before and after the run"))
            identity = TREE_VERIFIED
        else:
            d = fingerprint.diff(fpa, current)
            checks.append(_check("V11_TREE_IDENTITY", INCONCLUSIVE, f"evidence is for a different tree (added {len(d['added'])}, removed {len(d['removed'])}, changed {len(d['changed'])})"))
            identity = TREE_UNVERIFIED
    overall = worst([c["status"] for c in checks])
    return {"result": overall, "tree_identity": identity, "run_id": manifest.get("run_id"), "checks": checks,
            "verified": {"unique_scripts": len(parsed["unique_scripts"]), "passed": len(parsed["passed_scripts"]), "failed": len(parsed["failed_scripts"]),
                         "exit_code": exit_code}}
