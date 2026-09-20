"""
tests/p13/harness.py — MCP test clients + tiny assertion runner for the Phase 13 gateway tests.

ProcClient   spawns `python -m mcp_gateway` as a REAL subprocess and speaks newline-delimited JSON-RPC over
             its stdin/stdout (the actual MCP stdio transport). stderr is captured separately.
InProcClient drives McpServer in this process (used by mutation controls, which must patch code).

Both expose the same small API so the same scenarios can run against either:
    initialize(version) / initialized() / request(method, params) / call(tool, args) /
    raw(bytes) -> [responses]  /  stdout_lines / stderr_text / close()

Everything runs on SYNTHETIC fixtures only; nothing here touches Oracle, the network or the host.
"""
import contextlib
import io
import json
import os
import queue
import subprocess
import sys
import tempfile
import threading
import time
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)
MARKER = "SYNTHETIC_SECRET_DO_NOT_USE"
MARKER2 = "SYNTHETIC-SECRET-DO-NOT-USE"
PRIMARY = "fixture-primary-19c"

_TESTS = []


class Skip(Exception):
    pass


def test(fn):
    _TESTS.append(fn)
    return fn


def run_all() -> int:
    cases = list(_TESTS)
    timing = os.environ.get("P13_TIMING") == "1"
    failed = 0
    for fn in cases:
        t0 = time.time()
        try:
            fn()
            print(f"[PASS] {fn.__name__}")
        except Skip as e:
            print(f"[SKIP] {fn.__name__}: {e}")
        except AssertionError as e:
            failed += 1
            print(f"[FAIL] {fn.__name__}: {e}")
        except Exception:
            failed += 1
            print(f"[FAIL] {fn.__name__}: unexpected exception")
            traceback.print_exc()
        if timing:
            print(f"[TIME] {fn.__name__} {time.time() - t0:.2f}s")
    print(f"{len(cases) - failed}/{len(cases)} checks OK")
    return 1 if failed else 0


@contextlib.contextmanager
def tmpdir():
    d = tempfile.mkdtemp(prefix="p13_")
    try:
        yield d
    finally:
        import shutil
        shutil.rmtree(d, ignore_errors=True)


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f)


def make_fixture_dir(d, mapping):
    """mapping: {(alias, collector_id): rows}; writes <d>/<alias>/<collector_id>.json"""
    base = os.path.join(d, "fixtures")
    for (alias, cid), rows in mapping.items():
        write_json(os.path.join(base, alias, cid + ".json"), {"rows": rows})
    return base


def default_targets():
    with open(os.path.join(ROOT, "mcp_gateway", "config", "targets.fixture.json"), encoding="utf-8") as f:
        return json.load(f)


def make_targets_file(d, targets):
    p = os.path.join(d, "targets.json")
    write_json(p, {"schema_version": "1.0.0", "targets": targets})
    return p


class _Base:
    def __init__(self):
        self._id = 0
        self.responses = []

    def next_id(self):
        self._id += 1
        return self._id

    def initialize(self, version="2025-06-18", complete=True):
        r = self.request("initialize", {"protocolVersion": version, "capabilities": {}, "clientInfo": {"name": "p13-test", "version": "0"}})
        if complete:
            self.initialized()
        return r

    def initialized(self):
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, name, arguments=None):
        r = self.request("tools/call", {"name": name, "arguments": {} if arguments is None else arguments})
        if "result" in r:
            res = r["result"]
            env = res.get("structuredContent")
            assert isinstance(res.get("content"), list) and res["content"][0]["type"] == "text"
            assert json.loads(res["content"][0]["text"]) == env, "text content and structuredContent must agree"
            return env, res
        return None, r

    def collect(self, collector_id, alias=PRIMARY, **extra):
        return self.call("diagnostics.collect", dict({"collector_id": collector_id, "target_alias": alias}, **extra))[0]


class ProcClient(_Base):
    def __init__(self, targets=None, fixtures=None, extra_args=(), env_extra=None):
        super().__init__()
        args = [sys.executable, "-m", "mcp_gateway"]
        if targets:
            args += ["--targets", targets]
        if fixtures:
            args += ["--fixtures-dir", fixtures]
        args += list(extra_args)
        env = dict(os.environ, PYTHONPATH=ROOT, PYTHONDONTWRITEBYTECODE="1", PYTHONUTF8="1")
        env.update(env_extra or {})
        self.p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=ROOT, env=env)
        self.stdout_lines, self._err = [], []
        self._q = queue.Queue()
        threading.Thread(target=self._pump_out, daemon=True).start()
        threading.Thread(target=self._pump_err, daemon=True).start()

    def _pump_out(self):
        for line in iter(self.p.stdout.readline, b""):
            self.stdout_lines.append(line)
            self._q.put(line)
        self._q.put(None)

    def _pump_err(self):
        for line in iter(self.p.stderr.readline, b""):
            self._err.append(line)

    @property
    def stderr_text(self):
        return b"".join(self._err).decode("utf-8", "replace")

    def send(self, obj):
        self.send_bytes(json.dumps(obj).encode("utf-8") + b"\n")

    def send_bytes(self, data):
        try:
            self.p.stdin.write(data)
            self.p.stdin.flush()
        except (BrokenPipeError, OSError):
            pass

    def recv(self, timeout=30):
        try:
            line = self._q.get(timeout=timeout)
        except queue.Empty:
            raise AssertionError("timeout waiting for a server message (INCONCLUSIVE)")
        if line is None:
            raise AssertionError("server closed stdout unexpectedly")
        return json.loads(line.decode("utf-8"))

    def request(self, method, params=None, timeout=30):
        rid = self.next_id()
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self.send(msg)
        while True:
            m = self.recv(timeout)
            if m.get("id") == rid:
                return m
            self.responses.append(m)

    def raw(self, data: bytes, timeout=30):
        """Send raw bytes (a full line is appended if missing), then a ping sentinel; return everything that
        arrived before the sentinel reply."""
        if not data.endswith(b"\n"):
            data += b"\n"
        rid = self.next_id()
        self.send_bytes(data)
        self.send({"jsonrpc": "2.0", "id": rid, "method": "ping"})
        out = []
        while True:
            m = self.recv(timeout)
            if m.get("id") == rid and "result" in m:
                return out
            out.append(m)

    def close(self, wait=15):
        try:
            self.p.stdin.close()
        except Exception:
            pass
        try:
            rc = self.p.wait(timeout=wait)
        except subprocess.TimeoutExpired:
            self.p.kill()
            rc = None
        return rc


class InProcClient(_Base):
    def __init__(self, targets=None, fixtures=None):
        super().__init__()
        from mcp_gateway.cli import build_gateway
        from mcp_gateway.server import McpServer
        self.err = io.StringIO()
        self.out = io.BytesIO()
        self.server = McpServer(build_gateway(targets, fixtures, None), out=self.out, err=self.err)
        self.stdout_lines = []
        self._pos = 0

    @property
    def stderr_text(self):
        return self.err.getvalue()

    def _drain(self):
        data = self.out.getvalue()[self._pos:]
        self._pos += len(data)
        msgs = [json.loads(l) for l in data.decode("utf-8").split("\n") if l.strip()]
        self.stdout_lines += [l.encode() for l in data.decode("utf-8").split("\n") if l.strip()]
        return msgs

    def send(self, obj):
        self.server.handle_line(json.dumps(obj).encode("utf-8"))

    def request(self, method, params=None, timeout=30):
        rid = self.next_id()
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self.server.handle_line(json.dumps(msg).encode("utf-8"))
        for m in self._drain():
            if m.get("id") == rid:
                return m
        raise AssertionError("no response")

    def raw(self, data: bytes, timeout=30):
        self._drain()
        self.server.handle_line(data.rstrip(b"\n"))
        return self._drain()

    def close(self, wait=15):
        return 0


def all_output(client) -> str:
    return b"".join(client.stdout_lines).decode("utf-8", "replace") + "\n" + client.stderr_text


def leaks(text, extra=()):
    needles = (MARKER, MARKER2, "AKIAIOSFODNN7EXAMPLE", "BEGIN PRIVATE KEY", "5f4dcc3b5aa765d61d8327deb882cf99") + tuple(extra)
    return [n for n in needles if n in text]
