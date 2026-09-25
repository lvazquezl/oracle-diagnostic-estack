"""
tests/p15/check_lab_security.py — NEGATIVE security checks of the LAB oracle_sql adapter and launcher.

Every case must fail CLOSED with a fixed code or fixed text, before any evidence is returned, and nothing raw
(secret, host, user, database/instance/service names) may reach an envelope, the audit or the CLI output.
"""
import ast
import glob
import json
import os
import time
from datetime import datetime, timedelta, timezone

from tests.p15.harness import (posix_test, ALIAS, DELETE, ROOT, SECRET, FakeKeychain, Lab, Scenario, driver_error, lab_target, leaks, profile_doc,
                               run_all, run_lab_cli, test, tmpdir, utc, write_private, write_targets)

ID = "Q-DISC-IDENTITY-001"
LAB_PKG = os.path.join(ROOT, "mcp_gateway_lab")
WRITE_STATEMENT = __import__("re").compile(
    r"(?i)^\s*(insert\s+into|update\s+\S+\s+set|delete\s+from|merge\s+into|create\s+(table|user|role|index|view|or|public|database)|"
    r"alter\s+(system|database|user|table|session|pluggable)|drop\s+\S|truncate\s|grant\s|revoke\s|begin\b|declare\b|call\s|commit\b|rollback\b)")


def refused(d, profile=None, targets=None, raw=None, mode=0o600):
    """Build must be refused with ProfileError/RuntimeError."""
    from mcp_gateway_lab.cli import build_lab_gateway
    from tests.p15.harness import FakeDriver
    prof = write_private(d, "lab-profile.json", profile or profile_doc(), mode=mode, raw=raw)
    tf = write_targets(d, targets or [lab_target()])
    try:
        build_lab_gateway(tf, prof, driver=FakeDriver(), credential_runner=FakeKeychain())
    except RuntimeError:
        return True
    return False


def denied(lab, code, capability_status=None, collector=ID):
    env, is_error = lab.collect(collector)
    assert is_error and env["error"]["code"] == code, (code, env.get("error"))
    assert env["evidence_refs"] == [] and "evidence" not in env
    text = json.dumps(env) + json.dumps(lab.gateway.audit.records)
    assert not leaks(text), leaks(text)
    return env


# --- lab profile ------------------------------------------------------------------------------------

@posix_test
def profile_with_a_secret_or_connect_string_anywhere_is_refused():
    for key, where in (("password", "connection"), ("wallet_password", "connection"), ("dsn", "connection"), ("token", "credential"),
                       ("secret", "authorization")):
        with tmpdir() as d:
            doc = profile_doc()
            doc["targets"][ALIAS][where][key] = SECRET
            assert refused(d, profile=doc), key


@posix_test
def profile_file_must_be_private_regular_owned_and_outside_the_repository():
    with tmpdir() as d:
        assert refused(d, mode=0o644), "group/world-readable profile accepted"
    with tmpdir() as d:
        assert refused(d, mode=0o640)
    with tmpdir() as d:
        from mcp_gateway_lab.cli import build_lab_gateway
        from tests.p15.harness import FakeDriver
        real = write_private(d, "real.json", profile_doc())
        link = os.path.join(d, "link.json")
        os.symlink(real, link)
        try:
            build_lab_gateway(write_targets(d, [lab_target()]), link, driver=FakeDriver(), credential_runner=FakeKeychain())
            raise AssertionError("symlinked profile accepted")
        except RuntimeError:
            pass
    inside = os.path.join(ROOT, ".p15-profile-inside-repo.json")
    try:
        with tmpdir() as d:
            with open(inside, "w") as f:
                json.dump(profile_doc(), f)
            os.chmod(inside, 0o600)
            from mcp_gateway_lab.cli import build_lab_gateway
            from tests.p15.harness import FakeDriver
            try:
                build_lab_gateway(write_targets(d, [lab_target()]), inside, driver=FakeDriver(), credential_runner=FakeKeychain())
                raise AssertionError("profile inside the repository accepted")
            except RuntimeError:
                pass
    finally:
        if os.path.exists(inside):
            os.remove(inside)


@posix_test
def profile_structure_scope_and_limits_fail_closed():
    now = datetime.now(timezone.utc)
    bad = [
        {"environment_class": "PRODUCTION"},
        {"expected.oracle_version_family": "21c"},
        {"expected.container": "PDB"},                                       # PDB without con_name
        {"connection.transport": "http"},
        {"connection.host": "db;rm -rf /"},
        {"connection.port": 0},
        {"connection.username": "SYS AS SYSDBA"},
        {"credential.provider": "env"},
        {"allowed_system_privileges": ["CREATE SESSION", "CREATE TABLE"]},
        {"allowed_system_privileges": ["DBA"]},
        {"allowed_system_privileges": []},
        {"limits.max_rows": 201},
        {"limits.call_timeout_ms": 60000},
        {"limits.max_output_bytes": 1_000_000},
        {"limits.connect_timeout_seconds": 0},
        {"authorization.expires_at_utc": utc(now - timedelta(minutes=1))},  # expired
        {"authorization.approved_at_utc": utc(now + timedelta(days=1))},     # not yet valid
        {"authorization.expires_at_utc": utc(now + timedelta(days=200))},    # window > 90 days
        {"authorization.approved_by": DELETE},
        {"connection.extra_option": "x"},                                    # unknown key
    ]
    for over in bad:
        with tmpdir() as d:
            assert refused(d, profile=profile_doc(**over)), over
    with tmpdir() as d:
        doc = profile_doc()
        doc["targets"]["lab-second"] = doc["targets"][ALIAS]
        assert refused(d, profile=doc), "two targets accepted"
    with tmpdir() as d:
        assert refused(d, raw='{"schema_version": "1.0.0", "schema_version": "1.0.0", "profile_id": "x", "targets": {}}'), "duplicate keys accepted"


# --- lab targets file --------------------------------------------------------------------------------

@posix_test
def lab_targets_file_must_register_exactly_the_profile_target_consistently():
    fixture_like = dict(lab_target(), alias="fixture-primary-19c", adapter="fixture")
    for targets in ([lab_target(), dict(lab_target(), alias="lab-other-19c")],
                    [lab_target(adapter="fixture")], [lab_target(enabled=False)], [lab_target(alias="lab-unknown-19c")],
                    [lab_target(allowed_collectors=["Q-DISC-IDENTITY-001", "Q-DG-STATS-001"])], [lab_target(allowed_collectors=[])],
                    [lab_target(oracle_version="21c")], [lab_target(role="STANDBY")], [lab_target(container="PDB")],
                    [lab_target(container="UNKNOWN")], [lab_target(host="db19-lab.example.internal")], [lab_target(password=SECRET)],
                    [fixture_like]):
        with tmpdir() as d:
            assert refused(d, targets=targets), targets


# --- runtime authorization, identity and privilege guards -----------------------------------------

@posix_test
def authorization_expiring_during_the_session_stops_collection_before_connecting():
    with tmpdir() as d:
        later = [datetime.now(timezone.utc)]
        lab = Lab(d, wallclock=lambda: later[0])
        assert not lab.collect()[1]
        later[0] = later[0] + timedelta(days=30)
        n = len(lab.driver.connects)
        denied(lab, "E_AUTHORIZATION_EXPIRED")
        assert len(lab.driver.connects) == n and lab.adapter.last_failure == "AUTHORIZATION_EXPIRED"


@posix_test
def connected_identity_must_match_the_authorized_target():
    cases = [
        (Scenario(id_version_full="21.3.0.0.0"), "MISMATCH_VERSION"),
        (Scenario(id_version_full="19c-bogus"), "MISMATCH_VERSION"),
        (Scenario(id_database_role="PHYSICAL STANDBY"), "MISMATCH_ROLE"),
        (Scenario(id_cdb="YES", session_con_name="CDB$ROOT"), "MISMATCH_CONTAINER"),
        (Scenario(id_db_name="OTHERDB"), "MISMATCH_DB_NAME"),
        (Scenario(session_service_name="OTHERSVC"), "MISMATCH_SERVICE_NAME"),
        (Scenario(session_sess_user="APP_OWNER"), "MISMATCH_SESSION_USER"),
        (Scenario(identity=[]), "MISMATCH_IDENTITY_ROW_COUNT"),
    ]
    two = Scenario()
    two.identity = two.identity * 2
    cases.append((two, "MISMATCH_IDENTITY_ROW_COUNT"))
    for sc, category in cases:
        with tmpdir() as d:
            lab = Lab(d, scenario=sc)
            denied(lab, "E_TARGET_MISMATCH")
            assert lab.adapter.last_failure == category, (category, lab.adapter.last_failure)
            assert lab.driver.events[-2:] == ["rollback", "close"] and "commit" not in lab.driver.events


@posix_test
def pdb_container_name_mismatch_is_refused():
    with tmpdir() as d:
        sc = Scenario(session_service_name="LABPDB1", session_con_name="LABPDB2", id_cdb="YES", id_db_name="LABCDB")
        prof = profile_doc(**{"connection.service_name": "LABPDB1", "expected.container": "PDB", "expected.con_name": "LABPDB1", "expected.db_name": "LABCDB"})
        lab = Lab(d, scenario=sc, profile=prof, targets=[lab_target(container="PDB")])
        denied(lab, "E_TARGET_MISMATCH")
        assert lab.adapter.last_failure == "MISMATCH_CONTAINER_NAME"


@posix_test
def privileged_or_over_granted_sessions_are_refused_before_the_identity_query():
    for sc, category in ((Scenario(session_isdba="TRUE"), "PRIVILEGED_SESSION"),
                         (Scenario(session_sess_user="SYS"), "PRIVILEGED_SESSION"),
                         (Scenario(session_sess_user="SYSTEM"), "PRIVILEGED_SESSION"),
                         (Scenario(session_sess_user="DBSNMP"), "PRIVILEGED_SESSION"),
                         (Scenario(privileges=["CREATE SESSION", "CREATE TABLE"]), "EXCESSIVE_SYSTEM_PRIVILEGES"),
                         (Scenario(privileges=["CREATE SESSION", "SELECT ANY TABLE"]), "EXCESSIVE_SYSTEM_PRIVILEGES"),
                         (Scenario(privileges=["CREATE SESSION", "SELECT ANY DICTIONARY"]), "EXCESSIVE_SYSTEM_PRIVILEGES"),
                         (Scenario(privileges=["CREATE SESSION"] + [f"PRIV {i}" for i in range(80)]), "EXCESSIVE_SYSTEM_PRIVILEGES")):
        with tmpdir() as d:
            lab = Lab(d, scenario=sc)
            denied(lab, "E_PRIVILEGES_EXCESSIVE")
            assert lab.adapter.last_failure == category, (category, lab.adapter.last_failure)
            assert not any("v$instance" in s.lower() for s in lab.driver.statements), "identity query ran on a refused session"


@posix_test
def thick_mode_is_refused():
    for sc in (Scenario(thin_mode=False), Scenario(conn_thin=False)):
        with tmpdir() as d:
            lab = Lab(d, scenario=sc)
            denied(lab, "E_ADAPTER_FAILED")
            assert lab.adapter.last_failure == "THICK_MODE_REFUSED"
            assert not any("v$instance" in s.lower() for s in lab.driver.statements)


# --- SQL source integrity ----------------------------------------------------------------------------

@posix_test
def a_certified_query_changed_after_startup_is_never_executed():
    with tmpdir() as d:
        lab = Lab(d)
        lab.gateway.collectors[ID].query_sha256 = "0" * 64          # what a post-startup edit of the query file looks like
        denied(lab, "E_ADAPTER_FAILED")
        assert lab.adapter.last_failure == "SQL_SOURCE_REFUSED" and lab.driver.connects == [] and lab.keychain.calls == []


@posix_test
def collectors_the_adapter_does_not_implement_are_denied_even_if_forced():
    from mcp_gateway_lab import oracle_sql
    with tmpdir() as d:
        lab = Lab(d)
        denied(lab, "E_COLLECTOR_NOT_ALLOWED", collector="Q-ORA-RESOURCE-LIMITS-001")      # implemented but not allowed by the target
        target = lab.gateway.targets[ALIAS]
        for cid in ("Q-ORA-PROCESSES-SUMMARY-001", "Q-CDB-TEMP-001", "Q-DG-STATS-001", "Q-ORA-DIAGNOSTICS-ALERTLOG-001", "os.get_process_limits"):
            try:
                lab.adapter.fetch(target, lab.gateway.collectors[cid], {})               # adapter defense in depth
                raise AssertionError("adapter ran an unimplemented collector")
            except Exception as e:
                assert getattr(e, "code", None) == "E_COLLECTOR_NOT_ALLOWED", cid
        assert set(oracle_sql.SUPPORTED_COLLECTORS) == {ID, "Q-ORA-RESOURCE-LIMITS-001", "Q-CDB-TABLESPACES-001", "Q-RMAN-FRA-USAGE-001",
                                                         "Q-RMAN-BACKUP-FRESHNESS-001", "Q-RMAN-JOB-SUMMARY-001",
                                                         *("Q-DICT-VERIFY-%03d" % i for i in range(1, 6))}
        assert lab.driver.connects == []
    with tmpdir() as d:                                                              # the launcher refuses such a target file
        assert refused(d, targets=[lab_target(allowed_collectors=[ID, "Q-DG-STATS-001"])])
    with tmpdir() as d:                                                              # least privilege: not implemented on purpose
        assert refused(d, targets=[lab_target(allowed_collectors=[ID, "Q-ORA-RESOURCE-LIMITS-001", "Q-ORA-PROCESSES-SUMMARY-001"])])
    with tmpdir() as d:                                                              # lab-validated partial result: not implemented
        assert refused(d, targets=[lab_target(container="CDB_ROOT", allowed_collectors=[ID, "Q-CDB-TEMP-001"])],
                       profile=profile_doc(**{"expected.container": "CDB_ROOT"}))


@posix_test
def tool_arguments_cannot_carry_sql_connection_or_paths():
    with tmpdir() as d:
        lab = Lab(d)
        for extra in ({"sql": "select 1 from dual"}, {"dsn": "h:1521/s"}, {"host": "x"}, {"password": SECRET}, {"path": "/etc/passwd"},
                      {"query": "delete from t"}):
            env, is_error = lab.collect(**extra)
            assert is_error and env["error"]["code"] == "E_ARGS_INVALID", extra
        env, is_error = lab.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001; drop table x", "target_alias": ALIAS})
        assert is_error and env["error"]["code"] in ("E_ARGS_INVALID", "E_COLLECTOR_UNKNOWN")
        assert lab.driver.connects == [] and not leaks(json.dumps(lab.gateway.audit.records))


# --- result limits -----------------------------------------------------------------------------------

@posix_test
def non_scalar_oversized_or_too_large_results_are_refused():
    for value, category in ((b"\x00LOB", "RESULT_TYPE_REFUSED"), (datetime.now(), "RESULT_TYPE_REFUSED"), ({"x": 1}, "RESULT_TYPE_REFUSED"),
                            ("A" * 300, "RESULT_VALUE_TOO_LONG")):
        with tmpdir() as d:
            sc = Scenario()
            sc.identity = [dict(sc.identity[0], instance_name=value)]
            lab = Lab(d, scenario=sc)
            denied(lab, "E_RESULT_INVALID")
            assert lab.adapter.last_failure == category
    with tmpdir() as d:
        sc = Scenario(id_instance_name="I" * 250)
        lab = Lab(d, scenario=sc, profile=profile_doc(**{"limits.max_output_bytes": 256}))
        denied(lab, "E_OUTPUT_TOO_LARGE")


@posix_test
def a_hung_query_times_out_and_blocks_concurrent_calls_until_the_driver_returns():
    with tmpdir() as d:
        lab = Lab(d, scenario=Scenario(identity_delay=1.5), operation_timeout=0.4)
        t0 = time.monotonic()
        denied(lab, "E_TIMEOUT")
        assert time.monotonic() - t0 < 1.2, "the gateway deadline did not bound the call"
        denied(lab, "E_BUSY")
        time.sleep(1.6)
        lab.driver.s.identity_delay = 0
        lab.gateway.operation_timeout = 15.0
        env, is_error = lab.collect()
        assert not is_error, env
        assert lab.driver.events.count("close") == len(lab.driver.connects), "every connection was closed"


@posix_test
def call_timeouts_never_exceed_the_profile_cap():
    with tmpdir() as d:
        lab = Lab(d, profile=profile_doc(**{"limits.call_timeout_ms": 1500}))
        conns = []
        real_connect = lab.driver.connect
        lab.driver.connect = lambda **kw: conns.append(real_connect(**kw)) or conns[-1]
        assert not lab.collect()[1]
        ts = conns[0].call_timeouts
        assert ts and all(200 <= t <= 1500 for t in ts), ts


# --- secrets and driver errors -----------------------------------------------------------------------

@posix_test
def driver_errors_never_leak_messages_secrets_or_coordinates():
    for code, category in (("ORA-01017", "CREDENTIALS_REJECTED"), ("ORA-28000", "ACCOUNT_LOCKED"), ("ORA-12514", "SERVICE_NOT_REGISTERED"),
                           ("DPY-6005", "NETWORK_UNREACHABLE"), ("DPY-3001", "NATIVE_NETWORK_ENCRYPTION_NEEDS_THICK_MODE"),
                           ("DPY-6999", "NETWORK_OR_LISTENER"), ("ORA-99999", "DRIVER_ERROR")):
        with tmpdir() as d:
            lab = Lab(d, scenario=Scenario(connect_error=driver_error(code)))
            denied(lab, "E_ADAPTER_FAILED")
            assert lab.adapter.last_failure == category, (code, lab.adapter.last_failure)
    with tmpdir() as d:
        lab = Lab(d, scenario=Scenario(identity_error=driver_error("ORA-00942")))
        denied(lab, "E_ADAPTER_FAILED")
        assert lab.adapter.last_failure == "MISSING_OBJECT_PRIVILEGE" and lab.driver.events[-2:] == ["rollback", "close"]


@posix_test
def keychain_failures_fail_closed_without_connecting():
    for kc in (FakeKeychain(rc=44), FakeKeychain(out=b""), FakeKeychain(out=b"two\nlines\n"), FakeKeychain(out=b"\xff\xfe"),
               FakeKeychain(out=b"x" * 5000)):
        with tmpdir() as d:
            lab = Lab(d, keychain=kc)
            denied(lab, "E_ADAPTER_FAILED")
            assert lab.adapter.last_failure == "CREDENTIAL_UNAVAILABLE" and lab.driver.connects == []


# --- launcher ----------------------------------------------------------------------------------------

@test
def lab_cli_has_no_connection_sql_or_secret_flags_and_never_echoes_input():
    rc, out, err = run_lab_cli("serve", "--help")
    assert rc == 0
    import re
    assert not re.search(r"--(dsn|host|port|user|username|password|sql|query|shell|exec|connect|wallet|enable|real|adapter|collector)\b", out), out
    for bad in (["--bogus"], ["serve", "--dsn", SECRET], ["serve", "--targets", "/x"], ["check", "--password", SECRET], ["frobnicate"], []):
        rc, out, err = run_lab_cli(*bad)
        assert rc == 2 and out == "" and SECRET not in err and err.strip() in ("mcp_gateway_lab: invalid command line usage",), (bad, err)


@posix_test
def startup_refusals_are_fixed_text_and_environment_variables_change_nothing():
    with tmpdir() as d:
        prof = write_private(d, "lab-profile.json", profile_doc(), mode=0o644)
        rc, out, err = run_lab_cli("validate-config", "--targets", write_targets(d, [lab_target()]), "--lab-profile", prof)
        assert rc == 2 and out == "" and err.startswith("mcp_gateway_lab: startup refused (") and not leaks(err)
    with tmpdir() as d:
        prof = write_private(d, "lab-profile.json", profile_doc())
        tf = write_targets(d, [lab_target()])
        base = run_lab_cli("validate-config", "--targets", tf, "--lab-profile", prof)
        hostile = {"ORACLE_PASSWORD": SECRET, "TNS_ADMIN": "/nonexistent", "MCP_GATEWAY_ENABLE_REAL": "1", "ESTACK_LAB_DSN": "evil:1521/x",
                   "MCP_GATEWAY_ADAPTER": "oracle_sql"}
        other = run_lab_cli("validate-config", "--targets", tf, "--lab-profile", prof, env_extra=hostile)
        assert base == other and base[0] == 0
    rc, out, err = run_lab_cli("validate-config", "--targets", "/nonexistent.json", "--lab-profile", "/nonexistent.json", fake_driver=True)
    assert rc == 2 and out == ""


@posix_test
def missing_driver_is_a_fixed_startup_refusal():
    import subprocess, sys
    with tmpdir() as d:
        prof = write_private(d, "lab-profile.json", profile_doc())
        tf = write_targets(d, [lab_target()])
        blocker = os.path.join(d, "blk")
        os.makedirs(os.path.join(blocker, "oracledb"))
        with open(os.path.join(blocker, "oracledb", "__init__.py"), "w") as f:
            f.write("raise ImportError('blocked for test')\n")
        env = {"PATH": "/usr/bin:/bin", "PYTHONPATH": os.pathsep.join([blocker, ROOT]), "PYTHONDONTWRITEBYTECODE": "1"}
        p = subprocess.run([sys.executable, "-m", "mcp_gateway_lab", "validate-config", "--targets", tf, "--lab-profile", prof],
                           capture_output=True, text=True, cwd=ROOT, env=env, timeout=60)
        assert p.returncode == 2 and p.stdout == "" and "python-oracledb is not installed" in p.stderr


# --- the default runtime is unchanged ------------------------------------------------------------------

@test
def default_gateway_still_cannot_run_oracle_sql_and_never_imports_the_lab_package():
    for path in glob.glob(os.path.join(ROOT, "mcp_gateway", "*.py")):
        tree = ast.parse(open(path, encoding="utf-8").read())
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
                assert not any(m.split(".")[0] in ("mcp_gateway_lab", "oracledb") for m in mods), path
    from mcp_gateway.cli import build_gateway
    g = build_gateway()
    assert g.adapters.describe()["oracle_sql"] == "DISABLED" and g.lab_mode is False


@test
def lab_package_static_scan_no_network_eval_env_commit_or_thick_mode():
    subprocess_users = []
    for path in sorted(glob.glob(os.path.join(LAB_PKG, "*.py"))):
        src = open(path, encoding="utf-8").read()
        tree = ast.parse(src)
        base = os.path.basename(path)
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
                for m in mods:
                    top = m.split(".")[0]
                    assert top not in ("socket", "ssl", "http", "urllib", "requests", "pickle", "ctypes", "importlib", "asyncio", "multiprocessing"), (base, m)
                    if top == "subprocess":
                        subprocess_users.append(base)
            elif isinstance(node, ast.Call):
                fn = node.func
                if isinstance(fn, ast.Name):
                    assert fn.id not in ("eval", "exec", "compile", "__import__"), (base, fn.id)
                elif isinstance(fn, ast.Attribute):
                    assert fn.attr not in ("commit", "init_oracle_client", "system", "popen", "getenv", "putenv", "executemany", "callproc", "callfunc"), (base, fn.attr)
            elif isinstance(node, ast.Attribute) and node.attr in ("environ",):
                raise AssertionError(f"{base} reads the environment")
            elif isinstance(node, ast.Constant) and isinstance(node.value, str) and WRITE_STATEMENT.match(node.value):
                raise AssertionError(f"{base} carries a write/PLSQL statement literal")
        assert "shell=True" not in src
    assert subprocess_users == ["credentials.py"], subprocess_users



# --- CHG-ESTACK-ORA19C-LAB-002 -----------------------------------------------------------------------------

ALL = [ID, "Q-ORA-RESOURCE-LIMITS-001"]


@posix_test
def a_missing_object_grant_fails_closed_after_the_guards_without_partial_evidence():
    with tmpdir() as d:
        lab = Lab(d, scenario=Scenario(main_error=driver_error("ORA-00942")), targets=[lab_target(allowed_collectors=ALL)])
        denied(lab, "E_ADAPTER_FAILED", collector="Q-ORA-RESOURCE-LIMITS-001")
        assert lab.adapter.last_failure == "MISSING_OBJECT_PRIVILEGE"
        assert "commit" not in lab.driver.events and lab.driver.events[-2:] == ["rollback", "close"]


@posix_test
def the_new_collectors_still_require_the_identity_guard_first():
    with tmpdir() as d:
        lab = Lab(d, scenario=Scenario(id_db_name="OTHERDB"), targets=[lab_target(allowed_collectors=ALL)])
        denied(lab, "E_TARGET_MISMATCH", collector="Q-ORA-RESOURCE-LIMITS-001")
        assert not any("v$resource_limit" in s.lower() for s in lab.driver.statements), "the requested query ran before identity was proven"


@posix_test
def numeric_strings_are_converted_only_when_strictly_numeric():
    with tmpdir() as d:
        sc = Scenario()
        sc.resource_limits = [{"resource_name": "processes", "current_utilization": 1, "max_utilization": 2, "limit_value": "12abc"},
                              {"resource_name": "sessions", "current_utilization": 1, "max_utilization": 2, "limit_value": "-5"},
                              {"resource_name": "open_cursors", "current_utilization": 1, "max_utilization": 2, "limit_value": "1e3"},
                              {"resource_name": "dml_locks", "current_utilization": "7", "max_utilization": 2, "limit_value": "unlimited"}]
        sc.resource_limits.append({"resource_name": "enqueue_locks", "current_utilization": 1, "max_utilization": 2, "limit_value": "9" * 16})
        lab = Lab(d, scenario=sc, targets=[lab_target(allowed_collectors=ALL)])
        env, is_error = lab.collect("Q-ORA-RESOURCE-LIMITS-001")
        assert not is_error
        rows = {r["resource_name"]: r for r in env["evidence"]["rows"]}
        assert all("limit_value" not in rows[k] for k in ("processes", "sessions", "open_cursors", "enqueue_locks")), rows
        assert rows["dml_locks"]["limit_value"] == "UNLIMITED" and rows["dml_locks"]["current_utilization"] == 7


@test
def implicit_variant_requires_a_compatible_matrix_entry_for_the_same_file():
    import shutil
    from mcp_gateway import catalog
    from mcp_gateway_lab import sqlsource
    col = catalog.load_collectors()["Q-ORA-RESOURCE-LIMITS-001"]
    assert sqlsource.resolve(col, "19.0").variant_id == "Q-ORA-RESOURCE-LIMITS-001-IMPLICIT"
    original = sqlsource.MATRIX_FILE
    text = open(original, encoding="utf-8").read()
    line = next(l for l in text.splitlines() if l.startswith("  Q-ORA-RESOURCE-LIMITS-001:"))
    tampered = {
        "not compatible": line.replace("validation_status: COMPATIBLE", "validation_status: INCORRECT_VERSION_RANGE"),
        "explicit variants": line.replace("variants: implicit_full_range", "variants: explicit"),
        "other file": line.replace("resources/Q-ORA-RESOURCE-LIMITS-001.md", "processes/Q-ORA-PROCESSES-SUMMARY-001.md"),
        "range excludes 19c": line.replace('min: "10.2", max: latest', 'min: "10.2", max: "18.0"'),
        "entry missing": "",
        "duplicate entry": line + "\n" + line,
    }
    with tmpdir() as d:
        try:
            for why, repl in tampered.items():
                path = os.path.join(d, why.replace(" ", "-") + ".yaml")
                open(path, "w", encoding="utf-8").write(text.replace(line, repl))
                sqlsource.MATRIX_FILE = path
                try:
                    sqlsource.resolve(col, "19.0")
                    raise AssertionError("implicit variant accepted: " + why)
                except sqlsource.SqlSourceError:
                    pass
            sqlsource.MATRIX_FILE = os.path.join(d, "absent.yaml")
            try:
                sqlsource.resolve(col, "19.0")
                raise AssertionError("implicit variant accepted without a matrix")
            except sqlsource.SqlSourceError:
                pass
        finally:
            sqlsource.MATRIX_FILE = original
    for version in ("9.2", "abc"):
        try:
            sqlsource.resolve(col, version)
            raise AssertionError("resolved outside the certified range: " + version)
        except sqlsource.SqlSourceError:
            pass



@posix_test
def a_cdb_root_profile_refuses_a_session_that_lands_in_a_pdb():
    prof = profile_doc(**{"connection.username": "C##ESTACK_DIAG", "connection.service_name": "LABCDB",
                          "expected.container": "CDB_ROOT", "expected.db_name": "LABCDB"})
    with tmpdir() as d:
        sc = Scenario(session_service_name="LABCDB", session_con_name="PRUEBAS", session_sess_user="C##ESTACK_DIAG",
                      id_db_name="LABCDB", id_cdb="YES")
        lab = Lab(d, scenario=sc, profile=prof, targets=[lab_target(container="CDB_ROOT", allowed_collectors=ALL)])
        denied(lab, "E_TARGET_MISMATCH", collector="Q-ORA-RESOURCE-LIMITS-001")
        assert lab.adapter.last_failure == "MISMATCH_CONTAINER"
        assert not any("v$resource_limit" in s.lower() for s in lab.driver.statements)
    with tmpdir() as d:                                                    # registration and profile must agree on the container
        assert refused(d, profile=prof, targets=[lab_target(container="PDB", allowed_collectors=ALL)])



# --- CHG-ESTACK-ORA19C-LAB-003 -----------------------------------------------------------------------------

@posix_test
def cdb_root_only_collectors_are_not_applicable_outside_cdb_root_and_never_connect():
    from mcp_gateway import catalog
    for container, expected in (("PDB", "NOT_APPLICABLE"), ("NON_CDB", "NOT_APPLICABLE")):
        with tmpdir() as d:
            prof = profile_doc(**{"expected.container": container, **({"expected.con_name": "LABPDB1"} if container == "PDB" else {})})
            sc = Scenario(session_con_name="LABPDB1") if container == "PDB" else None
            lab = Lab(d, scenario=sc, profile=prof,
                      targets=[lab_target(container=container, allowed_collectors=[ID, "Q-CDB-TABLESPACES-001"])])
            for cid in ("Q-CDB-TABLESPACES-001",):
                env = denied(lab, "E_CAPABILITY", collector=cid)
                assert env["capability_status"] == expected, env
            assert lab.driver.connects == [], "a NOT_APPLICABLE collector must be refused before any connection"
    t = catalog.Target({"alias": "x-unknown", "adapter": "fixture", "enabled": True, "oracle_version": "19c", "container": "UNKNOWN",
                        "allowed_collectors": ["Q-CDB-TABLESPACES-001"]})
    col = catalog.load_collectors()["Q-CDB-TABLESPACES-001"]
    assert catalog.evaluate_capability(t, col, "VERIFIED_FIXTURE") == "ENVIRONMENT_UNKNOWN"


@posix_test
def raised_profile_ceilings_still_fail_closed_above_their_bounds():
    for key, bad in (("max_rows", 201), ("max_output_bytes", 65537), ("call_timeout_ms", 20001), ("max_rows", 0)):
        with tmpdir() as d:
            assert refused(d, profile=profile_doc(**{"limits." + key: bad})), (key, bad)
    with tmpdir() as d:
        assert not refused(d, profile=profile_doc(**{"limits.max_rows": 200, "limits.max_output_bytes": 65536, "limits.call_timeout_ms": 20000}))


@posix_test
def output_byte_ceiling_is_enforced_on_multi_row_results():
    with tmpdir() as d:
        prof = profile_doc(**{"connection.username": "C##ESTACK_DIAG", "connection.service_name": "LABCDB", "expected.container": "CDB_ROOT",
                              "expected.db_name": "LABCDB", "limits.max_rows": 200, "limits.max_output_bytes": 512})
        sc = Scenario(session_service_name="LABCDB", session_con_name="CDB$ROOT", session_sess_user="C##ESTACK_DIAG", id_db_name="LABCDB", id_cdb="YES")
        sc.tablespaces = [dict(sc.tablespaces[0], tablespace_name=f"TS{i}") for i in range(40)]
        lab = Lab(d, scenario=sc, profile=prof, targets=[lab_target(container="CDB_ROOT", allowed_collectors=[ID, "Q-CDB-TABLESPACES-001"])])
        denied(lab, "E_OUTPUT_TOO_LARGE", collector="Q-CDB-TABLESPACES-001")



# --- CHG-ESTACK-ORA19C-LAB-004 -----------------------------------------------------------------------------

@posix_test
def a_driver_date_value_is_refused_never_converted():
    import datetime as _dt
    with tmpdir() as d:
        sc = Scenario()
        sc.freshness = [{"backup_kind": "FULL_OR_LEVEL0", "record_count": 1, "hours_since_last": _dt.datetime(2026, 9, 1, 3, 0)}]
        lab = Lab(d, scenario=sc, targets=[lab_target(allowed_collectors=[ID, "Q-RMAN-BACKUP-FRESHNESS-001"])])
        denied(lab, "E_RESULT_INVALID", collector="Q-RMAN-BACKUP-FRESHNESS-001")
        assert lab.adapter.last_failure == "RESULT_TYPE_REFUSED"


@posix_test
def out_of_range_or_textual_ages_are_dropped_and_reported():
    with tmpdir() as d:
        sc = Scenario()
        sc.jobs = [{"input_type": "DB FULL", "jobs_total": 1, "last_status": "COMPLETED", "hours_since_last_start": -500.0,
                    "hours_since_last_success": "180.5", "failed_last_7d": 0, "last_elapsed_seconds": 10}]
        lab = Lab(d, scenario=sc, targets=[lab_target(allowed_collectors=[ID, "Q-RMAN-JOB-SUMMARY-001"])])
        env, is_error = lab.collect("Q-RMAN-JOB-SUMMARY-001")
        assert not is_error and env["status"] == "DEGRADED", env
        row, = env["evidence"]["rows"]
        assert "hours_since_last_start" not in row and "hours_since_last_success" not in row
        assert any(l.startswith("INVALID_VALUES_DROPPED") for l in env["limitations"]), env["limitations"]



# --- CHG-ESTACK-ORA19C-LAB-006: dictionary verification -----------------------------------------------------

@posix_test
def dictionary_verification_never_lets_a_name_outside_its_part_of_the_dictionary_leave():
    with tmpdir() as d:
        sc = Scenario()
        sc.dictverify = [{"finding": "COLUMN_NOT_FOUND", "view_name": "EMPLOYEES", "column_name": "SALARY", "tokens": 1},
                         {"finding": "COLUMN_NOT_FOUND", "view_name": "V$DATABASE", "column_name": "SSN", "tokens": 1},
                         {"finding": "CHECKED", "view_name": "*", "column_name": "*", "tokens": 94}]
        lab = Lab(d, scenario=sc, targets=[lab_target(allowed_collectors=[ID, "Q-DICT-VERIFY-003"])])
        env, is_error = lab.collect("Q-DICT-VERIFY-003")
        assert not is_error and env["status"] == "DEGRADED", env
        text = json.dumps(env)
        assert "EMPLOYEES" not in text and "SALARY" not in text and "SSN" not in text, "application-like names never leave"
        assert any(l.startswith("INVALID_VALUES_DROPPED") for l in env["limitations"]), env["limitations"]


# --- CHG-ESTACK-PORTABILITY-001 (run on every platform) -------------------------------------------------------

@test
def non_posix_hosts_are_refused_with_fixed_text_instead_of_a_traceback():
    from mcp_gateway_lab import profile
    saved = getattr(os, "getuid", None)
    if saved is not None:
        delattr(os, "getuid")                                   # simulate a host without POSIX owner checks
    try:
        try:
            profile.check_private_file(os.path.abspath(__file__))
            raise AssertionError("a non-POSIX host was accepted")
        except profile.ProfileError as e:
            assert str(e) == "the lab launcher requires a POSIX host (owner-only file checks are not available here)", str(e)
    finally:
        if saved is not None:
            os.getuid = saved


@test
def the_keychain_provider_is_refused_at_startup_off_macos_when_no_test_runner_is_injected():
    import sys
    from mcp_gateway_lab import cli, profile
    from tests.p15.harness import FakeDriver
    saved = sys.platform
    with tmpdir() as d:
        prof = write_private(d, "lab-profile.json", profile_doc())
        tf = write_targets(d, [lab_target()])
        sys.platform = "linux"
        try:
            try:
                cli.build_lab_gateway(tf, prof, driver=FakeDriver())          # no credential_runner: production path
                raise AssertionError("macos_keychain accepted off macOS")
            except profile.ProfileError as e:
                assert str(e) in ("the macos_keychain credential provider requires macOS",
                                  "the lab launcher requires a POSIX host (owner-only file checks are not available here)"), str(e)
        finally:
            sys.platform = saved


if __name__ == "__main__":
    raise SystemExit(run_all())
