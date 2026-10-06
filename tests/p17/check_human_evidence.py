"""CHG-ESTACK-HUMAN-EVIDENCE-001 — human-reported evidence: request (certified SQL only) and ingest (local sanitization).

No Oracle: the CSVs are synthetic. Every case runs against a temporary evidence directory.
"""
import json
import os
import re
import stat

from tests.p13.harness import ROOT, run_all, test, tmpdir

from human_evidence import cli
from human_evidence.classify import classify_column, value_is_sensitive
from mcp_gateway import catalog
from mcp_gateway_lab import sqlsource

SECRET = "Xk9fQ2pLm7Rt4Wz8Yb3Nc"          # token-shaped, must never survive
HOST = "dbhost01.corp.example.com"
IP = "10.20.30.40"
PATH = "/u01/app/oracle/admin/ORCL/adump"


class _Env:
    """Point the CLI at a temporary evidence directory for one case."""
    def __init__(self, d):
        self.d, self.saved = d, {}

    def __enter__(self):
        for k, sub in (("EVIDENCE", ""), ("REQUESTS", "requests"), ("RAW", "raw"), ("SANITIZED", "sanitized")):
            self.saved[k] = getattr(cli, k)
            setattr(cli, k, os.path.join(self.d, sub) if sub else self.d)
        return self

    def __exit__(self, *a):
        for k, v in self.saved.items():
            setattr(cli, k, v)


def _csv(path, header, rows):
    q = lambda v: '"' + v.replace('"', '""') + '"'
    with open(path, "w", encoding="utf-8") as f:
        f.write(",".join(q(h) for h in header) + "\n")
        for r in rows:
            f.write(",".join(q(v) for v in r) + "\n")


def _refused(fn, *a):
    try:
        fn(*a)
    except (cli.HumanEvidenceError, ValueError) as e:
        return str(e)
    raise AssertionError("expected a refusal")


def _params(d, scope="SES-test-001", rows=None):
    """A query WITHOUT a gateway spec (heuristic path; the CSV columns are synthetic on purpose)."""
    req = cli.make_request("Q-ORA-PARAMETERS-RAC-DIFF-001", "lab-ol8-19c", "19c", scope)
    p = os.path.join(d, "in.csv")
    _csv(p, ["NAME", "VALUE", "ISDEFAULT", "ISMODIFIED"], rows or [
        ["processes", "320", "FALSE", "FALSE"],
        ["remote_login_passwordfile", "EXCLUSIVE", "FALSE", "FALSE"],
        ["audit_file_dest", PATH, "FALSE", "FALSE"],
        ["local_listener", IP, "FALSE", "FALSE"],
        ["service_names", HOST, "FALSE", "FALSE"],
        ["db_create_file_dest", "+DATA", "FALSE", "FALSE"],
        ["_hidden_param_x", SECRET, "FALSE", "FALSE"],
        ["log_archive_dest_1", "password=Tiger123", "FALSE", "FALSE"],
        ["dispatchers", "sys/oracle@orcl", "FALSE", "FALSE"],
        ["mail_contact", "dba@example.com", "FALSE", "FALSE"],
    ])
    return req, p


# --- request -------------------------------------------------------------------------------------------------

@test
def a_request_carries_the_verbatim_certified_sql_and_its_sha():
    with tmpdir() as d, _Env(d):
        req = cli.make_request("Q-ORA-PARAMETERS-RAC-DIFF-001", "lab-ol8-19c", "19c", "SES-test-001")
        assert re.match(r"^ER-\d{8}-\d{6}-[0-9a-f]{6}$", req["request_id"])
        cert = sqlsource.resolve(cli._Q("Q-ORA-PARAMETERS-RAC-DIFF-001"), "19.0")
        script = open(os.path.join(d, "requests", req["request_id"] + ".sql"), encoding="utf-8").read()
        assert cert.sql + ";" in script and req["sql_sha256"] == cert.sql_sha256 and cert.sql_sha256 in script
        assert "SET MARKUP CSV ON" in script and req["csv_file"] in script
        for f in (".json", ".sql"):
            assert stat.S_IMODE(os.stat(os.path.join(d, "requests", req["request_id"] + f)).st_mode) == 0o600 or os.name == "nt"


@test
def the_script_has_no_statement_other_than_the_certified_select_and_sqlplus_settings():
    with tmpdir() as d, _Env(d):
        req = cli.make_request("Q-ORA-PARAMETERS-RAC-DIFF-001", "lab-ol8-19c", "19c", "SES-test-001")
        cert = sqlsource.resolve(cli._Q("Q-ORA-PARAMETERS-RAC-DIFF-001"), "19.0")
        script = open(os.path.join(d, "requests", req["request_id"] + ".sql"), encoding="utf-8").read()
        rest = script.replace(cert.sql + ";", "")
        for line in rest.splitlines():
            assert not line or line.startswith("--") or re.match(r"^(SET [A-Z]+ [A-Z0-9 ]+|SPOOL \S+|SPOOL OFF)$", line), line


@test
def requests_are_refused_for_unknown_inactive_or_unresolvable_queries_and_bad_ids():
    with tmpdir() as d, _Env(d):
        assert "unknown" in _refused(cli.make_request, "Q-NOPE-001", "lab-ol8-19c", "19c", "SES-test-001")
        assert "alias" in _refused(cli.make_request, "Q-ORA-PARAMETERS-RAC-DIFF-001", "Bad Alias!", "19c", "SES-test-001")
        assert "alias" in _refused(cli.make_request, "Q-ORA-PARAMETERS-RAC-DIFF-001", "lab-ol8-19c", "19c", "free text")
        assert "family" in _refused(cli.make_request, "Q-ORA-PARAMETERS-RAC-DIFF-001", "lab-ol8-19c", "7.3", "SES-test-001")
        assert "active" in _refused(cli.make_request, "Q-SEC-NETWORK-ENCRYPTION-PARAMS-001", "lab-ol8-19c", "19c", "SES-test-001")
        assert not os.listdir(os.path.join(d)) or not os.listdir(os.path.join(d, "requests"))


@test
def a_request_never_takes_sql_from_the_caller():
    import inspect
    assert list(inspect.signature(cli.make_request).parameters) == ["query_id", "target_alias", "oracle_version", "scope", "params",
                                                                     "license_confirmed", "confirmed_by"]
    # params are typed values for bind variables, never SQL: see the bind-parameter cases below


# --- typed bind parameters (CHG-ESTACK-SEC-QUERIES-001) ------------------------------------------------------

BIND_Q = "Q-ORA-REDO-SWITCH-FREQ-001"          # :window_start / :window_end
WINDOW = {"window_start": "2026-10-01T00:00:00", "window_end": "2026-10-02T00:00:00"}


@test
def a_query_with_binds_is_refused_without_its_parameters_and_says_which():
    with tmpdir() as d, _Env(d):
        msg = _refused(cli.make_request, BIND_Q, "lab-ol8-19c", "19c", "SES-test-001")
        assert "requires parameters" in msg and "window_start" in msg and "YYYY-MM-DD" in msg, msg
        assert not os.path.isdir(os.path.join(d, "requests")) or not os.listdir(os.path.join(d, "requests"))


@test
def parameters_are_rendered_as_typed_literals_and_the_rendered_sql_is_recorded():
    import hashlib
    with tmpdir() as d, _Env(d):
        req = cli.make_request(BIND_Q, "lab-ol8-19c", "19c", "SES-test-001", dict(WINDOW))
        script = open(os.path.join(d, "requests", req["request_id"] + ".sql"), encoding="utf-8").read()
        assert ":window_start" not in script and "TO_DATE('2026-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')" in script, script
        assert req["parameters"] == WINDOW and len(req["rendered_sql_sha256"]) == 64
        sql = script[script.index("SELECT"):script.index("SPOOL OFF")].rstrip().rstrip(";")
        assert hashlib.sha256(sql.encode()).hexdigest() == req["rendered_sql_sha256"]


@test
def parameter_values_cannot_carry_sql():
    with tmpdir() as d, _Env(d):
        for bad in ({"window_start": "2026-10-01T00:00:00' OR '1'='1", "window_end": WINDOW["window_end"]},
                    {"window_start": "2026-10-01T00:00:00", "window_end": "2026-10-02T00:00:00; DROP TABLE x"},
                    {"window_start": "2026-13-45T99:00:00", "window_end": WINDOW["window_end"]},
                    {"window_start": "2026-1-1T0:0:0", "window_end": WINDOW["window_end"]},
                    {"window_start": WINDOW["window_end"], "window_end": WINDOW["window_start"]},
                    dict(WINDOW, max_rows="10")):
            msg = _refused(cli.make_request, BIND_Q, "lab-ol8-19c", "19c", "SES-test-001", bad)
            assert "invalid value" in msg or "before" in msg or "does not take" in msg, (bad, msg)
        from human_evidence import params as qp
        for name, value in (("max_rows", "1e9"), ("max_rows", "0"), ("sql_id", "abc' --"), ("function_name", "dbms_x;")):
            try:
                qp._literal(name, value, qp._types()[name])
                raise AssertionError(f"{name}={value} accepted")
            except qp.ParameterError:
                pass


@test
def binds_inside_literals_and_comments_are_not_parameters():
    from human_evidence import params as qp
    sql = "SELECT TO_CHAR(SYSDATE, 'HH24:MI:SS') AS t, ':not_a_bind' AS s -- :nor_this\nFROM dual WHERE x = :real /* :nope */"
    assert qp.binds_of(sql) == ["real"], qp.binds_of(sql)
    out = qp.render(sql.replace(":real", ":max_rows"), {"max_rows": "5"})
    assert "'HH24:MI:SS'" in out and "':not_a_bind'" in out and "x = 5" in out, out


@test
def ingest_refuses_a_request_whose_rendered_sql_no_longer_matches():
    with tmpdir() as d, _Env(d):
        req = cli.make_request(BIND_Q, "lab-ol8-19c", "19c", "SES-test-001", dict(WINDOW))
        p = os.path.join(d, "f.csv")
        _csv(p, ["THREAD#", "HOUR_BUCKET", "SWITCH_COUNT"], [["1", "01-OCT-26", "4"]])
        rp = os.path.join(d, "requests", req["request_id"] + ".json")
        open(rp, "w", encoding="utf-8").write(json.dumps(dict(req, parameters=dict(WINDOW, window_end="2026-10-03T00:00:00"))))
        assert "not the one this request rendered" in _refused(cli.ingest, req["request_id"], p, "REV-DBA01")
        open(rp, "w", encoding="utf-8").write(json.dumps(req))
        assert cli.ingest(req["request_id"], p, "REV-DBA01")["row_count"] == 1


@test
def the_cli_takes_repeatable_typed_params():
    with tmpdir() as d, _Env(d):
        import contextlib, io as _io
        out = _io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = cli.main(["request", "--query", BIND_Q, "--target", "lab-ol8-19c", "--version", "19c", "--scope", "SES-test-001",
                           "--param", "window_start=2026-10-01T00:00:00", "--param", "window_end=2026-10-02T00:00:00"])
        assert rc == 0 and json.loads(out.getvalue())["parameters"] == WINDOW
        err = _io.StringIO()
        with contextlib.redirect_stderr(err):
            rc = cli.main(["request", "--query", BIND_Q, "--target", "lab-ol8-19c", "--version", "19c", "--scope", "SES-test-001",
                           "--param", "window_start"])
        assert rc == 2 and "NAME=VALUE" in err.getvalue()


# --- license gate (CHG-ESTACK-AWR-LICENSED-001) -------------------------------------------------------------

AWR_Q = "Q-PERF-WAIT-AWR-001"


@test
def a_licensed_query_needs_every_license_key_confirmed_by_a_named_reviewer():
    with tmpdir() as d, _Env(d):
        for lic, by in (([], None), (["diagnostics_pack"], None), (["tuning_pack"], "REV-DBAMANAGER"), (["diagnostics_pack"], "bad id;")):
            msg = _refused(cli.make_request, AWR_Q, "lab-ol8-19c", "19c", "SES-test-001", dict(WINDOW), lic, by)
            assert "requires a confirmed Oracle license (diagnostics_pack)" in msg and "--confirmed-by" in msg, (lic, by, msg)
        req = cli.make_request(AWR_Q, "lab-ol8-19c", "19c", "SES-test-001", dict(WINDOW), ["diagnostics_pack"], "REV-DBAMANAGER")
        assert req["license_confirmation"] == {"keys": ["diagnostics_pack"], "confirmed_by": "REV-DBAMANAGER"}
        p = os.path.join(d, "w.csv")
        _csv(p, ["INSTANCE_NUMBER", "EVENT_NAME", "WAIT_CLASS", "TOTAL_WAIT_TIME_SEC"], [["1", "log file sync", "Commit", "1.5"]])
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        assert doc["provenance"]["license_confirmation"]["confirmed_by"] == "REV-DBAMANAGER"


@test
def unlicensed_queries_need_no_confirmation():
    with tmpdir() as d, _Env(d):
        req = cli.make_request("Q-ORA-PARAMETERS-001", "lab-ol8-19c", "19c", "SES-test-001")
        assert req["license_confirmation"] is None


# --- ingest --------------------------------------------------------------------------------------------------

@test
def ingest_writes_human_reported_evidence_with_the_probable_cause_ceiling():
    with tmpdir() as d, _Env(d):
        req, p = _params(d)
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        assert doc["provenance"]["kind"] == "HUMAN_REPORTED" and doc["provenance"]["observed_by_estack"] is False
        assert doc["validation_level"] == "HUMAN_REPORTED" and doc["confidence_ceiling"] == "PROBABLE_CAUSE"
        assert doc["provenance"]["sql_sha256"] == req["sql_sha256"] and doc["provenance"]["reporter_id"] == "REV-DBA01"
        out = os.path.join(d, "sanitized", doc["evidence_id"] + ".json")
        assert json.load(open(out, encoding="utf-8"))["evidence_id"] == doc["evidence_id"]
        assert stat.S_IMODE(os.stat(out).st_mode) == 0o600 or os.name == "nt"


@test
def no_secret_host_ip_path_connect_string_or_email_reaches_sanitized_evidence():
    with tmpdir() as d, _Env(d):
        req, p = _params(d)
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        text = open(os.path.join(d, "sanitized", doc["evidence_id"] + ".json"), encoding="utf-8").read()
        for leak in (SECRET, HOST, IP, PATH, "Tiger123", "sys/oracle@orcl", "dba@example.com", "corp.example"):
            assert leak not in text, leak
        assert any(x.startswith("SENSITIVE_VALUES_DROPPED:") for x in doc["limitations"]), doc["limitations"]


@test
def oracle_identifiers_and_numbers_survive_verbatim():
    with tmpdir() as d, _Env(d):
        req, p = _params(d)
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        byname = {r.get("name"): r for r in doc["rows"]}
        assert "remote_login_passwordfile" in byname and "_hidden_param_x" in byname, sorted(byname, key=str)
        assert byname["processes"]["value"] == 320, byname["processes"]
        assert byname["remote_login_passwordfile"]["value"].startswith("tok-")
        assert "value" not in byname["_hidden_param_x"], "a secret-shaped value is dropped, the row is kept"


@test
def paths_ips_and_hosts_are_masked_even_inside_a_keep_column():
    with tmpdir() as d, _Env(d):
        req, p = _params(d, rows=[["processes", "320", "FALSE", "FALSE"], [HOST, "1", "FALSE", "FALSE"],
                                  [IP, "1", "FALSE", "FALSE"], [PATH, "1", "FALSE", "FALSE"]])
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        assert {c["name"]: c["policy"] for c in doc["columns"]}["name"] == "KEEP"
        names = [r["name"] for r in doc["rows"]]
        assert names[0] == "processes" and all(n.startswith("nam-") for n in names[1:]), names


@test
def tokens_stay_local_and_aliases_are_stable_within_a_scope_and_differ_across_scopes():
    with tmpdir() as d, _Env(d):
        r1, p1 = _params(d, "SES-alpha-001")
        a = cli.ingest(r1["request_id"], p1, "REV-DBA01")
        r2, p2 = _params(d, "SES-alpha-001")
        b = cli.ingest(r2["request_id"], p2, "REV-DBA01")
        r3, p3 = _params(d, "SES-beta-001")
        c = cli.ingest(r3["request_id"], p3, "REV-DBA01")
        v = lambda doc: {r["name"]: r.get("value") for r in doc["rows"]}
        assert v(a)["audit_file_dest"] == v(b)["audit_file_dest"] != v(c)["audit_file_dest"]
        tok = os.path.join(d, "raw", r1["request_id"] + ".tokens.json")
        assert json.load(open(tok, encoding="utf-8"))[v(a)["audit_file_dest"]] == PATH
        assert stat.S_IMODE(os.stat(tok).st_mode) == 0o600 or os.name == "nt"
        assert not os.path.exists(os.path.join(d, "sanitized", r1["request_id"] + ".tokens.json"))


@test
def the_gateway_collector_spec_is_authoritative_and_unknown_columns_are_dropped():
    with tmpdir() as d, _Env(d):
        req = cli.make_request("Q-CDB-TABLESPACES-001", "lab-ol8-19c", "19c", "SES-test-001")
        p = os.path.join(d, "ts.csv")
        _csv(p, ["CON_ID", "TABLESPACE_NAME", "USED_PERCENT", "USED_SPACE", "TABLESPACE_SIZE", "STATUS", "CONTENTS", "AUTOEXTEND"], [
            ["3", "USERS", "12.5", "100", "800", "ONLINE", "PERMANENT", "YES"],
            ["3", "APP_DATA", "91", "900", "1000", "WEIRD", "PERMANENT", "NO"],
        ])
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        pol = {c["name"]: (c["policy"], c["reason"]) for c in doc["columns"]}
        assert pol["tablespace_name"] == ("MASK", "collector_spec") and pol["autoextend"] == ("DROP", "not_in_collector_spec"), pol
        assert all(r["tablespace_name"].startswith("ts-") for r in doc["rows"]) and doc["rows"][0]["used_percent"] == 12.5
        assert "status" not in doc["rows"][1], "a value outside the collector enum is not kept"
        assert all(set(c) == {"name", "policy", "reason"} for c in doc["columns"])


@test
def a_query_with_a_collector_spec_uses_the_lab_aliases_and_the_spec_types():
    with tmpdir() as d, _Env(d):
        req = cli.make_request("Q-ORA-PARAMETERS-001", "lab-ol8-19c", "19c", "SES-test-001")
        p = os.path.join(d, "par.csv")
        _csv(p, ["NAME", "ISDEFAULT", "ISMODIFIED", "VALUE_NUMBER", "VALUE_FLAG", "VALUE_VERSION", "VALUE_KEYWORD", "VALUE"], [
            ["processes", "FALSE", "FALSE", "480", "", "", "", "480"],
            ["compatible", "FALSE", "FALSE", "", "", "19.0.0", "", "19.0.0"],
            ["audit_file_dest", "FALSE", "FALSE", "", "", "", "", PATH],
            ["Bad Name", "MAYBE", "FALSE", "abc", "YES", "x.y", "WHATEVER", ""],
        ])
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        pol = {c["name"]: (c["policy"], c["reason"]) for c in doc["columns"]}
        assert pol["parameter_name"] == ("KEEP", "collector_spec") and pol["value"] == ("DROP", "not_in_collector_spec"), pol
        rows = doc["rows"]
        assert rows[0] == {"parameter_name": "processes", "isdefault": "FALSE", "ismodified": "FALSE", "value_number": 480}, rows[0]
        assert rows[1]["value_version"] == "19.0.0" and rows[2] == {"parameter_name": "audit_file_dest", "isdefault": "FALSE", "ismodified": "FALSE"}
        assert rows[3] == {"ismodified": "FALSE"}, rows[3]            # wrong shapes and enum values are dropped, not kept
        assert PATH not in json.dumps(doc)


@test
def ingest_refuses_changed_sql_bad_headers_ragged_rows_and_oversize_files():
    with tmpdir() as d, _Env(d):
        req, p = _params(d)
        rp = os.path.join(d, "requests", req["request_id"] + ".json")
        bad = dict(req, sql_sha256="0" * 64)
        open(rp, "w", encoding="utf-8").write(json.dumps(bad))
        assert "changed" in _refused(cli.ingest, req["request_id"], p, "REV-DBA01")
        open(rp, "w", encoding="utf-8").write(json.dumps(req))
        _csv(p, ["NAME", "VALUE; DROP TABLE x"], [["a", "b"]])
        assert "header" in _refused(cli.ingest, req["request_id"], p, "REV-DBA01")
        open(p, "w", encoding="utf-8").write('"NAME","VALUE"\n"a"\n')
        assert "ragged" in _refused(cli.ingest, req["request_id"], p, "REV-DBA01")
        with open(p, "w", encoding="utf-8") as f:
            f.write('"NAME"\n' + ('"x"\n' * (cli.MAX_FILE_BYTES // 4 + 1)))
        assert "large" in _refused(cli.ingest, req["request_id"], p, "REV-DBA01")
        assert "invalid" in _refused(cli.ingest, "ER-../../etc", p, "REV-DBA01")
        assert "invalid" in _refused(cli.ingest, req["request_id"], p, "rev dba; rm")
        assert not os.path.exists(os.path.join(d, "sanitized")) or not os.listdir(os.path.join(d, "sanitized"))


@test
def rows_beyond_the_request_limit_are_truncated_and_declared():
    with tmpdir() as d, _Env(d):
        req, p = _params(d)
        rp = os.path.join(d, "requests", req["request_id"] + ".json")
        open(rp, "w", encoding="utf-8").write(json.dumps(dict(req, max_rows=3)))
        doc = cli.ingest(req["request_id"], p, "REV-DBA01")
        assert doc["row_count"] == 3 and "ROWS_TRUNCATED_TO_LIMIT" in doc["limitations"]


# --- classifier ----------------------------------------------------------------------------------------------

@test
def sensitive_named_columns_are_dropped_even_with_an_override():
    for n in ("password", "spare4", "sql_text", "wallet_location", "api_key", "bind_data"):
        assert classify_column(n, ["x"], "KEEP")[0] == "DROP", n
        assert classify_column(n, ["x"])[0] == "DROP", n


@test
def identity_columns_are_masked_long_text_dropped_and_the_rest_tokenized():
    assert classify_column("owner", ["HR"])[0] == "MASK"
    assert classify_column("host_name", ["db01"])[0] == "MASK"
    assert classify_column("status", ["VALID"])[0] == "KEEP"
    assert classify_column("bytes", ["1", "2.5"])[0] == "KEEP"
    assert classify_column("comments", ["x" * 200])[0] == "DROP"
    assert classify_column("detail", ["a b c, with 'quotes'"])[0] == "TOKENIZE"
    try:
        classify_column("x", ["1"], "PUBLISH")
        raise AssertionError("invalid override accepted")
    except ValueError:
        pass


@test
def the_secret_detector_spares_oracle_identifiers_only():
    for ok in (PATH, "+DATA/ORCL/DATAFILE/system.257.1234567", "remote_login_passwordfile", "_optimizer_adaptive_plans", "DBA_HIST_ACTIVE_SESS_HISTORY", "log_archive_dest_10"):
        assert not value_is_sensitive(ok), ok
    for bad in (SECRET, "abcdefghij0123456789abcd", "password=Tiger123", "sys/oracle@orcl", "dba@example.com",
                "Bearer abc.def", "/u01/" + SECRET, "AKIA" + "A" * 16, "f" * 40, "jdbc://u:p@h"):
        assert value_is_sensitive(bad), bad


@test
def overrides_file_is_valid_and_only_names_certified_queries_without_a_collector_spec():
    d = json.load(open(cli.OVERRIDES, encoding="utf-8"))
    assert d["queries"], "overrides file must not be empty"
    for qid, cols in d["queries"].items():
        assert catalog._find_query_file(qid), qid
        assert cli._collector_fields(qid) is None, f"{qid}: the gateway spec is authoritative, remove the override"
        for col, pol in cols.items():
            assert re.match(r"^[a-z0-9_#$]{1,64}$", col) and pol in ("KEEP", "MASK", "HASH", "TOKENIZE", "DROP"), (qid, col, pol)


@test
def the_package_has_no_database_driver_network_or_shell_access():
    src = "".join(open(os.path.join(ROOT, "human_evidence", f), encoding="utf-8").read()
                  for f in os.listdir(os.path.join(ROOT, "human_evidence")) if f.endswith(".py"))
    for bad in ("oracledb", "cx_Oracle", "subprocess", "socket", "urllib", "requests", "os.system", "keyring", "execute("):
        assert re.search(r"\b" + re.escape(bad), src) is None or bad == "requests" and "import requests" not in src, bad


if __name__ == "__main__":
    raise SystemExit(run_all())
