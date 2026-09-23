"""
tests/p15/check_lab_adapter.py — FUNCTIONAL checks of the LAB oracle_sql adapter through the real gateway path
(build_lab_gateway -> Gateway -> OracleSqlAdapter -> sanitize_rows), with a fake driver and a fake Keychain.
"""
import hashlib
import io
import json

from tests.p15.harness import (ALIAS, SECRET, Lab, Scenario, leaks, profile_doc, run_all, run_lab_cli, test, tmpdir, write_private,
                               write_targets, lab_target)

ID = "Q-DISC-IDENTITY-001"


@test
def identity_collection_returns_real_sanitized_evidence():
    with tmpdir() as d:
        lab = Lab(d)
        env, is_error = lab.collect()
        assert not is_error and env["status"] == "OK", env
        assert env["provenance"] == {"kind": "REAL", "real_observation": True}
        assert env["collected_at_utc"] and env["collected_at_utc"].endswith("+00:00")
        assert env["sanitization_status"] == "SANITIZED" and env["capability_status"] == "SUPPORTED"
        row, = env["evidence"]["rows"]
        assert row == {"instance_name": "inst-A1", "version": "19.27.0.0.0", "db_name": "db-A1", "database_role": "PRIMARY",
                       "cdb": "NO", "open_mode": "READ WRITE"}, row
        assert env["limitations"] == [] and len(env["evidence_refs"]) == 1
        text = json.dumps(env)
        assert not leaks(text), leaks(text)


@test
def get_evidence_and_analyze_keep_real_provenance():
    with tmpdir() as d:
        lab = Lab(d)
        env, _ = lab.collect()
        ref = env["evidence_refs"][0]
        got, is_error = lab.call("diagnostics.get_evidence", {"evidence_ref": ref, "target_alias": ALIAS})
        assert not is_error and got["provenance"] == {"kind": "REAL", "real_observation": True}
        assert got["evidence"]["digest"] == env["evidence"]["digest"] and got["collected_at_utc"] == env["collected_at_utc"]
        ana, is_error = lab.call("diagnostics.analyze_incident", {"target_alias": ALIAS, "evidence_refs": [ref]})
        assert ana["provenance"]["kind"] == "REAL" if not is_error else ana["error"]["code"] in ("E_INSUFFICIENT_EVIDENCE", "E_ANALYSIS_FAILED")


@test
def only_certified_and_guard_sql_is_executed_in_a_read_only_transaction():
    from mcp_gateway import catalog
    from mcp_gateway_lab import oracle_sql
    with tmpdir() as d:
        lab = Lab(d)
        lab.collect()
        st = lab.driver.statements
        assert st[:3] == [oracle_sql.READ_ONLY_TRANSACTION, oracle_sql.GUARD_SESSION_SQL, oracle_sql.GUARD_PRIVILEGES_SQL], st[:3]
        assert len(st) == 4
        text = open(catalog._find_query_file(ID), encoding="utf-8").read()
        v3 = [b for b in catalog.sql_blocks(text) if "i.version_full," in b]
        assert len(v3) == 1 and st[3] == v3[0].rstrip().rstrip(";").rstrip(), "the 19c session runs the certified V3 variant verbatim"
        assert hashlib.sha256("\n".join(catalog.sql_blocks(text)).encode()).hexdigest() == lab.gateway.collectors[ID].query_sha256
        assert "commit" not in lab.driver.events and lab.driver.events[-2:] == ["rollback", "close"]


@test
def connection_uses_profile_coordinates_thin_mode_no_retries_and_bounded_timeouts():
    with tmpdir() as d:
        lab = Lab(d)
        lab.collect()
        kw, = lab.driver.connects
        assert kw == {"user": "ESTACK_DIAG", "host": "db19-lab.example.internal", "port": 1521, "service_name": "LAB19C", "protocol": "tcp",
                      "tcp_connect_timeout": 5.0, "retry_count": 0, "retry_delay": 0, "program": "estack-diag-lab"}, kw
        assert lab.driver.password_ok == [True], "the Keychain password is handed to connect only"
        assert all(0 < n <= 65 for n in lab.driver.fetch_sizes)
        assert max(lab.driver.fetch_sizes[-1:]) <= 2, "identity fetch is bounded to 1 row + 1 truncation probe"


@test
def tcps_transport_requests_server_dn_match():
    with tmpdir() as d:
        prof = profile_doc(**{"connection.transport": "tcps", "connection.port": 2484,
                              "connection.tcps": {"server_cert_dn": "CN=db19-lab.example.internal,O=Lab"}})
        lab = Lab(d, profile=prof)
        env, is_error = lab.collect()
        assert not is_error, env
        kw, = lab.driver.connects
        assert kw["protocol"] == "tcps" and kw["ssl_server_dn_match"] is True and kw["ssl_server_cert_dn"].startswith("CN=")


@test
def keychain_lookup_uses_a_fixed_argv_without_shell_and_a_minimal_environment():
    with tmpdir() as d:
        lab = Lab(d)
        lab.collect()
        (argv, kw), = lab.keychain.calls
        assert argv == ["/usr/bin/security", "find-generic-password", "-s", "oracle-estack-lab", "-a", ALIAS, "-w"]
        assert kw["shell"] is False and kw["env"] == {"PATH": "/usr/bin:/bin", "LANG": "C"} and kw["timeout"] <= 5
        assert kw["check"] is False and kw["capture_output"] is True


@test
def password_is_fetched_per_connection_and_never_retained():
    with tmpdir() as d:
        lab = Lab(d)
        lab.collect()
        lab.collect()
        assert len(lab.keychain.calls) == 2 and len(lab.driver.connects) == 2
        blob = json.dumps(vars(lab.adapter), default=str) + json.dumps(lab.driver.connects)
        assert SECRET not in blob


@test
def undeclared_columns_and_nulls_are_minimized_at_the_source():
    with tmpdir() as d:
        sc = Scenario()
        sc.identity = [dict(sc.identity[0], host_name="db19-lab.example.internal", open_mode=None)]
        lab = Lab(d, scenario=sc)
        env, is_error = lab.collect()
        assert not is_error
        row, = env["evidence"]["rows"]
        assert "host_name" not in row and "open_mode" not in row and not leaks(json.dumps(env))


@test
def pdb_target_is_validated_by_container_name():
    with tmpdir() as d:
        sc = Scenario(session_service_name="LABPDB1", session_con_name="LABPDB1", id_cdb="YES", id_db_name="LABCDB")
        prof = profile_doc(**{"connection.service_name": "LABPDB1", "expected.container": "PDB", "expected.con_name": "LABPDB1",
                              "expected.db_name": "LABCDB"})
        lab = Lab(d, scenario=sc, profile=prof, targets=[lab_target(container="PDB")])
        env, is_error = lab.collect()
        assert not is_error and env["evidence"]["rows"][0]["cdb"] == "YES", env


@test
def select_any_dictionary_is_accepted_only_when_the_profile_opts_in():
    with tmpdir() as d:
        sc = Scenario(privileges=["CREATE SESSION", "SELECT ANY DICTIONARY"])
        lab = Lab(d, scenario=sc, profile=profile_doc(**{"allowed_system_privileges": ["CREATE SESSION", "SELECT ANY DICTIONARY"]}))
        env, is_error = lab.collect()
        assert not is_error, env


@test
def mcp_protocol_in_lab_mode_announces_lab_provenance_and_keeps_the_static_tool_surface():
    from mcp_gateway.gateway import TOOLS
    from mcp_gateway.server import McpServer
    with tmpdir() as d:
        lab = Lab(d)
        out, err = io.BytesIO(), io.StringIO()
        srv = McpServer(lab.gateway, out=out, err=err)
        for i, (m, p) in enumerate([("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "t", "version": "0"}}),
                                    (None, None), ("tools/list", {}),
                                    ("tools/call", {"name": "diagnostics.list_capabilities", "arguments": {}}),
                                    ("tools/call", {"name": "diagnostics.collect", "arguments": {"collector_id": ID, "target_alias": ALIAS}})]):
            msg = {"jsonrpc": "2.0", "method": "notifications/initialized"} if m is None else {"jsonrpc": "2.0", "id": i, "method": m, "params": p}
            srv.handle_line(json.dumps(msg).encode())
        replies = {r["id"]: r for r in (json.loads(l) for l in out.getvalue().decode().splitlines() if l.strip())}
        assert "LAB launcher" in replies[0]["result"]["instructions"] and "synthetic fixture data" not in replies[0]["result"]["instructions"]
        tools = replies[2]["result"]["tools"]
        assert [t["name"] for t in tools] == list(TOOLS) and all(t["inputSchema"] == TOOLS[t["name"]]["inputSchema"] for t in tools)
        assert "SYNTHETIC" not in json.dumps(tools)
        caps = replies[3]["result"]["structuredContent"]
        assert caps["adapters"]["oracle_sql"] == "LAB_ENABLED"
        tgt, = caps["targets"]
        assert tgt["target_alias"] == ALIAS and tgt["capabilities"][ID] == "SUPPORTED"
        assert all(v == "UNSUPPORTED" for k, v in tgt["capabilities"].items() if k != ID)
        col = replies[4]["result"]["structuredContent"]
        assert col["provenance"]["kind"] == "REAL" and not leaks(out.getvalue().decode())


@test
def check_command_report_is_sanitized_and_explains_failures_by_category_only():
    from mcp_gateway_lab.cli import run_check
    with tmpdir() as d:
        lab = Lab(d)
        report, rc = run_check(lab.gateway, lab.adapter)
        assert rc == 0 and report["result"] == "PASS" and report["failure_category"] is None and not leaks(json.dumps(report))
        from tests.p15.harness import driver_error
        lab.driver.s.connect_error = driver_error("ORA-01017")
        report, rc = run_check(lab.gateway, lab.adapter)
        assert rc == 1 and report["failure_category"] == "CREDENTIALS_REJECTED" and report["envelope"]["error"]["code"] == "E_ADAPTER_FAILED"
        assert not leaks(json.dumps(report))


@test
def validate_config_subcommand_is_offline_and_prints_no_connection_material():
    with tmpdir() as d:
        prof = write_private(d, "lab-profile.json", profile_doc())
        tf = write_targets(d, [lab_target()])
        rc, out, err = run_lab_cli("validate-config", "--targets", tf, "--lab-profile", prof)
        assert rc == 0 and err == "", err
        doc = json.loads(out)
        assert doc["connection_attempted"] is False and doc["adapter_status"] == "LAB_ENABLED" and doc["target_alias"] == ALIAS
        assert not leaks(out) and "oracle-estack-lab" not in out and "1521" not in out


@test
def serve_subcommand_speaks_mcp_over_stdio_without_connecting_at_startup():
    import subprocess, sys, os
    from tests.p15.harness import FAKEDRIVER_DIR, ROOT
    with tmpdir() as d:
        prof = write_private(d, "lab-profile.json", profile_doc())
        tf = write_targets(d, [lab_target()])
        msgs = [{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "t", "version": "0"}}},
                {"jsonrpc": "2.0", "method": "notifications/initialized"},
                {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "diagnostics.list_capabilities", "arguments": {}}}]
        # no collect here: in a subprocess it would reach the real /usr/bin/security; tests never touch the Keychain
        env = {"PATH": "/usr/bin:/bin", "PYTHONPATH": os.pathsep.join([FAKEDRIVER_DIR, ROOT]), "PYTHONDONTWRITEBYTECODE": "1"}
        p = subprocess.run([sys.executable, "-m", "mcp_gateway_lab", "serve", "--targets", tf, "--lab-profile", prof, "--audit", "off"],
                           input=b"".join(json.dumps(m).encode() + b"\n" for m in msgs), capture_output=True, cwd=ROOT, env=env, timeout=60)
        assert p.returncode == 0 and p.stderr == b"", p.stderr[-300:]
        r = {m["id"]: m for m in (json.loads(l) for l in p.stdout.decode().splitlines() if l.strip())}
        assert r[2]["result"]["structuredContent"]["adapters"]["oracle_sql"] == "LAB_ENABLED" and "LAB launcher" in r[1]["result"]["instructions"]
        assert not leaks(p.stdout.decode())



# --- CHG-ESTACK-ORA19C-LAB-002: instance-level collectors ------------------------------------------------

RL = "Q-ORA-RESOURCE-LIMITS-001"
ALL = ["Q-DISC-IDENTITY-001", RL]


@test
def resource_limits_returns_typed_real_evidence_after_the_identity_guard():
    from mcp_gateway import catalog
    with tmpdir() as d:
        lab = Lab(d, targets=[lab_target(allowed_collectors=ALL)])
        env, is_error = lab.collect(RL)
        assert not is_error and env["status"] == "OK" and env["provenance"] == {"kind": "REAL", "real_observation": True}, env
        rows = {r["resource_name"]: r for r in env["evidence"]["rows"]}
        assert rows["processes"] == {"resource_name": "processes", "current_utilization": 71, "max_utilization": 96, "limit_value": 320}, rows
        assert rows["dml_locks"]["limit_value"] == "UNLIMITED" and rows["sessions"]["limit_value"] == 504
        st = lab.driver.statements
        assert len(st) == 5 and "v$instance" in st[3].lower(), "identity must be proven before the requested query runs"
        block, = catalog.sql_blocks(open(catalog._find_query_file(RL), encoding="utf-8").read())
        assert st[4] == block.rstrip().rstrip(";").rstrip(), "the implicit variant runs the single certified block verbatim"
        assert "commit" not in lab.driver.events and lab.driver.events[-2:] == ["rollback", "close"]
        assert not leaks(json.dumps(env))


@test
def resource_limits_fetch_is_bounded_by_the_tightest_limit():
    with tmpdir() as d:
        lab = Lab(d, targets=[lab_target(allowed_collectors=ALL)])
        env, is_error = lab.collect(RL)
        assert not is_error, env
        assert lab.driver.fetch_sizes[-1] == 6, lab.driver.fetch_sizes          # min(profile 5, query 50, collector 50) + 1


@test
def describe_collector_reports_the_live_adapter_status_per_collector():
    with tmpdir() as d:
        lab = Lab(d, targets=[lab_target(allowed_collectors=ALL)])
        for cid in ALL:
            env, is_error = lab.call("diagnostics.describe_collector", {"collector_id": cid})
            assert not is_error and env["collector"]["adapter_status"]["oracle_sql"] == "LAB_ENABLED", (cid, env["collector"]["adapter_status"])
            assert env["capability_by_target"][ALIAS] == "SUPPORTED"
        for cid in ("Q-DG-STATS-001", "Q-ORA-PROCESSES-SUMMARY-001"):
            env, _ = lab.call("diagnostics.describe_collector", {"collector_id": cid})
            assert env["collector"]["adapter_status"]["oracle_sql"] == "UNSUPPORTED", (cid, env["collector"]["adapter_status"])
        env, _ = lab.call("diagnostics.describe_collector", {"collector_id": "Q-ORA-DIAGNOSTICS-ALERTLOG-001"})
        assert env["collector"]["adapter_status"] == {"fixture": "VERIFIED_FIXTURE", "oracle_diag_file": "CONTRACT_ONLY"}
    from mcp_gateway.cli import build_gateway
    from mcp_gateway.gateway import Session
    g = build_gateway()
    env, _ = g.call(Session(), "diagnostics.describe_collector", {"collector_id": RL})
    assert env["collector"]["adapter_status"] == {"fixture": "VERIFIED_FIXTURE", "oracle_sql": "DISABLED"}, "default runtime unchanged"



@test
def cdb_root_target_with_a_common_user_returns_instance_level_resource_limits():
    """Option C of CHG-ESTACK-ORA19C-LAB-002: a PDB session sees no V$RESOURCE_LIMIT rows, so the lab target is CDB$ROOT."""
    with tmpdir() as d:
        prof = profile_doc(**{"connection.username": "C##ESTACK_DIAG", "connection.service_name": "LABCDB",
                              "expected.container": "CDB_ROOT", "expected.db_name": "LABCDB"})
        sc = Scenario(session_service_name="LABCDB", session_con_name="CDB$ROOT", session_sess_user="C##ESTACK_DIAG",
                      id_db_name="LABCDB", id_cdb="YES", id_instance_name="LABCDB")
        lab = Lab(d, scenario=sc, profile=prof, targets=[lab_target(container="CDB_ROOT", allowed_collectors=ALL)])
        env, is_error = lab.collect(RL)
        assert not is_error and env["provenance"]["kind"] == "REAL" and env["evidence"]["row_count"] == 4, env
        env, is_error = lab.collect()
        row, = env["evidence"]["rows"]
        assert row["cdb"] == "YES" and not leaks(json.dumps(env)) and "C##ESTACK_DIAG" not in json.dumps(env)



# --- CHG-ESTACK-ORA19C-LAB-003: tablespaces / TEMP from CDB$ROOT, FRA usage ------------------------------

TBS, FRA = "Q-CDB-TABLESPACES-001", "Q-RMAN-FRA-USAGE-001"
BATCH1 = ["Q-DISC-IDENTITY-001", RL, TBS, FRA]


def root_lab(d, scenario=None, **limits):
    prof = profile_doc(**{"connection.username": "C##ESTACK_DIAG", "connection.service_name": "LABCDB", "expected.container": "CDB_ROOT",
                          "expected.db_name": "LABCDB", **{"limits." + k: v for k, v in limits.items()}})
    sc = scenario or Scenario()
    sc.session.update(service_name="LABCDB", con_name="CDB$ROOT", sess_user="C##ESTACK_DIAG")
    sc.identity = [dict(r, db_name="LABCDB", cdb="YES", instance_name="LABCDB") for r in sc.identity]
    return Lab(d, scenario=sc, profile=prof, targets=[lab_target(container="CDB_ROOT", allowed_collectors=BATCH1, budget={"max_calls": 20, "max_rows": 300})])


@test
def cdb_tablespaces_are_masked_per_pdb_and_never_expose_autoextend_or_raw_names():
    with tmpdir() as d:
        lab = root_lab(d, max_rows=50, max_output_bytes=16384)
        env, is_error = lab.collect(TBS)
        assert not is_error and env["status"] == "OK" and env["provenance"]["kind"] == "REAL", env
        rows = env["evidence"]["rows"]
        assert len(rows) == 3 and all(r["con_id"] == 3 for r in rows)
        assert all(r["tablespace_name"].startswith("ts-A") for r in rows), rows
        assert {r["contents"] for r in rows} == {"PERMANENT", "UNDO"} and max(r["used_percent"] for r in rows) == 91.4
        assert all("autoextend" not in r for r in rows) and "autoextend" not in env["evidence"]["columns"]
        assert not leaks(json.dumps(env)), leaks(json.dumps(env))


@test
def fra_returns_typed_evidence_without_the_destination_path():
    with tmpdir() as d:
        lab = root_lab(d, max_rows=50, max_output_bytes=16384)
        env, is_error = lab.collect(FRA)
        assert not is_error and env["status"] == "OK", env
        rows = {r["file_type"]: r for r in env["evidence"]["rows"]}
        assert rows["ARCHIVED LOG"]["percent_space_used"] == 42.5 and rows["ARCHIVED LOG"]["space_limit"] == 21474836480
        assert all("dest_name" not in r for r in rows.values()) and not leaks(json.dumps(env))


@test
def effective_row_cap_is_the_tightest_of_profile_query_and_collector():
    with tmpdir() as d:
        lab = root_lab(d)                                                     # harness profile: max_rows 5
        sc = lab.driver.s
        sc.tablespaces = [dict(sc.tablespaces[0], tablespace_name=f"TS{i}") for i in range(12)]
        env, is_error = lab.collect(TBS)
        assert not is_error and env["evidence"]["row_count"] == 5 and "ROWS_TRUNCATED_TO_LIMIT" in env["limitations"], env
        assert lab.driver.fetch_sizes[-1] == 6
    with tmpdir() as d:
        lab = root_lab(d, max_rows=200, max_output_bytes=65536)
        target, cols = lab.gateway.targets[ALIAS], lab.gateway.collectors
        assert lab.adapter.row_cap(target, cols["Q-DISC-IDENTITY-001"]) == 5, "identity keeps its 5-row ceiling whatever the profile allows"
        assert lab.adapter.row_cap(target, cols[FRA]) == 20 and lab.adapter.row_cap(target, cols[TBS]) == 200
        sc = lab.driver.s
        sc.fra = [dict(sc.fra[0]) for _ in range(25)]
        env, is_error = lab.collect(FRA)
        assert not is_error and env["evidence"]["row_count"] == 20 and "ROWS_TRUNCATED_TO_LIMIT" in env["limitations"], env["limitations"]


if __name__ == "__main__":
    raise SystemExit(run_all())
