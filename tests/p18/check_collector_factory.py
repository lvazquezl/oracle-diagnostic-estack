"""CHG-ESTACK-COLLECTOR-FACTORY-B1 — collector factory, lot B1 (Oracle Core + tablespaces for /healthcheck).

No Oracle: generated specs, synthetic fixtures and the lab adapter's minimization on synthetic driver rows.
"""
import copy
import json
import os
import re

from tests.p13.harness import PRIMARY, ROOT, InProcClient, run_all, test, tmpdir

from mcp_gateway import catalog
from mcp_gateway.evidence import SessionScope, _sanitize_value, sanitize_rows
from mcp_gateway_lab import oracle_sql
from scripts.collector_factory import generate as gen

FACTORY = os.path.join(ROOT, "mcp_gateway", "catalog", "collectors.factory.json")
RAW_ONLY = ("value", "destination", "error", "reason", "suggested_action", "file_name", "comp_name", "last_archived",
            "startup_time", "last_start_date", "creation_time", "name", "type", "thread#", "group#")


def _factory_ids():
    return [c["collector_id"] for c in json.load(open(FACTORY, encoding="utf-8"))["collectors"]]


def _raises(fn, *a, **kw):
    try:
        fn(*a, **kw)
    except (gen.FactoryError, RuntimeError) as e:
        return str(e)
    raise AssertionError("expected a refusal")


# --- generation ----------------------------------------------------------------------------------------------

@test
def the_committed_catalog_and_fixtures_are_exactly_what_the_factory_generates():
    assert gen.check() == [], gen.check()


@test
def lot_b1_exposes_the_healthcheck_core_and_tablespace_collectors():
    ids = set(_factory_ids())
    must = {"Q-DISC-INSTANCE-001", "Q-ORA-INSTANCE-STATE-001", "Q-ORA-DB-STATE-001", "Q-ORA-PARAMETERS-001", "Q-ORA-SPFILE-001",
            "Q-ORA-REDO-001", "Q-ORA-ARCHIVE-001", "Q-ORA-CONTROLFILE-001", "Q-ORA-UNDO-001", "Q-ORA-TEMP-001",
            "Q-DBA-TBS-USAGE-001", "Q-DBA-TBS-DATAFILES-001", "Q-ORA-SESSIONS-SUMMARY-001", "Q-ORA-COMPONENTS-001",
            "Q-ORA-INVALID-OBJECTS-001", "Q-ORA-OBJECTS-INVENTORY-001", "Q-ORA-JOBS-SUMMARY-001", "Q-ORA-DIAGNOSTICS-ADR-001"}
    assert must <= ids, sorted(must - ids)


@test
def every_generated_collector_loads_with_the_default_deny_rules_and_never_exposes_raw_text_or_dates():
    cols = catalog.load_collectors()
    for cid in _factory_ids():
        c = cols[cid]
        assert c.query_sha256 and c.supported_oracle_versions, cid
        for name, f in c.output_fields.items():
            assert name not in RAW_ONLY, (cid, name)
            assert not (f["type"] == "identifier" and f["policy"] == "KEEP") and f["type"] != "text", (cid, name)
            assert f["type"] != "timestamp_utc", (cid, name, "ages are computed in the database")


@test
def a_collector_id_in_both_catalogs_is_refused():
    with tmpdir() as d:
        spec = json.load(open(catalog.DEFAULT_COLLECTORS_FILE, encoding="utf-8"))
        fac = json.load(open(FACTORY, encoding="utf-8"))
        fac["collectors"].append(copy.deepcopy(spec["collectors"][0]))
        p = os.path.join(d, "factory.json")
        json.dump(fac, open(p, "w", encoding="utf-8"))
        assert "invalid collector catalog" in _raises(catalog.load_collectors, catalog.DEFAULT_COLLECTORS_FILE, p)


@test
def an_override_may_only_narrow_the_knowledge_base():
    base = {"type": "enum", "policy": "KEEP", "values": ["A", "B"], "example": "A"}
    num = {"type": "integer", "policy": "KEEP", "min": 0, "max": 10, "example": 1}
    assert "type" in _raises(gen._narrow, "f", base, {"type": "identifier"}, "Q")
    assert "policy" in _raises(gen._narrow, "f", {"type": "identifier", "policy": "MASK", "example": "X"}, {"policy": "KEEP"}, "Q")
    assert "subset" in _raises(gen._narrow, "f", base, {"values": ["A", "C"]}, "Q")
    assert "widens" in _raises(gen._narrow, "f", num, {"max": 11}, "Q")
    assert "widens" in _raises(gen._narrow, "f", num, {"min": -1}, "Q")
    assert "without values" in _raises(gen._narrow, "f", {"type": "enum", "policy": "KEEP", "values": [], "example": None}, None, "Q")
    assert "outside" in _raises(gen._narrow, "f", base, {"example": "Z"}, "Q")
    assert gen._narrow("f", base, {"values": ["B"], "example": "B"}, "Q")["values"] == ["B"]


@test
def a_lot_cannot_expose_an_unknown_field_an_uncertified_query_or_more_rows_than_certified():
    lot_dir = gen.LOTS
    try:
        with tmpdir() as d:
            gen.LOTS = d
            lot = json.load(open(os.path.join(lot_dir, "B1-oracle-core.json"), encoding="utf-8"))
            one = lambda **kw: dict(lot, collectors=[dict(lot["collectors"][0], overrides={}, **kw)])
            for doc, why in ((one(fields=["inst_id", "secret_col"]), "knowledge base"),
                             (one(collector_id="Q-NOPE-001"), "certified"),
                             (one(row_limit=10 ** 6), "max_rows"),
                             (one(aliases={"x": "not_listed"}), "alias")):
                json.dump(doc, open(os.path.join(d, "lot.json"), "w", encoding="utf-8"))
                assert why in _raises(gen.generate), why
    finally:
        gen.LOTS = lot_dir


# --- parameter_name type -------------------------------------------------------------------------------------

@test
def parameter_name_is_keepable_only_in_a_field_named_parameter_name():
    with tmpdir() as d:
        for fields in ({"owner": {"type": "parameter_name", "policy": "KEEP"}},
                       {"parameter_name": {"type": "identifier", "policy": "MASK"}},
                       {"parameter_name": {"type": "parameter_name", "policy": "MASK"}}):
            spec = json.load(open(catalog.DEFAULT_COLLECTORS_FILE, encoding="utf-8"))
            spec["collectors"][0]["output_fields"] = fields
            p = os.path.join(d, "c.json")
            json.dump(spec, open(p, "w", encoding="utf-8"))
            assert "default-deny" in _raises(catalog.load_collectors, p), fields


@test
def parameter_names_keep_only_the_oracle_name_shape():
    s = SessionScope()
    f = {"type": "parameter_name", "policy": "KEEP"}
    for ok in ("processes", "remote_login_passwordfile", "_optimizer_adaptive_plans", "db_32k_cache_size"):
        assert _sanitize_value(f, ok, s, PRIMARY) == (True, ok), ok
    for bad in ("/u01/app/oracle", "ORCL", "a b", "x" * 90, "sys/oracle@db", 42, None, "name=value"):
        assert _sanitize_value(f, bad, s, PRIMARY)[0] is False, bad


# --- fixtures and lab minimization ---------------------------------------------------------------------------

@test
def every_generated_collector_runs_in_fixture_mode_without_dropped_values():
    c = InProcClient()
    c.initialize()
    targets = {s["collector_id"]: s["factory"].get("fixture_target", PRIMARY)
               for s in json.load(open(FACTORY, encoding="utf-8"))["collectors"]}
    for cid in _factory_ids():
        env, _ = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": targets[cid]})
        assert env["status"] == "OK", (cid, env.get("error"), env.get("capability_status"))
        assert not [x for x in env.get("limitations", []) if "DROP" in str(x)], (cid, env["limitations"])


@test
def the_lab_adapter_implements_the_lot_with_its_aliases_and_hand_entries_win():
    fac = oracle_sql._factory_collectors()
    assert set(fac) == set(_factory_ids())
    for cid, aliases in fac.items():
        assert oracle_sql.SUPPORTED_COLLECTORS[cid] == aliases or cid in ("Q-DISC-IDENTITY-001",), cid
    assert oracle_sql.SUPPORTED_COLLECTORS["Q-DISC-IDENTITY-001"] == {"version_full": "version"}


@test
def raw_driver_columns_never_leave_the_lab_adapter():
    cols = catalog.load_collectors()
    s = SessionScope()
    raw = {
        "Q-ORA-PARAMETERS-001": {"name": "audit_file_dest", "value": "/u01/app/oracle/admin/LAB/adump", "isdefault": "FALSE",
                                 "ismodified": "FALSE", "value_number": None, "value_flag": None, "value_version": None, "value_keyword": None},
        "Q-ORA-ARCHIVE-001": {"dest_id": 2, "destination": "service=stby.example.internal", "status": "ERROR",
                              "error": "ORA-12541: TNS:no listener at db19-lab.example.internal", "last_archived": "2026-09-29",
                              "hours_since_last_archived": 3.5, "dest_kind": "SERVICE", "has_error": "YES"},
        "Q-ORA-REDO-001": {"thread#": 1, "group#": 3, "bytes": 209715200, "status": "CURRENT", "member_count": 2},
        "Q-DBA-TBS-DATAFILES-001": {"tablespace_name": "APP_DATA", "file_name": "+DATA/LAB19C/DATAFILE/app_data.300.1",
                                    "bytes": 1024, "autoextensible": "YES", "maxbytes": 2048, "increment_by": 1},
        "Q-ORA-DIAGNOSTICS-ADR-001": {"reason": "Tablespace [APP_DATA] is [91 percent] full", "message_type": "Warning",
                                      "suggested_action": "Add space to APP_DATA", "creation_time": "x", "hours_since_created": 2.0},
    }
    for cid, row in raw.items():
        c = cols[cid]
        out = sanitize_rows(c, oracle_sql.OracleSqlAdapter._minimize([row], c), s, PRIMARY, 10)
        text = json.dumps(out)
        for leak in ("/u01", "stby.example", "db19-lab", "ORA-12541", "+DATA", "APP_DATA", "91 percent", "2026-09-29"):
            assert leak not in text, (cid, leak)
    red = sanitize_rows(cols["Q-ORA-REDO-001"], oracle_sql.OracleSqlAdapter._minimize([raw["Q-ORA-REDO-001"]], cols["Q-ORA-REDO-001"]), s, PRIMARY, 10)
    assert json.dumps(red).count('"thread_no": 1') == 1 and '"group_no": 3' in json.dumps(red), red
    par = sanitize_rows(cols["Q-ORA-PARAMETERS-001"], oracle_sql.OracleSqlAdapter._minimize([raw["Q-ORA-PARAMETERS-001"]], cols["Q-ORA-PARAMETERS-001"]), s, PRIMARY, 10)
    assert '"parameter_name": "audit_file_dest"' in json.dumps(par), par


@test
def the_modified_queries_compute_ages_and_value_shapes_in_the_database():
    from mcp_gateway_lab import sqlsource
    import hashlib

    class Q:
        def __init__(self, qid):
            p = catalog._find_query_file(qid)
            b = catalog.sql_blocks(open(p, encoding="utf-8").read())
            self.collector_id, self.kind, self.query_sha256 = qid, "sql_query", hashlib.sha256("\n".join(b).encode()).hexdigest()
    expect = {"Q-DISC-INSTANCE-001": "uptime_hours", "Q-ORA-INSTANCE-STATE-001": "uptime_hours",
              "Q-ORA-JOBS-SUMMARY-001": "hours_since_last_start", "Q-ORA-DIAGNOSTICS-ADR-001": "hours_since_created",
              "Q-ORA-ARCHIVE-001": "hours_since_last_archived", "Q-ORA-PARAMETERS-001": "value_keyword", "Q-ORA-SPFILE-001": "value_keyword"}
    for qid, col in expect.items():
        for v in ("11.2", "19.0", "23.0"):
            sql = sqlsource.resolve(Q(qid), v).sql
            assert re.search(r"\bAS " + col + r"\b", sql), (qid, v)


# --- lot B2 (performance) -----------------------------------------------------------------------------------

@test
def lot_b2_exposes_the_performance_collectors_without_diagnostics_pack_views():
    cols = catalog.load_collectors()
    b2 = [c["collector_id"] for c in json.load(open(FACTORY, encoding="utf-8"))["collectors"] if c["factory"]["lot"] == "B2"]
    must = {"Q-PERF-WAIT-SYSTEM-001", "Q-PERF-WAIT-CLASS-001", "Q-PERF-DBTIME-CURRENT-001", "Q-PERF-TOPSQL-CURRENT-001",
            "Q-PERF-BLOCKING-001", "Q-PERF-IO-FILESTAT-001", "Q-PERF-HARDPARSE-001", "Q-ORA-REDO-SWITCH-24H-001"}
    assert must <= set(b2), sorted(must - set(b2))
    for cid in b2:
        assert cols[cid].license_requirements in ("none", None, []), (cid, cols[cid].license_requirements)


@test
def oracle_term_and_sql_id_are_keepable_only_in_their_named_fields():
    with tmpdir() as d:
        for fields in ({"owner": {"type": "oracle_term", "policy": "KEEP"}},
                       {"event": {"type": "identifier", "policy": "MASK"}},
                       {"event": {"type": "oracle_term", "policy": "MASK"}},
                       {"host_name": {"type": "sql_id", "policy": "KEEP"}},
                       {"sql_id": {"type": "identifier", "policy": "MASK"}}):
            spec = json.load(open(catalog.DEFAULT_COLLECTORS_FILE, encoding="utf-8"))
            spec["collectors"][0]["output_fields"] = fields
            p = os.path.join(d, "c.json")
            json.dump(spec, open(p, "w", encoding="utf-8"))
            assert "default-deny" in _raises(catalog.load_collectors, p), fields


@test
def oracle_terms_and_sql_ids_keep_only_their_shape():
    s = SessionScope()
    term = {"type": "oracle_term", "policy": "KEEP"}
    for ok in ("db file sequential read", "enq: TX - row lock contention", "SQL*Net message from client", "TABLE/PROCEDURE"):
        assert _sanitize_value(term, ok, s, PRIMARY) == (True, ok), ok
    for bad in ("/u01/app/oracle", "sys/oracle@db", "x" * 80, "password=Tiger123", "Xk9fQ2pLm7Rt4Wz8Yb3Nc", 7, None):
        assert _sanitize_value(term, bad, s, PRIMARY) == (False, None), bad
    sid = {"type": "sql_id", "policy": "KEEP"}
    assert _sanitize_value(sid, "7ztv2z24kw0s0", s, PRIMARY) == (True, "7ztv2z24kw0s0")
    for bad in ("SELECT * FROM t", "7ZTV2Z24KW0S0", "7ztv2z24kw0s", "7ztv2z24kw0s0x", 42):
        assert _sanitize_value(sid, bad, s, PRIMARY)[0] is False, bad


@test
def long_readable_oracle_identifiers_are_masked_not_dropped_but_token_shapes_still_are():
    s = SessionScope()
    f = {"type": "identifier", "policy": "MASK", "alias_prefix": "own"}
    for ok in ("REMOTE_SCHEDULER_AGENT", "GSMADMIN_INTERNAL", "gsmcatuser_internal_x"):
        kept, v = _sanitize_value(f, ok, s, PRIMARY)
        assert kept and v.startswith("own-") and ok not in v, (ok, v)
    for bad in ("Xk9fQ2pLm7Rt4Wz8Yb3Nc", "ABCDEFGHIJ0123456789ABCD", "f" * 40):
        assert _sanitize_value(f, bad, s, PRIMARY) == (False, None), bad


@test
def b2_collectors_never_expose_sql_text_file_paths_or_memory_addresses():
    cols = catalog.load_collectors()
    s = SessionScope()
    raw = {
        "Q-PERF-TOPSQL-CURRENT-001": {"sql_id": "7ztv2z24kw0s0", "sql_text": "SELECT card_no FROM payments", "plan_hash_value": 1,
                                      "executions": 2, "elapsed_sec": 1.5, "cpu_sec": 1.0, "buffer_gets": 3, "disk_reads": 0, "rows_processed": 1},
        "Q-PERF-IO-FILESTAT-001": {"file_id": 7, "file_name": "/u02/oradata/LAB/app_data01.dbf", "tablespace_name": "APP_DATA",
                                   "phyrds": 10, "phywrts": 2, "avg_read_latency_ms": 4.1, "avg_write_latency_ms": 1.0},
        "Q-PERF-TEMP-001": {"session_addr": "00000000DEADBEEF", "sid": 12, "serial_no": 34, "sql_id": "7ztv2z24kw0s0",
                            "tablespace": "TEMP_APP", "contents": "TEMPORARY", "bytes_used": 1048576},
    }
    for cid, row in raw.items():
        out = json.dumps(sanitize_rows(cols[cid], oracle_sql.OracleSqlAdapter._minimize([row], cols[cid]), s, PRIMARY, 10))
        for leak in ("card_no", "payments", "/u02", "app_data01", "APP_DATA", "DEADBEEF", "TEMP_APP"):
            assert leak not in out, (cid, leak)
        assert "7ztv2z24kw0s0" in out or cid == "Q-PERF-IO-FILESTAT-001", out


@test
def the_b2_query_fixes_are_in_the_certified_sql():
    from mcp_gateway_lab import sqlsource
    import hashlib

    def sql(qid, v="19.0"):
        class Q:
            pass
        q = Q()
        p = catalog._find_query_file(qid)
        b = catalog.sql_blocks(open(p, encoding="utf-8").read())
        q.collector_id, q.kind, q.query_sha256 = qid, "sql_query", hashlib.sha256("\n".join(b).encode()).hexdigest()
        return sqlsource.resolve(q, v).sql
    assert "readtim * 10" in sql("Q-PERF-IO-FILESTAT-001") and "file_name" not in sql("Q-PERF-IO-FILESTAT-001")
    assert "session_addr," not in sql("Q-PERF-TEMP-001") and "session_addr," not in sql("Q-PERF-TEMP-001", "11.2")
    assert "server_name" not in sql("Q-PERF-PARALLEL-001") and "sql_id" not in sql("Q-PERF-PARALLEL-001")
    assert ":window" not in sql("Q-ORA-REDO-SWITCH-24H-001")
    assert "FROM   dual\nLEFT   JOIN v$parameter" in sql("Q-ORA-SPFILE-001")
    for v in ("10.2", "11.2", "19.0", "23.0"):
        assert sql("Q-PERF-HARDPARSE-001", v) and sql("Q-PERF-WAIT-SYSTEM-001", v) and sql("Q-PERF-WAIT-CLASS-001", v)


# --- lot B3 (security, CHG-ESTACK-SEC-QUERIES-001) ----------------------------------------------------------

@test
def lot_b3_exposes_the_corrected_security_queries_without_licensed_options():
    cols = catalog.load_collectors()
    b3 = [c["collector_id"] for c in json.load(open(FACTORY, encoding="utf-8"))["collectors"] if c["factory"]["lot"] == "B3"]
    assert set(b3) == {"Q-SEC-ROLE-SYSTEM-PRIVILEGES-001", "Q-SEC-NESTED-ROLE-GRANTS-001", "Q-SEC-UNIFIED-AUDIT-TRAIL-001",
                       "Q-SEC-TRADITIONAL-AUDIT-001", "Q-SEC-DIRECTORIES-001", "Q-SEC-DEFAULT-ACCOUNTS-001"}, b3
    for cid in b3:
        f = cols[cid].output_fields
        assert all(not (v["type"] == "identifier" and v["policy"] == "KEEP") for v in f.values()), cid
        assert "directory_path" not in f and "sql_text" not in f and "dbusername" not in f, cid


@test
def role_privilege_queries_read_the_whole_database_not_the_session():
    from mcp_gateway_lab import sqlsource
    import hashlib

    def sql(qid, v):
        class Q:
            pass
        q = Q()
        b = catalog.sql_blocks(open(catalog._find_query_file(qid), encoding="utf-8").read())
        q.collector_id, q.kind, q.query_sha256 = qid, "sql_query", hashlib.sha256("\n".join(b).encode()).hexdigest()
        return sqlsource.resolve(q, v).sql.lower()
    a, b = sql("Q-SEC-ROLE-SYSTEM-PRIVILEGES-001", "11.2"), sql("Q-SEC-NESTED-ROLE-GRANTS-001", "11.2")
    assert "dba_sys_privs" in a and "role_sys_privs" not in a, a
    assert "dba_role_privs" in b and "role_role_privs" not in b, b
    # CHG-ESTACK-PDB-COVERAGE-001: 12.1+ reads CDB_* (every open container) and only the custom roles
    a, b = sql("Q-SEC-ROLE-SYSTEM-PRIVILEGES-001", "19.0"), sql("Q-SEC-NESTED-ROLE-GRANTS-001", "19.0")
    assert "cdb_sys_privs" in a and "role_sys_privs" not in a and "oracle_maintained = 'n'" in a, a
    assert "cdb_role_privs" in b and "role_role_privs" not in b and "oracle_maintained = 'n'" in b, b
    for qid in ("Q-SEC-UNIFIED-AUDIT-TRAIL-001", "Q-SEC-TRADITIONAL-AUDIT-001", "Q-SEC-DATA-REDACTION-POLICIES-001",
                "Q-SEC-DATABASE-VAULT-STATUS-001", "Q-SEC-DIRECTORIES-001"):
        assert sql(qid, "19.0"), qid                              # every one of them resolves now


@test
def privilege_and_action_names_are_keepable_only_in_their_fields():
    with tmpdir() as d:
        for fields in ({"grantee": {"type": "oracle_term", "policy": "KEEP"}},
                       {"privilege": {"type": "identifier", "policy": "MASK"}},
                       {"action_name": {"type": "enum", "values": ["LOGON"], "policy": "KEEP"}}):
            spec = json.load(open(catalog.DEFAULT_COLLECTORS_FILE, encoding="utf-8"))
            spec["collectors"][0]["output_fields"] = fields
            p = os.path.join(d, "c.json")
            json.dump(spec, open(p, "w", encoding="utf-8"))
            assert "default-deny" in _raises(catalog.load_collectors, p), fields


# --- lot B4 (AWR/ASH, CHG-ESTACK-AWR-LICENSED-001) ----------------------------------------------------------

B4 = ("Q-PERF-AWR-DBTIME-24H-001", "Q-PERF-AWR-TOPSQL-24H-001", "Q-PERF-AWR-WAITS-24H-001", "Q-PERF-ASH-1H-001")


@test
def diagnostics_pack_collectors_run_only_where_the_license_is_confirmed():
    c = InProcClient()
    c.initialize()
    for cid in B4:
        env, _ = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": PRIMARY})
        assert env["status"] == "ERROR" and env["capability_status"] == "LICENSE_RESTRICTED", (cid, env)
        env, _ = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": "fixture-licensed-19c"})
        assert env["status"] == "OK", (cid, env.get("error"))


@test
def license_keys_follow_the_option_and_tuning_implies_diagnostics():
    from mcp_gateway.catalog import license_keys
    assert license_keys("[Diagnostics Pack]") == {"diagnostics_pack"}
    assert license_keys("Oracle Tuning Pack") == {"tuning_pack", "diagnostics_pack"}
    assert license_keys("Active Data Guard") == {"active_data_guard"}
    assert license_keys("Advanced Security Option") == {"other_option"}

    class T:
        oracle_version, container, role, missing_privileges, enabled = "19c", "NON_CDB", "PRIMARY", set(), True
        allowed_collectors = {"Q-PERF-AWR-WAITS-24H-001"}
    cols = catalog.load_collectors()
    col = cols["Q-PERF-AWR-WAITS-24H-001"]
    assert isinstance(col.license_requirements, (list, str))
    for status, expected in (({}, "LICENSE_RESTRICTED"), ({"diagnostics_pack": "UNKNOWN"}, "LICENSE_RESTRICTED"),
                             ({"tuning_pack": "CONFIRMED"}, "LICENSE_RESTRICTED"), ({"diagnostics_pack": "CONFIRMED"}, "SUPPORTED")):
        t = T()
        t.license_status = status
        got = catalog.evaluate_capability(t, col, "VERIFIED_FIXTURE")
        assert got == expected, (status, got)
    tuning = copy.copy(col)
    tuning.license_requirements = ["Tuning Pack"]                 # needs BOTH tuning_pack and diagnostics_pack
    for status, expected in (({"tuning_pack": "CONFIRMED"}, "LICENSE_RESTRICTED"),
                             ({"diagnostics_pack": "CONFIRMED"}, "LICENSE_RESTRICTED"),
                             ({"tuning_pack": "CONFIRMED", "diagnostics_pack": "CONFIRMED"}, "SUPPORTED")):
        t = T()
        t.license_status = status
        got = catalog.evaluate_capability(t, tuning, "VERIFIED_FIXTURE")
        assert got == expected, (status, got)


@test
def awr_queries_use_deltas_not_cumulative_sums():
    text = open(catalog._find_query_file("Q-PERF-AWR-WAITS-24H-001"), encoding="utf-8").read()
    sql = "\n".join(catalog.sql_blocks(text)).lower()
    assert "max(e.time_waited_micro) - min(e.time_waited_micro)" in sql and "startup_time" in sql
    text = open(catalog._find_query_file("Q-PERF-AWR-DBTIME-24H-001"), encoding="utf-8").read()
    sql = "\n".join(catalog.sql_blocks(text)).lower()
    assert "lag(db_time)" in sql and "partition by dbid, instance_number, startup_time" in sql
    # 12.1+: keep only CDB-level rows (con_dbid = dbid); in a non-CDB it changes nothing (docs/AWR_LICENSED.md)
    from mcp_gateway_lab import sqlsource
    import hashlib
    for qid, col in (("Q-PERF-AWR-DBTIME-24H-001", "t.con_dbid = t.dbid"), ("Q-PERF-AWR-WAITS-24H-001", "e.con_dbid = e.dbid")):
        class Q:
            pass
        q = Q()
        b = catalog.sql_blocks(open(catalog._find_query_file(qid), encoding="utf-8").read())
        q.collector_id, q.kind, q.query_sha256 = qid, "sql_query", hashlib.sha256("\n".join(b).encode()).hexdigest()
        assert col in sqlsource.resolve(q, "19.0").sql and col not in sqlsource.resolve(q, "11.2").sql, qid


def _resolved(qid, version):
    from mcp_gateway_lab import sqlsource
    import hashlib

    class Q:
        pass
    q = Q()
    b = catalog.sql_blocks(open(catalog._find_query_file(qid), encoding="utf-8").read())
    q.collector_id, q.kind, q.query_sha256 = qid, "sql_query", hashlib.sha256("\n".join(b).encode()).hexdigest()
    return sqlsource.resolve(q, version).sql.lower()


@test
def pdb_coverage_variants_read_every_container_from_12_1():
    # CHG-ESTACK-PDB-COVERAGE-001 (FND-0021 of ANA-20261007-001): from CDB$ROOT, DBA_* sees the root only
    cases = {"Q-ORA-INVALID-OBJECTS-001": ("dba_objects", "cdb_objects"),
             "Q-ORA-OBJECTS-INVENTORY-001": ("dba_objects", "cdb_objects"),
             "Q-ORA-JOBS-SUMMARY-001": ("dba_scheduler_jobs", "cdb_scheduler_jobs"),
             "Q-ORA-COMPONENTS-001": ("dba_registry", "cdb_registry"),
             "Q-SEC-DIRECTORIES-001": ("dba_directories", "cdb_directories"),
             "Q-SEC-TRADITIONAL-AUDIT-001": ("dba_audit_session", "cdb_audit_session"),
             "Q-SEC-PASSWORD-PROFILES-001": ("dba_profiles", "cdb_profiles")}
    for qid, (legacy, cdb) in cases.items():
        old, new = _resolved(qid, "11.2"), _resolved(qid, "19.0")
        assert legacy in old and cdb not in old and "con_id" not in old, qid
        select_list = new.split(" from ")[0] if " from " in new else new.split("\nfrom")[0]
        assert cdb in new and "con_id" in select_list.split("from")[0], qid      # con_id must be an output column
    assert "cdb_unified_audit_trail" in _resolved("Q-SEC-UNIFIED-AUDIT-TRAIL-001", "19.0")
    assert "cdb_unified_audit_trail" not in _resolved("Q-SEC-UNIFIED-AUDIT-TRAIL-001", "18.0")   # not documented before 19c
    spec = catalog.load_collectors()
    for qid in list(cases) + ["Q-SEC-ROLE-SYSTEM-PRIVILEGES-001", "Q-SEC-NESTED-ROLE-GRANTS-001", "Q-SEC-UNIFIED-AUDIT-TRAIL-001"]:
        assert "con_id" in spec[qid].output_fields, qid


@test
def pdb_coverage_lot_never_exposes_free_text_or_raw_values():
    spec = catalog.load_collectors()
    forbidden = {"message", "action", "line", "error_number", "value", "limit", "directory_path", "open_time", "time",
                 "entity_name", "user_name", "name"}
    for qid in ("Q-CDB-PDB-STATE-001", "Q-CDB-SERVICES-001", "Q-CDB-PLUGIN-VIOLATIONS-001", "Q-SEC-UNIFIED-AUDIT-POLICIES-001",
                "Q-SEC-PASSWORD-PROFILES-001", "Q-SEC-ADMIN-PRIVILEGES-001", "Q-RMAN-CONFIGURATION-001", "Q-SEC-DIRECTORIES-001"):
        fields = set(spec[qid].output_fields)
        assert not fields & forbidden, (qid, fields & forbidden)
    pv = _resolved("Q-CDB-PLUGIN-VIOLATIONS-001", "19.0")
    assert all(w not in pv for w in ("message", "action", " line")), pv
    rm = _resolved("Q-RMAN-CONFIGURATION-001", "19.0")
    assert "as setting" in rm and "regexp_substr(value" in rm and ", value" not in rm, rm
    pp = _resolved("Q-SEC-PASSWORD-PROFILES-001", "19.0")
    assert "custom_function" in pp and "as limit_keyword" in pp, pp
    import re
    assert not re.search(r"(select|,)\s*limit\s*(,|from)", pp), "the raw profile limit must never be an output column"
    assert "directory_path" not in _resolved("Q-SEC-DIRECTORIES-001", "19.0")
    for f in ("pdb_name", "service_name", "profile", "username"):
        owner = next(c for c in spec.values() if f in c.output_fields and c.collector_id in
                     ("Q-CDB-PDB-STATE-001", "Q-CDB-SERVICES-001", "Q-SEC-PASSWORD-PROFILES-001", "Q-SEC-ADMIN-PRIVILEGES-001"))
        assert owner.output_fields[f]["policy"] == "MASK", f


@test
def custom_audit_policy_names_never_leave_the_database():
    for v in ("12.1", "19.0"):
        sql = _resolved("Q-SEC-UNIFIED-AUDIT-POLICIES-001", v)
        assert "else 'custom' end as policy_name" in sql.replace("\n", " "), v
        assert "entity_name" not in sql.split("from")[0].replace("case when entity_name = 'all users'", ""), v
    assert "policy_name" in catalog.ORACLE_TERM_FIELDS and "cause" in catalog.ORACLE_TERM_FIELDS


@test
def clock_check_compares_the_database_clock_with_the_gateway():
    # CHG-ESTACK-ASSESSMENT-ACCURACY-001: a skewed host clock shifts every "hours since ..." computed in the database
    from mcp_gateway import gateway
    ok = gateway.clock_check([{"db_utc_epoch": 1791417600}], "2026-10-08T00:00:30+00:00")
    assert ok["compared"] and ok["offset_seconds"] == -30 and not ok["skew"], ok
    bad = gateway.clock_check([{"db_utc_epoch": 1791417600 - 7920}], "2026-10-08T00:00:00+00:00")
    assert bad["skew"] and bad["offset_seconds"] == -7920, bad
    assert gateway.clock_check([{"db_utc_epoch": 1791417600}], None)["compared"] is False      # fixture: never compared
    assert gateway.clock_check([], "2026-10-08T00:00:00+00:00")["compared"] is False
    assert "sys_extract_utc(systimestamp)" in _resolved("Q-DISC-CLOCK-001", "19.0")


@test
def accuracy_queries_fix_redo_scope_and_placement():
    rs = _resolved("Q-ORA-REDO-SWITCH-24H-001", "19.0")
    assert "next_time" in rs and "first_time" not in rs, rs
    un = _resolved("Q-ORA-UNDO-001", "19.0")
    assert "group  by u.con_id" in un and "con_id" in un.split("from")[0], un
    assert "con_id" not in _resolved("Q-ORA-UNDO-001", "11.2")
    assert "con_id" in _resolved("Q-SEC-ADMIN-PRIVILEGES-001", "19.0").split("from")[0]
    px = _resolved("Q-SEC-PROXY-AUTHENTICATION-001", "19.0")
    assert "proxy_oracle_maintained" in px and "client_oracle_maintained" in px
    assert "oracle_maintained" not in _resolved("Q-SEC-PROXY-AUTHENTICATION-001", "12.1.0.1")   # column exists from 12.1.0.2
    assert "grantee_oracle_maintained" in _resolved("Q-SEC-DIRECTORIES-001", "19.0")
    asm = _resolved("Q-ASM-TOPOLOGY-001", "19.0")
    for f in ("holds_datafiles", "holds_redo", "holds_controlfile", "holds_fra", "c.group_number"):
        assert f in asm, f
    spec = catalog.load_collectors()
    exposed = set(spec["Q-ASM-TOPOLOGY-001"].output_fields)
    assert not exposed & {"name", "member", "value"}, exposed                 # paths and the FRA destination never leave
    assert all(spec["Q-ASM-TOPOLOGY-001"].output_fields[f]["values"] == ["NO", "YES"]
               for f in ("holds_datafiles", "holds_redo", "holds_controlfile", "holds_fra"))
    cd = _resolved("Q-CDB-CONTAINER-DATA-001", "19.0")
    assert "sys_context('userenv', 'session_user')" in cd, cd                 # only the diagnostic account itself
    assert spec["Q-CDB-CONTAINER-DATA-001"].output_fields["pdb_name"]["policy"] == "MASK"


@test
def a_variant_max_is_inclusive_at_its_own_precision():
    # CHG-ESTACK-ASSESSMENT-ACCURACY-001: a 4-component max ("12.1.0.1") padded with ".99.99.99" exceeded the version
    # parser and the variant never matched, so 11g/12.1.0.1 targets failed closed for split queries.
    for v in ("11.2.0.4.0", "12.1.0.1.0"):
        assert "oracle_maintained" not in _resolved("Q-SEC-DEFAULT-ACCOUNTS-001", v), v
        assert "oracle_maintained" not in _resolved("Q-SEC-PROXY-AUTHENTICATION-001", v), v
    for v in ("12.1.0.2.0", "19.0.0.0.0"):
        assert "oracle_maintained" in _resolved("Q-SEC-DEFAULT-ACCOUNTS-001", v), v
    assert "rownum" in _resolved("Q-SEC-TRADITIONAL-AUDIT-001", "11.2.0.4.0")          # max "11.2" still covers 11.2.0.4
    try:
        _resolved("Q-SEC-PROXY-AUTHENTICATION-001", "24.0.0.0.0")                     # above every max: fail closed
        raise AssertionError("a version above every variant must not resolve")
    except Exception as e:
        assert "could not be resolved" in str(e), e


if __name__ == "__main__":
    raise SystemExit(run_all())
