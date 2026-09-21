"""Phase 14 — packaging and reproducibility: the deployable runtime must run from a clean copy made only of the
files git knows about, without site-packages, without importing anything from the original checkout, without
optional dependencies and without any network attempt."""
import ast
import json
import os
import shutil
import subprocess
import sys

from tests.p14.harness import PRIMARY, ROOT, run_all, test, tmpdir, write

RUNTIME_DIRS = ("mcp_gateway", "rca_engine", "change_documentation_knowledge", "queries")
RUNTIME_PACKAGES = ("mcp_gateway", "rca_engine", "change_documentation_knowledge")
MSGS = [{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "pkg", "version": "0"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"}, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY}}},
        {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY}}},
        {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {"collector_id": "os.get_process_limits", "target_alias": PRIMARY}}}]


def env():
    keep = {k: v for k, v in os.environ.items() if k.upper() in ("PATH", "SYSTEMROOT", "SYSTEMDRIVE", "WINDIR", "TEMP", "TMP", "COMSPEC", "PATHEXT")}
    return dict(keep, PYTHONDONTWRITEBYTECODE="1")


def clean_copy(d, dirs=RUNTIME_DIRS):
    """Copy ONLY the project files git knows about (tracked + untracked-not-ignored) under `dirs`, as a fresh clone would have them."""
    from release_readiness import fingerprint
    existing, _deleted = fingerprint.list_project_files(ROOT)
    dst = os.path.join(d, "clean_checkout")
    n = 0
    for rel in existing:
        if rel.split("/", 1)[0] in dirs:
            target = os.path.join(dst, *rel.split("/"))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.copyfile(os.path.join(ROOT, rel), target)
            n += 1
    assert n > 100, "the copy must contain the runtime"
    return dst


def run_isolated(copy_root, argv, payload=b"", timeout=60, flags=("-E", "-s", "-S", "-B")):
    return subprocess.run([sys.executable, *flags, *argv], input=payload, capture_output=True, cwd=copy_root, timeout=timeout, env=env())


def replies_of(proc):
    return {m["id"]: m for m in (json.loads(l) for l in proc.stdout.decode("utf-8").splitlines() if l.strip())}


def payload():
    return b"".join(json.dumps(m).encode() + b"\n" for m in MSGS)


@test
def the_runtime_imports_only_the_standard_library_and_its_own_packages():
    stdlib = set(sys.stdlib_module_names)
    internal = set(RUNTIME_PACKAGES) | {"release_readiness", "capacity_engine"}
    seen_third_party = []
    for pkg in RUNTIME_PACKAGES + ("release_readiness", "capacity_engine"):
        for dp, dn, fn in os.walk(os.path.join(ROOT, pkg)):
            dn[:] = [x for x in dn if x != "__pycache__"]
            for f in fn:
                if not f.endswith(".py"):
                    continue
                tree = ast.parse(open(os.path.join(dp, f), "rb").read())
                for node in ast.walk(tree):
                    mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""] if isinstance(node, ast.ImportFrom) and node.level == 0 else []
                    for m in mods:
                        top = m.split(".")[0]
                        if top and top not in stdlib and top not in internal:
                            seen_third_party.append((os.path.join(pkg, f), top))
    assert not seen_third_party, seen_third_party[:5]
    for pkg in RUNTIME_PACKAGES:
        for dp, dn, fn in os.walk(os.path.join(ROOT, pkg)):
            for f in [x for x in fn if x.endswith(".py")]:
                tree = ast.parse(open(os.path.join(dp, f), "rb").read())
                for node in ast.walk(tree):
                    if isinstance(node, ast.ImportFrom) and node.level == 0 and (node.module or "").split(".")[0] in ("release_readiness", "capacity_engine", "tests"):
                        raise AssertionError(f"the runtime must not depend on tooling or tests: {dp}/{f}")


@test
def a_clean_copy_of_the_git_known_files_runs_a_full_session_without_site_packages():
    with tmpdir() as d:
        copy = clean_copy(d)
        p = run_isolated(copy, ["-m", "mcp_gateway", "--audit", "off"], payload())
        assert p.returncode == 0 and p.stderr == b"", p.stderr[-300:]
        r = replies_of(p)
        assert set(r) == {1, 2, 3, 4, 5} and len(r[2]["result"]["tools"]) == 5
        for i in (3, 4, 5):
            env_ = r[i]["result"]["structuredContent"]
            assert not r[i]["result"]["isError"] and env_["sanitization_status"] == "SANITIZED" and env_["provenance"]["real_observation"] is False, i
        assert run_isolated(copy, ["-m", "mcp_gateway", "--version"]).returncode == 0
        assert b"mcpServers" in run_isolated(copy, ["-m", "mcp_gateway", "--print-claude-config"]).stdout


@test
def nothing_is_imported_from_the_original_checkout_when_running_from_the_copy():
    with tmpdir() as d:
        copy = clean_copy(d)
        code = ("import sys, json, mcp_gateway.cli, mcp_gateway.server, rca_engine, change_documentation_knowledge.change\n"
                "print(json.dumps(sorted({getattr(m, '__file__', '') or '' for n, m in sys.modules.items() if n.split('.')[0] in "
                "('mcp_gateway', 'rca_engine', 'change_documentation_knowledge')})))\n")
        p = run_isolated(copy, ["-c", code])
        assert p.returncode == 0, p.stderr.decode()[-300:]
        files = json.loads(p.stdout.decode())
        assert files and all(os.path.normcase(os.path.realpath(f)).startswith(os.path.normcase(os.path.realpath(copy))) for f in files if f), files
        original = os.path.normcase(os.path.realpath(ROOT))
        assert not any(os.path.normcase(os.path.realpath(f)).startswith(original) for f in files if f)
        p = run_isolated(copy, ["-c", "import sys; print(json.dumps([x for x in sys.path]))".replace("json.dumps", "__import__('json').dumps")])
        paths = json.loads(p.stdout.decode())
        assert not any(os.path.normcase(os.path.realpath(x or ".")) == original for x in paths if x != ""), "the original checkout must not be on sys.path"


@test
def explicit_configuration_is_honored_and_defaults_are_not_consulted_when_told_otherwise():
    with tmpdir() as d:
        copy = clean_copy(d)
        custom_targets = os.path.join(d, "custom_targets.json")
        target = {"alias": "custom-only-target", "adapter": "fixture", "enabled": True, "oracle_version": "19c", "role": "PRIMARY", "container": "NON_CDB",
                  "architecture": {"rac": False}, "license_status": {}, "allowed_collectors": ["Q-ORA-PROCESSES-SUMMARY-001"], "budget": {"max_calls": 5, "max_rows": 20}}
        write(custom_targets, json.dumps({"schema_version": "1.0.0", "targets": [target]}))
        fx = os.path.join(d, "custom_fixtures")
        write(os.path.join(fx, "custom-only-target", "Q-ORA-PROCESSES-SUMMARY-001.json"), json.dumps({"rows": [{"process_count": 7, "processes_limit": 70}]}))
        msgs = MSGS[:2] + [{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "diagnostics.list_capabilities", "arguments": {}}},
                           {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": "custom-only-target"}}},
                           {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "diagnostics.collect", "arguments": {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001", "target_alias": PRIMARY}}}]
        p = run_isolated(copy, ["-m", "mcp_gateway", "--audit", "off", "--targets", custom_targets, "--fixtures-dir", fx], b"".join(json.dumps(m).encode() + b"\n" for m in msgs))
        assert p.returncode == 0, p.stderr.decode()[-300:]
        r = replies_of(p)
        aliases = [t["target_alias"] for t in r[2]["result"]["structuredContent"]["targets"]]
        assert aliases == ["custom-only-target"], "only the explicitly supplied configuration is in force"
        assert r[3]["result"]["structuredContent"]["evidence"]["rows"][0]["process_count"] == 7
        assert r[4]["result"]["isError"] and r[4]["result"]["structuredContent"]["error"]["code"] == "E_TARGET_UNKNOWN", "the shipped targets are not consulted"


@test
def no_optional_dependency_is_ever_imported_or_assumed():
    deny = ["yaml", "requests", "numpy", "pandas", "scipy", "cryptography", "oracledb", "cx_Oracle", "jaydebeapi", "psutil", "colorama", "pydantic", "jsonschema",
            "mcp", "anthropic", "openai", "httpx", "aiohttp", "paramiko", "pexpect"]
    code = ("import sys, json\n"
            f"DENY = set({deny!r})\n"
            "attempts = []\n"
            "class Rec:\n"
            "    def find_spec(self, name, path=None, target=None):\n"
            "        if name.split('.')[0] in DENY:\n"
            "            attempts.append(name)\n"
            "            raise ImportError('blocked')\n"
            "sys.meta_path.insert(0, Rec())\n"
            "import mcp_gateway.cli, mcp_gateway.server, mcp_gateway.gateway, mcp_gateway.bridge, rca_engine, change_documentation_knowledge.change\n"
            "import change_documentation_knowledge.cli, release_readiness.cli, release_readiness.gate, capacity_engine\n"
            "print(json.dumps(attempts))\n")
    p = subprocess.run([sys.executable, "-E", "-s", "-S", "-B", "-c", code], capture_output=True, cwd=ROOT, timeout=60, env=env())
    assert p.returncode == 0, p.stderr.decode()[-300:]
    assert json.loads(p.stdout.decode()) == [], "an optional third-party module was imported or probed"


DRIVER = r"""
import os, socket, subprocess, sys, runpy
marker = sys.argv[1]
def _blocked(*a, **k):
    with open(marker, "a") as f:
        f.write("attempt\n")
    raise OSError("blocked by the test")
for name in ("connect", "connect_ex", "bind", "listen", "sendto"):
    setattr(socket.socket, name, _blocked)
socket.create_connection = socket.getaddrinfo = socket.gethostbyname = _blocked
subprocess.Popen.__init__ = _blocked
os.system = _blocked
sys.argv = ["mcp_gateway", "--audit", "off"]
runpy.run_module("mcp_gateway", run_name="__main__")
"""


@test
def the_clean_copy_makes_no_network_or_process_attempt_during_a_full_session():
    with tmpdir() as d:
        copy = clean_copy(d)
        marker = os.path.join(d, "attempts.txt")
        p = subprocess.run([sys.executable, "-E", "-s", "-S", "-B", "-c", DRIVER, marker], input=payload(), capture_output=True, cwd=copy, timeout=60, env=env())
        assert p.returncode == 0, p.stderr.decode()[-300:]
        assert not os.path.exists(marker), "an unapproved network or process call was attempted"
        assert len(replies_of(p)) == 5


@test
def running_the_runtime_leaves_no_files_behind_in_the_copy_or_elsewhere():
    with tmpdir() as d:
        copy = clean_copy(d)

        def snapshot():
            return sorted(os.path.relpath(os.path.join(dp, f), d) for dp, _dn, fn in os.walk(d) for f in fn)
        before = snapshot()
        p = run_isolated(copy, ["-m", "mcp_gateway"], payload())
        assert p.returncode == 0
        after = snapshot()
        assert before == after, sorted(set(after) ^ set(before))[:5]
        assert not any(n.startswith(".audit") for n in os.listdir(copy)), "the gateway must not create an audit directory"
        assert b"AUDIT" in p.stderr, "audit goes to stderr and nowhere else"


@test
def the_documented_install_and_health_commands_work_from_a_clean_copy():
    with tmpdir() as d:
        copy = clean_copy(d)
        out = run_isolated(copy, ["-m", "mcp_gateway", "--version"])
        assert out.returncode == 0 and b"oracle-diagnostic-estack-mcp-gateway" in out.stdout
        cfg = json.loads(run_isolated(copy, ["-m", "mcp_gateway", "--print-claude-config"]).stdout.decode())
        srv = cfg["mcpServers"]["oracle-diagnostic-estack"]
        assert srv["command"] == "python" and srv["args"] == ["-m", "mcp_gateway"] and srv["cwd"].startswith("<")
        assert json.dumps(cfg).lower().count("password") == 0 and "secret" not in json.dumps(cfg).lower()


if __name__ == "__main__":
    raise SystemExit(run_all())
