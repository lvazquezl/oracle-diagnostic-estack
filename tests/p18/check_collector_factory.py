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
    for cid in _factory_ids():
        env, _ = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": PRIMARY})
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
    for v in ("11.2", "19.0"):
        a, b = sql("Q-SEC-ROLE-SYSTEM-PRIVILEGES-001", v), sql("Q-SEC-NESTED-ROLE-GRANTS-001", v)
        assert "dba_sys_privs" in a and "role_sys_privs" not in a, a
        assert "dba_role_privs" in b and "role_role_privs" not in b, b
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


if __name__ == "__main__":
    raise SystemExit(run_all())
