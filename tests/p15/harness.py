"""
tests/p15/harness.py — fakes and builders for the LAB oracle_sql adapter tests (CHG-ESTACK-ORA19C-LAB-001, CHG-ESTACK-ORA19C-LAB-002).

Nothing here touches Oracle, the network, the Keychain or the host: the python-oracledb driver and the
`/usr/bin/security` runner are replaced by in-process fakes that RECORD what the adapter asked for (connect
parameters without the password, every SQL statement, commits, rollbacks, closes, fetch sizes).
"""
import copy
import json
import os
import stat
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone

from tests.p13.harness import MARKER, ROOT, Skip, run_all, test, tmpdir  # noqa: F401  (re-exported for the checks)

import functools

# CHG-ESTACK-PORTABILITY-001: the lab launcher refuses non-POSIX hosts by design (owner-only profile checks, macOS
# Keychain). Cases that build a lab gateway or rely on POSIX file permissions are reported as an explicit [SKIP] there,
# never as a silent PASS; platform-agnostic cases (static scans, SQL source resolution, refusal paths) always run.
POSIX_HOST = hasattr(os, "getuid") and os.name == "posix"


def posix_test(fn):
    @functools.wraps(fn)
    def wrapper():
        if not POSIX_HOST:
            raise Skip("requires a POSIX host: the lab launcher refuses non-POSIX hosts by design")
        return fn()
    return test(wrapper)


# CHG-ESTACK-CI-MATRIX-001: cases that start the real lab CLI in a subprocess with the default profile (credential
# provider `macos_keychain`, no injected runner). Off macOS the launcher refuses that provider at startup by design,
# so they are an explicit [SKIP] there; the refusal itself is covered on every platform in check_lab_security.
MACOS_HOST = POSIX_HOST and sys.platform == "darwin"


def macos_test(fn):
    @functools.wraps(fn)
    def wrapper():
        if not MACOS_HOST:
            raise Skip("requires macOS: the default lab profile uses the macos_keychain provider, refused elsewhere by design")
        return fn()
    return test(wrapper)

ALIAS = "lab-ol8-19c"
SECRET = "Lab-" + MARKER + "-pw"                      # the fake Keychain password; must never appear in any output
RAW_NAMES = ("LAB19C", "LABCDB", "LABPDB1", "ESTACK_DIAG", "db19-lab.example.internal", "fast_recovery_area", "APP_DATA")
FAKEDRIVER_DIR = os.path.join(ROOT, "tests", "p15", "fakedriver")


def utc(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def profile_doc(**over):
    now = datetime.now(timezone.utc)
    t = {
        "environment_class": "NON_PRODUCTION",
        "connection": {"host": "db19-lab.example.internal", "port": 1521, "service_name": "LAB19C", "transport": "tcp", "username": "ESTACK_DIAG"},
        "credential": {"provider": "macos_keychain", "service": "oracle-estack-lab", "account": ALIAS},
        "expected": {"oracle_version_family": "19c", "database_role": "PRIMARY", "container": "NON_CDB", "db_name": "LAB19C"},
        "allowed_system_privileges": ["CREATE SESSION"],
        "limits": {"connect_timeout_seconds": 5, "call_timeout_ms": 8000, "max_rows": 5, "max_output_bytes": 4096},
        "authorization": {"approved_by": "DBA lead (lab)", "change_ref": "CHG-ESTACK-ORA19C-LAB-001",
                          "approved_at_utc": utc(now - timedelta(days=1)), "expires_at_utc": utc(now + timedelta(days=6))},
    }
    for path, value in over.items():                   # "connection.port" -> t["connection"]["port"]
        node = t
        keys = path.split(".")
        for k in keys[:-1]:
            node = node[k]
        if value is _DELETE:
            node.pop(keys[-1], None)
        else:
            node[keys[-1]] = value
    return {"schema_version": "1.0.0", "profile_id": "LAB-OL8-19C-TEST", "targets": {ALIAS: t}}


_DELETE = object()
DELETE = _DELETE


def lab_target(**over):
    t = {"alias": ALIAS, "adapter": "oracle_sql", "enabled": True, "oracle_version": "19c", "role": "PRIMARY", "container": "NON_CDB",
         "architecture": {"rac": False, "dataguard": False, "asm": False}, "license_status": {},
         "allowed_collectors": ["Q-DISC-IDENTITY-001"], "budget": {"max_calls": 20, "max_rows": 50}}
    t.update(over)
    return t


def write_private(d, name, doc, mode=0o600, raw=None):
    p = os.path.join(d, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(raw if raw is not None else json.dumps(doc))
    os.chmod(p, mode)
    return p


def write_targets(d, targets):
    return write_private(d, "targets.lab.json", {"schema_version": "1.0.0", "targets": targets}, mode=0o644)


# --- fake python-oracledb ---------------------------------------------------------------------------

class FakeDbError(Exception):
    pass


class _ErrInfo:
    def __init__(self, code, message):
        self.full_code = code
        self.message = message


def driver_error(code, message="ORA failure mentioning " + SECRET + " at db19-lab.example.internal:1521/LAB19C"):
    return FakeDbError(_ErrInfo(code, message))


class Scenario:
    def __init__(self, **kw):
        self.thin_mode = True
        self.conn_thin = True
        self.connect_error = None
        self.session = {"service_name": "LAB19C", "con_name": "LAB19C", "sess_user": "ESTACK_DIAG", "isdba": "FALSE"}
        self.privileges = ["CREATE SESSION"]
        self.identity = [{"instance_name": "LAB19C", "version_full": "19.27.0.0.0", "db_name": "LAB19C",
                          "database_role": "PRIMARY", "cdb": "NO", "open_mode": "READ WRITE"}]
        self.identity_delay = 0.0
        self.identity_error = None
        # V$RESOURCE_LIMIT.LIMIT_VALUE and V$PARAMETER.VALUE are padded VARCHAR2 in Oracle; the fake reproduces that.
        self.resource_limits = [
            {"resource_name": "dml_locks", "current_utilization": 0, "max_utilization": 12, "limit_value": " UNLIMITED"},
            {"resource_name": "enqueue_locks", "current_utilization": 31, "max_utilization": 64, "limit_value": "      4340"},
            {"resource_name": "processes", "current_utilization": 71, "max_utilization": 96, "limit_value": "       320"},
            {"resource_name": "sessions", "current_utilization": 84, "max_utilization": 110, "limit_value": "       504"}]
        self.processes = [{"process_count": 71, "processes_limit": "320"}]
        self.main_error = None                       # raised by any non-identity certified query (e.g. ORA-00942)
        # CHG-ESTACK-ORA19C-LAB-003: CDB_* rows per PDB (con_id > 1) and FRA usage with the (undeclared) destination path.
        self.tablespaces = [
            {"con_id": 3, "tablespace_name": "SYSTEM", "used_percent": 1.87, "used_space": 62400, "tablespace_size": 4194302,
             "status": "ONLINE", "contents": "PERMANENT", "autoextend": "YES"},
            {"con_id": 3, "tablespace_name": "APP_DATA_LABPDB1", "used_percent": 91.4, "used_space": 958464, "tablespace_size": 1048576,
             "status": "ONLINE", "contents": "PERMANENT", "autoextend": "NO"},
            {"con_id": 3, "tablespace_name": "UNDOTBS1", "used_percent": 0.2, "used_space": 8192, "tablespace_size": 4194302,
             "status": "ONLINE", "contents": "UNDO", "autoextend": "NO"}]
        self.temp = [{"con_id": 3, "tablespace_name": "TEMP", "allocated_bytes": 36700160, "bytes_used": 2097152, "bytes_free": 34603008}]
        # CHG-ESTACK-ORA19C-LAB-004: ages come already computed by the database (NUMBER), never as DATE.
        self.freshness = [
            {"backup_kind": "FULL_OR_LEVEL0", "record_count": 6, "hours_since_last": 180.5},
            {"backup_kind": "INCREMENTAL", "record_count": 0, "hours_since_last": None},
            {"backup_kind": "ARCHIVELOG", "record_count": 4, "hours_since_last": 26.75},
            {"backup_kind": "CONTROLFILE", "record_count": 1, "hours_since_last": 180.4},
            {"backup_kind": "SPFILE", "record_count": 1, "hours_since_last": 180.4}]
        self.jobs = [
            {"input_type": "DB FULL", "jobs_total": 2, "last_status": "COMPLETED", "hours_since_last_start": 181.0,
             "hours_since_last_success": 180.5, "failed_last_7d": 0, "last_elapsed_seconds": 612},
            {"input_type": "ARCHIVELOG", "jobs_total": 3, "last_status": "FAILED", "hours_since_last_start": 2.5,
             "hours_since_last_success": 26.75, "failed_last_7d": 1, "last_elapsed_seconds": 14}]
        self.fra = [
            {"file_type": "ARCHIVED LOG", "percent_space_used": 42.5, "percent_space_reclaimable": 30.1, "number_of_files": 118,
             "dest_name": "/u01/app/oracle/fast_recovery_area/LABCDB", "space_limit": 21474836480, "space_used": 10307921510,
             "space_reclaimable": 6979321856, "dest_files": 131},
            {"file_type": "BACKUP PIECE", "percent_space_used": 5.5, "percent_space_reclaimable": 0, "number_of_files": 13,
             "dest_name": "/u01/app/oracle/fast_recovery_area/LABCDB", "space_limit": 21474836480, "space_used": 10307921510,
             "space_reclaimable": 6979321856, "dest_files": 131}]
        for k, v in kw.items():
            if k.startswith("session_"):
                self.session[k[len("session_"):]] = v
            elif k.startswith("id_"):
                self.identity = [dict(r, **{k[len("id_"):]: v}) for r in self.identity]
            else:
                setattr(self, k, v)


class FakeDriver:
    def __init__(self, scenario=None):
        self.s = scenario or Scenario()
        self.lock = threading.Lock()
        self.connects = []            # connect kwargs WITHOUT the password
        self.password_ok = []         # whether the password handed to connect was the Keychain value
        self.statements = []
        self.fetch_sizes = []
        self.events = []              # commit / rollback / close

    def is_thin_mode(self):
        return self.s.thin_mode

    def connect(self, **kw):
        with self.lock:
            self.password_ok.append(kw.get("password") == SECRET)
            self.connects.append({k: v for k, v in kw.items() if k != "password"})
        if self.s.connect_error is not None:
            raise self.s.connect_error
        return FakeConnection(self)


class FakeConnection:
    def __init__(self, drv):
        self.drv = drv
        self.thin = drv.s.conn_thin
        self.autocommit = True
        self.module = self.action = None
        self.call_timeout = 0
        self.call_timeouts = []

    def __setattr__(self, k, v):
        if k == "call_timeout" and hasattr(self, "call_timeouts"):
            self.call_timeouts.append(v)
        object.__setattr__(self, k, v)

    def cursor(self):
        return FakeCursor(self)

    def commit(self):
        self.drv.events.append("commit")

    def rollback(self):
        self.drv.events.append("rollback")

    def close(self):
        self.drv.events.append("close")


class FakeCursor:
    def __init__(self, conn):
        self.conn = conn
        self.drv = conn.drv
        self.description = None
        self._rows = []
        self.arraysize = 100
        self.prefetchrows = 2

    def execute(self, sql, *args, **kw):
        assert not args and not kw, "the adapter must never bind client values"
        self.drv.statements.append(sql)
        s = self.drv.s
        low = sql.lower()
        if sql == "SET TRANSACTION READ ONLY":
            return
        if "sys_context" in low:
            self._set([s.session])
        elif "session_privs" in low:
            self._set([{"privilege": p} for p in s.privileges])
        elif "v$instance" in low:
            if s.identity_delay:
                time.sleep(s.identity_delay)
            if s.identity_error is not None:
                raise s.identity_error
            self._set(s.identity)
        elif any(v in low for v in ("v$resource_limit", "v$process", "cdb_tablespace_usage_metrics", "cdb_temp_files",
                                     "v$flash_recovery_area_usage", "v$backup_datafile", "v$rman_backup_job_details")):
            if s.main_error is not None:
                raise s.main_error
            self._set(s.resource_limits if "v$resource_limit" in low else s.processes if "v$process" in low
                      else s.tablespaces if "cdb_tablespace_usage_metrics" in low else s.temp if "cdb_temp_files" in low
                      else s.freshness if "v$backup_datafile" in low else s.jobs if "v$rman_backup_job_details" in low else s.fra)
        else:
            raise driver_error("ORA-00900", "invalid SQL statement")

    def _set(self, rows):
        cols = list(rows[0]) if rows else ["x"]
        self.description = [(c.upper(), None) for c in cols]
        self._rows = [tuple(r.get(c) for c in cols) for r in rows]

    def fetchmany(self, n):
        self.drv.fetch_sizes.append(n)
        return self._rows[:n]

    def close(self):
        pass


class FakeKeychain:
    def __init__(self, rc=0, out=None):
        self.rc = rc
        self.out = (SECRET + "\n").encode() if out is None else out
        self.calls = []

    def __call__(self, argv, **kw):
        self.calls.append((list(argv), dict(kw)))
        return subprocess.CompletedProcess(argv, self.rc, stdout=self.out if self.rc == 0 else b"", stderr=b"")


# --- builders ---------------------------------------------------------------------------------------

class Lab:
    """A lab gateway wired to fakes, built through the real mcp_gateway_lab.cli.build_lab_gateway."""

    def __init__(self, d, scenario=None, profile=None, targets=None, keychain=None, wallclock=None, operation_timeout=None):
        from mcp_gateway_lab.cli import build_lab_gateway
        self.driver = FakeDriver(scenario)
        self.keychain = keychain or FakeKeychain()
        self.audit_lines = []
        self.profile_path = write_private(d, "lab-profile.json", profile or profile_doc())
        self.targets_path = write_targets(d, targets or [lab_target()])
        self.gateway, self.adapter = build_lab_gateway(self.targets_path, self.profile_path, self.audit_lines.append, driver=self.driver,
                                                       credential_runner=self.keychain, wallclock=wallclock)
        if operation_timeout is not None:
            self.gateway.operation_timeout = operation_timeout
        from mcp_gateway.gateway import Session
        self.session = Session()

    def call(self, tool, args):
        return self.gateway.call(self.session, tool, args)

    def collect(self, collector_id="Q-DISC-IDENTITY-001", **extra):
        return self.call("diagnostics.collect", dict({"collector_id": collector_id, "target_alias": ALIAS}, **extra))


def leaks(text: str) -> list:
    """Raw identifiers, host, user or the secret found in `text` (case-insensitive for names)."""
    found = [SECRET] if SECRET in text or MARKER in text else []
    low = text.lower()
    return found + [n for n in RAW_NAMES if n.lower() in low]


def run_lab_cli(*args, env_extra=None, fake_driver=True):
    env = {"PATH": "/usr/bin:/bin", "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUTF8": "1",
           "PYTHONPATH": os.pathsep.join(([FAKEDRIVER_DIR] if fake_driver else []) + [ROOT])}
    env.update(env_extra or {})
    p = subprocess.run([sys.executable, "-m", "mcp_gateway_lab", *args], capture_output=True, text=True, encoding="utf-8", cwd=ROOT,
                       env=env, stdin=subprocess.DEVNULL, timeout=60)
    return p.returncode, p.stdout, p.stderr


def deepcopy(x):
    return copy.deepcopy(x)


def is_private(path):
    return not (os.stat(path).st_mode & (stat.S_IRWXG | stat.S_IRWXO))
