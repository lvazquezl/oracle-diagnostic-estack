"""
mcp_gateway_lab.oracle_sql — the real, read-only `oracle_sql` adapter (python-oracledb, THIN mode only).

It implements the gateway adapter interface (`name`, `status`, `fetch(target, collector, params)`) and returns
UNTRUSTED rows that the gateway then validates and sanitizes (mcp_gateway.evidence.sanitize_rows). Per call:

  1. authorization  the target is the one lab target of the profile, its human authorization is current, the
                    collector is one this adapter implements, and the registered target agrees with the profile;
  2. concurrency    one operation at a time (non-blocking lock). A call abandoned by the gateway deadline keeps
                    the lock until the driver returns (bounded by call_timeout), so calls never pile up;
  3. SQL source     certified variant re-read and hash-verified (sqlsource.resolve); guard statements below are
                    fixed constants checked by the same read-only guard; there is no other SQL;
  4. connection     fresh THIN connection, password fetched from the approved secret store just for connect,
                    no retries, bounded connect timeout, call_timeout per round trip under one overall deadline;
  5. session guard  SET TRANSACTION READ ONLY; the session must not be SYSDBA-like, must be the configured
                    dedicated user (not an Oracle-maintained account) and hold no system privilege above the
                    profile's allowance (ceiling CREATE SESSION / SELECT ANY DICTIONARY);
  6. identity       the certified identity query must show the authorized version family, database role,
                    container, database name and service BEFORE any evidence is returned;
  7. limits         fetchmany(max_rows + 1) (truncation is detected, never silent), scalar types only, bounded
                    value length and total bytes;
  8. teardown       rollback + close in `finally` — nothing is ever committed, no connection outlives the call.

Failures surface as fixed GatewayError codes. A coarse failure category (fixed enum, never a driver message) is
kept in `last_failure` for the human-run `python -m mcp_gateway_lab check` only.
"""
from __future__ import annotations

import json
import re
import threading
import time

from mcp_gateway.catalog import assert_read_only_sql
from mcp_gateway.common import AdapterStatus, GatewayError
from mcp_gateway.versions import family_of

from . import sqlsource
from .credentials import CredentialError, provider_for

IDENTITY_COLLECTOR = "Q-DISC-IDENTITY-001"
# collector id -> column aliases (driver column name, lower-cased -> catalog output field).
# Only R0 views with object grants (CHG-ESTACK-ORA19C-LAB-002, -003); every other collector stays refused.
# Columns the catalog does not declare (FRA dest_name path, tablespace autoextend) are dropped here, at the source.
SUPPORTED_COLLECTORS = {
    IDENTITY_COLLECTOR: {"version_full": "version"},
    "Q-ORA-RESOURCE-LIMITS-001": {},
    "Q-CDB-TABLESPACES-001": {},
    "Q-RMAN-FRA-USAGE-001": {},
    # Q-CDB-TEMP-001 deliberately absent: validated in the lab, its GV$TEMP_SPACE_HEADER join returns no usage from CDB$ROOT.
}

GUARD_SESSION_SQL = ("SELECT SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS service_name, "
                     "SYS_CONTEXT('USERENV', 'CON_NAME') AS con_name, "
                     "SYS_CONTEXT('USERENV', 'SESSION_USER') AS sess_user, "
                     "SYS_CONTEXT('USERENV', 'ISDBA') AS isdba "
                     "FROM dual")
GUARD_PRIVILEGES_SQL = "SELECT privilege FROM session_privs"
READ_ONLY_TRANSACTION = "SET TRANSACTION READ ONLY"
for _stmt in (GUARD_SESSION_SQL, GUARD_PRIVILEGES_SQL):
    assert_read_only_sql(_stmt)                                   # import-time: the guards obey the same rule

_DIGITS = re.compile(r'^[0-9]{1,15}$')
MAX_PRIVILEGE_ROWS = 64
MAX_VALUE_CHARS = 256
PRIVILEGED_USERS = frozenset({"SYS", "SYSTEM", "SYSBACKUP", "SYSDG", "SYSKM", "SYSRAC", "SYSMAN", "DBSNMP", "AUDSYS", "OUTLN",
                              "GSMADMIN_INTERNAL", "XDB", "CTXSYS", "MDSYS", "ORDSYS", "WMSYS", "LBACSYS", "DVSYS", "OJVMSYS",
                              "ORACLE_OCM", "APPQOSSYS", "DBSFWUSER", "GGSYS", "ANONYMOUS"})
_ROLE_FAMILY = {"PRIMARY": "PRIMARY", "PHYSICAL STANDBY": "STANDBY", "LOGICAL STANDBY": "STANDBY", "SNAPSHOT STANDBY": "STANDBY"}

# driver error code -> coarse category (for the human `check` command only; never sent to the model)
_DRIVER_CATEGORIES = {"ORA-01017": "CREDENTIALS_REJECTED", "ORA-28000": "ACCOUNT_LOCKED", "ORA-28001": "PASSWORD_EXPIRED",
                      "ORA-12514": "SERVICE_NOT_REGISTERED", "DPY-6001": "SERVICE_NOT_REGISTERED", "ORA-12541": "NO_LISTENER",
                      "DPY-6005": "NETWORK_UNREACHABLE", "ORA-12170": "NETWORK_TIMEOUT", "DPY-3001": "NATIVE_NETWORK_ENCRYPTION_NEEDS_THICK_MODE",
                      "ORA-00942": "MISSING_OBJECT_PRIVILEGE", "ORA-01031": "INSUFFICIENT_PRIVILEGES", "DPY-4024": "CALL_TIMEOUT",
                      "DPY-4011": "CONNECTION_CLOSED", "ORA-01035": "RESTRICTED_SESSION"}


class _Fail(Exception):
    def __init__(self, code: str, category: str):
        super().__init__(category)
        self.code, self.category = code, category


def _driver_category(exc) -> str:
    err = exc.args[0] if getattr(exc, "args", None) else None
    code = getattr(err, "full_code", None)
    if isinstance(code, str) and code in _DRIVER_CATEGORIES:
        return _DRIVER_CATEGORIES[code]
    if isinstance(code, str) and code.startswith("DPY-6"):
        return "NETWORK_OR_LISTENER"
    return "DRIVER_ERROR"


class OracleSqlAdapter:
    name = "oracle_sql"
    status = AdapterStatus.LAB_ENABLED
    implemented_collectors = frozenset(SUPPORTED_COLLECTORS)      # read by the gateway to report per-collector status

    def __init__(self, profile, driver, identity_collector, credential_runner=None, clock=time.monotonic, wallclock=None):
        if identity_collector.collector_id != IDENTITY_COLLECTOR:
            raise RuntimeError("identity collector is required")
        self._identity = identity_collector
        self._profile = profile
        self._driver = driver
        self._credentials = provider_for(profile.target.credential["provider"], credential_runner)
        self._lock = threading.Lock()
        self._clock = clock
        self._wallclock = wallclock
        self.last_failure = None

    # -- helpers -------------------------------------------------------------------------------------
    def _deadline_ms(self, deadline: float, cap_ms: int) -> int:
        remaining = int((deadline - self._clock()) * 1000)
        if remaining < 200:
            raise _Fail("E_TIMEOUT", "DEADLINE")
        return max(200, min(cap_ms, remaining))

    def _query(self, conn, sql: str, max_rows: int, deadline: float, cap_ms: int):
        conn.call_timeout = self._deadline_ms(deadline, cap_ms)
        cur = conn.cursor()
        try:
            cur.arraysize = max_rows + 1
            cur.prefetchrows = max_rows + 1
            cur.execute(sql)
            cols = [str(d[0]).lower() for d in (cur.description or [])]
            fetched = cur.fetchmany(max_rows + 1)
        finally:
            try:
                cur.close()
            except Exception:
                pass
        rows = []
        for r in fetched:
            if len(r) != len(cols):
                raise _Fail("E_RESULT_INVALID", "RESULT_SHAPE_REFUSED")
            row = {}
            for c, v in zip(cols, r):
                if v is not None and (isinstance(v, bool) or not isinstance(v, (str, int, float))):
                    raise _Fail("E_RESULT_INVALID", "RESULT_TYPE_REFUSED")        # LOB, bytes, dates, objects: refused
                if isinstance(v, str) and len(v) > MAX_VALUE_CHARS:
                    raise _Fail("E_RESULT_INVALID", "RESULT_VALUE_TOO_LONG")
                row[c] = v
            rows.append(row)
        return rows

    def _check_target(self, target, spec):
        """The registered target (gateway catalog) must agree with the private profile."""
        if target.oracle_version != spec.expected_version_family or target.role != spec.gateway_role() \
                or target.container != spec.expected_container:
            raise _Fail("E_TARGET_MISMATCH", "TARGET_REGISTRATION_MISMATCH")

    def _check_session(self, conn, spec, deadline):
        cap = spec.limits["call_timeout_ms"]
        rows = self._query(conn, GUARD_SESSION_SQL, 1, deadline, cap)
        if len(rows) != 1:
            raise _Fail("E_TARGET_MISMATCH", "SESSION_CONTEXT_UNAVAILABLE")
        s = rows[0]
        user = str(s.get("sess_user") or "").upper()
        if str(s.get("isdba") or "").upper() != "FALSE" or user in PRIVILEGED_USERS:
            raise _Fail("E_PRIVILEGES_EXCESSIVE", "PRIVILEGED_SESSION")
        if user != spec.username.upper():
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_SESSION_USER")
        if str(s.get("service_name") or "").upper() != spec.expected_service_name:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_SERVICE_NAME")
        privs = self._query(conn, GUARD_PRIVILEGES_SQL, MAX_PRIVILEGE_ROWS, deadline, cap)
        held = {str(r.get("privilege") or "").upper() for r in privs}
        if len(privs) > MAX_PRIVILEGE_ROWS or not held <= spec.allowed_system_privileges:
            raise _Fail("E_PRIVILEGES_EXCESSIVE", "EXCESSIVE_SYSTEM_PRIVILEGES")
        return str(s.get("con_name") or "").upper()

    def _check_identity(self, rows, spec, target, con_name):
        if len(rows) != 1:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_IDENTITY_ROW_COUNT")
        r = rows[0]
        version = r.get("version_full", r.get("version"))
        if family_of(version) != spec.expected_version_family or family_of(version) != target.oracle_version:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_VERSION")
        role = r.get("database_role")
        if role != spec.expected_role or _ROLE_FAMILY.get(role) != target.role:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_ROLE")
        cdb = r.get("cdb")
        container = "NON_CDB" if cdb == "NO" else ("CDB_ROOT" if con_name == "CDB$ROOT" else "PDB") if cdb == "YES" else None
        if container != spec.expected_container:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_CONTAINER")
        if spec.expected_con_name is not None and con_name != spec.expected_con_name:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_CONTAINER_NAME")
        if str(r.get("db_name") or "").upper() != spec.expected_db_name:
            raise _Fail("E_TARGET_MISMATCH", "MISMATCH_DB_NAME")
        return version

    def _connect(self, spec):
        try:
            password = self._credentials.get_password(spec.credential["service"], spec.credential["account"])
        except CredentialError:
            raise _Fail("E_ADAPTER_FAILED", "CREDENTIAL_UNAVAILABLE")
        kwargs = {"user": spec.username, "password": password, "host": spec.host, "port": spec.port,
                  "service_name": spec.service_name, "protocol": spec.transport,
                  "tcp_connect_timeout": float(spec.limits["connect_timeout_seconds"]), "retry_count": 0, "retry_delay": 0,
                  "program": "estack-diag-lab"}
        if spec.transport == "tcps":
            kwargs["ssl_server_dn_match"] = True
            if spec.wallet_location:
                kwargs["wallet_location"] = spec.wallet_location
            if spec.server_cert_dn:
                kwargs["ssl_server_cert_dn"] = spec.server_cert_dn
        try:
            return self._driver.connect(**kwargs)
        except Exception as e:
            raise _Fail("E_ADAPTER_FAILED", _driver_category(e))
        finally:
            password = None
            kwargs.clear()

    # -- adapter interface -------------------------------------------------------------------------------
    def row_cap(self, target, collector) -> int:
        """Rows this adapter may return for (target, collector): min(profile, collector). The certified query's max_rows is
        never lower (catalog load enforces row_limit <= query max_rows). _query fetches one extra row so the gateway can
        report truncation instead of silently returning a partial set."""
        spec = self._profile.get(target.alias)
        return min(spec.limits["max_rows"], collector.row_limit) if spec is not None else 0

    def fetch(self, target, collector, params: dict):
        self.last_failure = None
        try:
            return self._fetch(target, collector)
        except _Fail as f:
            self.last_failure = f.category
            raise GatewayError(f.code)

    def _fetch(self, target, collector):
        spec = self._profile.get(target.alias)
        if spec is None:
            raise _Fail("E_TARGET_DISABLED", "TARGET_NOT_IN_PROFILE")
        if not spec.authorization.is_current(self._wallclock() if self._wallclock else None):
            raise _Fail("E_AUTHORIZATION_EXPIRED", "AUTHORIZATION_EXPIRED")
        if collector.collector_id not in SUPPORTED_COLLECTORS:
            raise _Fail("E_COLLECTOR_NOT_ALLOWED", "COLLECTOR_NOT_IMPLEMENTED")
        self._check_target(target, spec)
        if not self._lock.acquire(blocking=False):
            raise _Fail("E_BUSY", "BUSY")
        try:
            return self._collect(target, collector, spec)
        finally:
            self._lock.release()

    def _collect(self, target, collector, spec):
        family_version = target.oracle_version[:-1] + ".0"            # '19c' -> '19.0' (variant pre-selection)
        try:
            identity = sqlsource.resolve(self._identity, family_version)
            main = identity if collector.collector_id == IDENTITY_COLLECTOR else sqlsource.resolve(collector, family_version)
        except sqlsource.SqlSourceError:
            raise _Fail("E_ADAPTER_FAILED", "SQL_SOURCE_REFUSED")
        max_rows = min(spec.limits["max_rows"], main.max_rows, collector.row_limit)
        max_bytes = min(spec.limits["max_output_bytes"], main.max_output_bytes)
        deadline = self._clock() + max(1.0, min(main.timeout_seconds, collector.timeout_seconds) - 0.5)
        if hasattr(self._driver, "is_thin_mode") and not self._driver.is_thin_mode():
            raise _Fail("E_ADAPTER_FAILED", "THICK_MODE_REFUSED")
        conn = self._connect(spec)
        try:
            if getattr(conn, "thin", True) is not True:
                raise _Fail("E_ADAPTER_FAILED", "THICK_MODE_REFUSED")
            conn.autocommit = False
            conn.module = "estack-diag-lab"
            conn.action = collector.collector_id[:32]
            conn.call_timeout = self._deadline_ms(deadline, spec.limits["call_timeout_ms"])
            cur = conn.cursor()
            try:
                cur.execute(READ_ONLY_TRANSACTION)
            finally:
                cur.close()
            con_name = self._check_session(conn, spec, deadline)
            id_rows = self._query(conn, identity.sql, 1, deadline, spec.limits["call_timeout_ms"])
            self._check_identity(id_rows, spec, target, con_name)
            rows = id_rows if main is identity else self._query(conn, main.sql, max_rows, deadline, spec.limits["call_timeout_ms"])
        except _Fail:
            raise
        except Exception as e:                                   # driver/network errors: category only, never the message
            raise _Fail("E_ADAPTER_FAILED", _driver_category(e))
        finally:
            try:
                conn.rollback()                                  # nothing is ever committed
            except Exception:
                pass
            try:
                conn.close()
            except Exception:
                pass
        out = self._minimize(rows, collector)
        if len(json.dumps(out, ensure_ascii=True).encode("utf-8")) > max_bytes:
            raise _Fail("E_OUTPUT_TOO_LARGE", "OUTPUT_TOO_LARGE")
        return out

    @staticmethod
    def _typed(value, field):
        """Oracle returns some numeric facts as padded VARCHAR2 (V$RESOURCE_LIMIT.LIMIT_VALUE, V$PARAMETER.VALUE).
        For fields the catalog declares integer/integer_or_unlimited, a plain digit string becomes an int and
        'UNLIMITED' is normalized; anything else is passed through unchanged so the sanitizer drops it."""
        if not isinstance(value, str) or field.get("type") not in ("integer", "integer_or_unlimited"):
            return value
        text = value.strip()
        if _DIGITS.match(text):
            return int(text)
        if field["type"] == "integer_or_unlimited" and text.upper() == "UNLIMITED":
            return "UNLIMITED"
        return value

    @staticmethod
    def _minimize(rows, collector):
        """Rename driver columns to catalog fields and drop everything the catalog does not declare (and NULLs)."""
        aliases = SUPPORTED_COLLECTORS[collector.collector_id]
        out = []
        for r in rows:
            row = {}
            for k, v in r.items():
                k = aliases.get(k, k)
                if k in collector.output_fields and v is not None:
                    row[k] = OracleSqlAdapter._typed(v, collector.output_fields[k])
            out.append(row)
        return out
