"""Phase 13 — gateway security: no execution/network/arbitrary-file capability, certified-SQL guard, target
catalog hygiene, real adapters disabled, startup fail-closed, operator flags, environment cannot change policy."""
import ast
import glob
import json
import os
import re
import subprocess
import sys

from tests.p13.harness import (
    MARKER, PRIMARY, ROOT, ProcClient, default_targets, leaks, make_fixture_dir, make_targets_file, run_all, test, tmpdir,
)

PKG = os.path.join(ROOT, "mcp_gateway")


def run_cli(*args, env_extra=None, cwd=ROOT):
    env = dict(os.environ, PYTHONPATH=ROOT, PYTHONDONTWRITEBYTECODE="1", PYTHONUTF8="1")
    env.update(env_extra or {})
    p = subprocess.run([sys.executable, "-m", "mcp_gateway", *args], capture_output=True, text=True, encoding="utf-8", cwd=cwd, env=env,
                       stdin=subprocess.DEVNULL, timeout=60)
    return p.returncode, p.stdout, p.stderr


@test
def gateway_source_has_no_execution_network_dynamic_import_or_environment_capability():
    banned_imports = {"subprocess", "socket", "urllib", "http", "requests", "ctypes", "ftplib", "smtplib", "telnetlib", "asyncio",
                      "multiprocessing", "pty", "webbrowser", "importlib", "pickle", "shelve", "sqlite3", "cx_Oracle", "oracledb", "jaydebeapi",
                      "paramiko", "xmlrpc", "socketserver", "ssl", "code", "runpy"}
    banned_attr = {"system", "popen", "spawn", "spawnl", "execv", "execl", "fork", "getenv", "putenv", "environ", "startfile", "listen", "bind", "connect"}
    banned_name = {"eval", "exec", "compile", "__import__", "input"}
    for path in sorted(glob.glob(os.path.join(PKG, "*.py"))):
        tree = ast.parse(open(path, encoding="utf-8").read())
        base = os.path.basename(path)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    assert a.name.split(".")[0] not in banned_imports, f"{base} imports {a.name}"
            elif isinstance(node, ast.ImportFrom) and node.module:
                assert node.module.split(".")[0] not in banned_imports, f"{base} imports from {node.module}"
            elif isinstance(node, ast.Call):
                f = node.func
                if isinstance(f, ast.Attribute):
                    assert f.attr not in banned_attr, f"{base} calls .{f.attr}()"
                else:
                    assert getattr(f, "id", "") not in banned_name, f"{base} calls {f.id}()"
            elif isinstance(node, ast.Attribute) and node.attr in ("environ", "getenv"):
                raise AssertionError(f"{base} reads the environment")
    srcs = "\n".join(open(p, encoding="utf-8").read() for p in glob.glob(os.path.join(PKG, "*.py")))
    assert "shell=True" not in srcs and "os.system" not in srcs


@test
def only_the_bounded_worker_thread_exists_and_no_server_socket_or_listener_is_created():
    srcs = {os.path.basename(p): open(p, encoding="utf-8").read() for p in glob.glob(os.path.join(PKG, "*.py"))}
    users = [n for n, s in srcs.items() if re.search(r"^\s*import threading|^\s*from threading", s, re.M)]
    assert users == ["adapters.py"], f"threading is allowed only for the adapter deadline: {users}"
    for n, s in srcs.items():
        assert not re.search(r"\b(HTTPServer|TCPServer|create_server|serve_forever|\.listen\()", s), n


@test
def no_tool_schema_property_or_default_can_carry_free_form_input_and_all_objects_are_closed():
    from mcp_gateway.gateway import TOOLS
    forbidden = {"sql", "query", "statement", "command", "cmd", "shell", "script", "path", "file", "filename", "url", "uri", "dsn", "host", "hostname",
                 "port", "password", "user", "username", "wallet", "where", "connection", "connect_string", "code", "template", "expression"}

    def walk(s, where):
        if s["type"] == "object":
            assert s["additionalProperties"] is False, where
            assert not (set(s["properties"]) & forbidden), where
            for k, v in s["properties"].items():
                walk(v, f"{where}.{k}")
        if s["type"] == "string":
            assert "maxLength" in s, where
        if s["type"] == "array":
            assert "maxItems" in s, where
            walk(s["items"], where + "[]")
    for name, t in TOOLS.items():
        walk(t["inputSchema"], name)


@test
def certified_sql_guard_accepts_selects_and_rejects_dml_ddl_plsql_and_stacked_statements():
    from mcp_gateway.catalog import assert_read_only_sql
    good = ["SELECT a FROM v$x WHERE b = 1", "select a from t;", "WITH q AS (SELECT 1 FROM dual) SELECT * FROM q", "-- c\nSELECT 1 FROM dual"]
    for g in good:
        assert_read_only_sql(g)
    bad = ["DELETE FROM t", "UPDATE t SET a=1", "INSERT INTO t VALUES (1)", "DROP TABLE t", "ALTER SYSTEM SET x=1", "SELECT 1 FROM dual; DROP TABLE t",
           "BEGIN NULL; END;", "CREATE TABLE t (a int)", "GRANT DBA TO x", "SELECT * FROM t FOR UPDATE", "SELECT dbms_utility.get_time FROM dual",
           "SELECT 1 INTO x FROM dual", "TRUNCATE TABLE t", "EXEC foo", "MERGE INTO t USING s ON (1=1)", "commit", "select 1 from dual; select 2 from dual"]
    for b in bad:
        try:
            assert_read_only_sql(b)
        except RuntimeError:
            continue
        raise AssertionError(f"accepted a non read-only statement: {b}")


@test
def every_exposed_sql_collector_is_backed_by_a_certified_r0_read_only_query_with_immutable_provenance():
    from mcp_gateway.catalog import load_collectors
    cols = load_collectors()
    sql_like = [c for c in cols.values() if c.kind in ("sql_query", "alert_log_excerpt")]
    assert len(sql_like) >= 5
    for c in sql_like:
        assert c.risk_class == "R0" and c.query_id == c.collector_id
        if c.kind == "sql_query":
            assert re.fullmatch(r"[0-9a-f]{64}", c.query_sha256), c.collector_id
    for c in cols.values():
        for f in c.output_fields.values():
            assert not (f["type"] == "text" and f["policy"] != "DROP") and not (f["type"] == "identifier" and f["policy"] == "KEEP")


@test
def a_collector_that_is_not_in_the_repository_registry_or_not_certified_cannot_be_loaded():
    import mcp_gateway.catalog as cat
    with tmpdir() as d:
        spec = json.load(open(cat.DEFAULT_COLLECTORS_FILE, encoding="utf-8"))
        spec["collectors"][0] = dict(spec["collectors"][0], collector_id="Q-NOT-IN-REGISTRY-001")
        p = os.path.join(d, "c.json")
        json.dump(spec, open(p, "w"))
        try:
            cat.load_collectors(p)
        except RuntimeError:
            pass
        else:
            raise AssertionError("an uncertified collector id must be refused at load time")
        spec = json.load(open(cat.DEFAULT_COLLECTORS_FILE, encoding="utf-8"))
        spec["collectors"][0]["output_fields"]["instance_name"]["policy"] = "KEEP"      # identifiers may never be KEEP
        json.dump(spec, open(p, "w"))
        try:
            cat.load_collectors(p)
        except RuntimeError:
            pass
        else:
            raise AssertionError("KEEP on an identifier must be refused")


@test
def target_catalog_rejects_connection_material_unknown_collectors_and_bad_aliases():
    import mcp_gateway.catalog as cat
    cols = cat.load_collectors()
    base = default_targets()["targets"][0]
    for bad in (dict(base, password="x"), dict(base, dsn="h/s"), dict(base, host="db01"), dict(base, wallet="/w"), dict(base, connection_string="u/p@h"),
                dict(base, allowed_collectors=["Q-SOMETHING-ELSE-001"]), dict(base, alias="Bad Alias"), dict(base, alias="../x"),
                dict(base, oracle_version="19.3.0"), dict(base, role="ADMIN")):
        with tmpdir() as d:
            p = make_targets_file(d, [bad])
            try:
                cat.load_targets(p, cols)
            except RuntimeError:
                continue
            raise AssertionError(f"accepted a hostile target definition: {list(bad)[:3]}")
    shipped = default_targets()
    keys = {k for t in shipped["targets"] for k in t}
    assert not (keys & {"password", "dsn", "host", "hostname", "user", "username", "wallet", "connection_string", "token", "secret", "tns"}), keys
    values = json.dumps([t for t in shipped["targets"]]).lower()
    assert "@" not in values and "jdbc:" not in values and "://" not in values, "shipped targets carry no connection material"


@test
def real_adapters_stay_disabled_even_if_a_target_file_tries_to_enable_them():
    with tmpdir() as d:
        base = default_targets()["targets"]
        real = dict(base[0], alias="real-oracle-enabled", adapter="oracle_sql", enabled=True, allowed_collectors=["Q-DISC-IDENTITY-001"])
        os_real = dict(base[0], alias="real-os-enabled", adapter="os_readonly", enabled=True, allowed_collectors=["os.get_process_limits"])
        unknown = dict(base[0], alias="unknown-adapter", adapter="jdbc_direct", enabled=True, allowed_collectors=["Q-DISC-IDENTITY-001"])
        tf = make_targets_file(d, [real, os_real, unknown])
        os.makedirs(os.path.join(d, "fixtures"), exist_ok=True)
        c = ProcClient(targets=tf, fixtures=os.path.join(d, "fixtures"), env_extra={"ORACLE_HOME": "/nonexistent", "TNS_ADMIN": "/nonexistent",
                                                                          "ESTACK_ENABLE_REAL": "1", "ORACLE_PASSWORD": MARKER})
        c.initialize()
        caps = c.call("diagnostics.list_capabilities")[0]
        assert caps["adapters"]["oracle_sql"] == "DISABLED" and caps["adapters"]["os_readonly"] == "CONTRACT_ONLY"
        for alias, cid in (("real-oracle-enabled", "Q-DISC-IDENTITY-001"), ("real-os-enabled", "os.get_process_limits"), ("unknown-adapter", "Q-DISC-IDENTITY-001")):
            env, res = c.call("diagnostics.collect", {"collector_id": cid, "target_alias": alias})
            assert res["isError"] and env["error"]["code"] == "E_CAPABILITY" and env["capability_status"] == "DISABLED", alias
        c.close()
        assert not leaks(c.stderr_text + b"".join(c.stdout_lines).decode())


@test
def environment_variables_cannot_change_policy_adapters_or_limits():
    base = ProcClient()
    base.initialize()
    a = base.call("diagnostics.list_capabilities")[0]
    base.close()
    env = {"MCP_GATEWAY_ENABLE_REAL": "1", "ESTACK_ENABLE_REAL_ADAPTERS": "true", "MCP_ALLOW_ALL": "1", "ESTACK_APPROVE": "1",
           "PYTHONPATH": ROOT}
    other = ProcClient(env_extra=env)
    other.initialize()
    b = other.call("diagnostics.list_capabilities")[0]
    other.close()
    strip = lambda e: json.dumps({k: v for k, v in e.items() if k not in ("request_id", "target_token")}, sort_keys=True)
    assert strip(a) == strip(b)


@test
def startup_fails_closed_with_fixed_stderr_text_and_empty_stdout_on_bad_configuration():
    with tmpdir() as d:
        bad = os.path.join(d, "bad.json")
        open(bad, "w").write("{ not json " + MARKER)
        for args in (["--targets", bad], ["--targets", os.path.join(d, "missing.json")], ["--fixtures-dir", os.path.join(d, "missing")]):
            rc, out, err = run_cli(*args)
            assert rc == 2 and out == "" and err.strip() == "mcp_gateway: startup refused (catalog, target or fixture configuration is invalid)", args
            assert MARKER not in err
        leak = dict(default_targets()["targets"][0], password=MARKER)
        rc, out, err = run_cli("--targets", make_targets_file(d, [leak]))
        assert rc == 2 and out == "" and MARKER not in err


@test
def cli_has_no_flag_to_enable_real_adapters_open_listeners_or_add_collectors_and_errors_do_not_echo():
    rc, out, err = run_cli("--help")
    assert rc == 0
    assert not re.search(r"--(enable|connect|dsn|host|port|listen|bind|http|tcp|sql|shell|exec|collector|adapter|password|token|real)\b", out), out
    for bad in (["--bogus"], ["--adapter", "oracle_sql"], ["--listen", "0.0.0.0:80"], ["--audit", MARKER], ["extra-" + MARKER]):
        rc, out2, err2 = run_cli(*bad)
        assert rc == 2 and out2 == "" and err2.strip() == "mcp_gateway: invalid command line usage" and MARKER not in err2


@test
def claude_code_config_example_has_no_credentials_hosts_or_real_paths_and_is_fixture_only():
    rc, out, err = run_cli("--print-claude-config")
    assert rc == 0
    cfg = json.loads(out)
    text = json.dumps(cfg).lower()
    for w in ("password", "token", "secret", "dsn", "wallet", "@", "://", "jdbc", "users\\", "/home/", "c:\\"):
        assert w not in text, w
    srv = cfg["mcpServers"]["oracle-diagnostic-estack"]
    assert srv["command"] == "python" and srv["args"] == ["-m", "mcp_gateway"] and "<" in srv["cwd"], "placeholder path, not a real one"
    assert "fixture" in text


@test
def fixture_reads_are_confined_traversal_and_links_do_not_escape_the_fixtures_directory():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {(PRIMARY, "Q-DISC-IDENTITY-001"): [{"version": "19.0.0.0.0"}]})
        outside = os.path.join(d, "outside")
        os.makedirs(outside)
        secret_file = os.path.join(outside, "Q-ORA-PROCESSES-SUMMARY-001.json")
        open(secret_file, "w").write('{"rows": [{"process_count": 1, "processes_limit": 2}]}')
        link = os.path.join(fx, PRIMARY)
        # replace the alias directory with a link that points outside the fixtures directory
        import shutil
        shutil.rmtree(link)
        made = False
        try:
            os.symlink(outside, link)
            made = True
        except (OSError, NotImplementedError):
            if os.name == "nt":
                r = subprocess.run(["cmd", "/c", "mklink", "/J", link, outside], capture_output=True)
                made = r.returncode == 0
        if not made:
            raise AssertionError("could not create a link to test confinement in this environment (INCONCLUSIVE)")
        c = ProcClient(fixtures=fx)
        c.initialize()
        env, res = c.call("diagnostics.collect", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY})
        assert res["isError"] and env["error"]["code"] == "E_ADAPTER_FAILED", "a link leaving the fixtures directory must not be followed"
        c.close()


@test
def no_repository_secrets_or_real_hosts_ship_inside_the_gateway_package():
    for p in glob.glob(os.path.join(PKG, "**", "*"), recursive=True):
        if os.path.isfile(p) and p.endswith((".json", ".py")):
            t = open(p, encoding="utf-8").read().lower()
            assert not re.search(r"(?<![a-z])(password|passwd|secret|api[_-]?key)\s*[:=]\s*[\"']?[a-z0-9]{6,}", t.replace("password=\"x\"", "")), p
            assert "begin private key" not in t and "akia" not in t, p


if __name__ == "__main__":
    raise SystemExit(run_all())
