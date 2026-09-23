"""
mcp_gateway_lab.profile — the private lab profile: connection coordinates, secret reference, expected identity,
limits and the human authorization for ONE non-production target.

The profile is operator configuration, never reachable from a tool call. Fail closed on anything unexpected:
  * file: absolute path, regular file, not a symlink, owned by the current user, no group/other permission bits,
    outside the repository checkout, bounded size, strict JSON (duplicate keys rejected);
  * content: exactly one target, environment_class NON_PRODUCTION, no secret-bearing key anywhere, every field
    typed and bounded, limits only LOWER than the certified query ceilings, authorization window current and at
    most 90 days long.
Errors carry fixed text only (no values from the file are echoed).
"""
from __future__ import annotations

import json
import os
import re
import stat
from datetime import datetime, timedelta, timezone

from mcp_gateway.catalog import ALIAS_RE, REPO_ROOT

MAX_PROFILE_BYTES = 65_536
MAX_AUTHORIZATION_DAYS = 90
ENVIRONMENT_CLASSES = ("NON_PRODUCTION",)
TRANSPORTS = ("tcp", "tcps")
CONTAINERS = ("NON_CDB", "CDB_ROOT", "PDB")
DATABASE_ROLES = ("PRIMARY", "PHYSICAL STANDBY", "LOGICAL STANDBY", "SNAPSHOT STANDBY")
CREDENTIAL_PROVIDERS = ("macos_keychain",)
# System privileges a diagnostic session may hold. CREATE SESSION is mandatory; SELECT ANY DICTIONARY is tolerated
# only when the profile opts in explicitly (object grants on V_$ views are the least-privilege option).
PRIVILEGE_CEILING = frozenset({"CREATE SESSION", "SELECT ANY DICTIONARY"})
# Ceilings for the profile limits. They are upper bounds only: every call still applies min(profile, certified query,
# collector) — e.g. Q-DISC-IDENTITY-001 stays at 5 rows / 4096 bytes / 10 s whatever the profile says. Raised in
# CHG-ESTACK-ORA19C-LAB-003 for multi-container CDB_* views (rows = MAX_ROWS_HARD, bytes = Q-CDB-TABLESPACES-001).
LIMIT_BOUNDS = {"connect_timeout_seconds": (1, 10), "call_timeout_ms": (500, 20_000), "max_rows": (1, 200), "max_output_bytes": (256, 65_536)}
FORBIDDEN_KEYS = frozenset({"password", "passwd", "pwd", "secret", "token", "wallet_password", "dsn", "connect_string",
                            "connection_string", "easy_connect", "private_key", "api_key"})

_HOST = re.compile(r'^(?=.{1,253}$)([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$')
_IPV6 = re.compile(r'^[0-9A-Fa-f:]{2,39}$')
_SERVICE = re.compile(r'^[A-Za-z][A-Za-z0-9_.$#-]{0,127}$')
_USER = re.compile(r'^[A-Za-z][A-Za-z0-9_$#]{0,127}$')
_DBNAME = re.compile(r'^[A-Za-z][A-Za-z0-9_$#]{0,29}$')
_KEYCHAIN = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.:/@-]{0,127}$')
_CERT_DN = re.compile(r'^[A-Za-z0-9 =,._*@-]{1,256}$')
_FREE_REF = re.compile(r'^[A-Za-z0-9][A-Za-z0-9 _.:/#()-]{0,127}$')
_TS = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')


class ProfileError(RuntimeError):
    """Fixed-text configuration error."""

    def __init__(self, reason: str = "lab profile is invalid"):
        super().__init__(reason)


def _no_dupes(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate key")
    return dict(pairs)


def _forbidden_key_anywhere(obj) -> bool:
    if isinstance(obj, dict):
        return any((isinstance(k, str) and k.lower() in FORBIDDEN_KEYS) or _forbidden_key_anywhere(v) for k, v in obj.items())
    if isinstance(obj, list):
        return any(_forbidden_key_anywhere(v) for v in obj)
    return False


def check_private_file(path: str, what: str = "lab profile") -> str:
    """Return the real path of an owner-only regular file outside the repository, or raise ProfileError."""
    if not isinstance(path, str) or not os.path.isabs(path):
        raise ProfileError(f"{what} path must be absolute")
    try:
        st = os.lstat(path)
    except OSError:
        raise ProfileError(f"{what} is not readable")
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
        raise ProfileError(f"{what} must be a regular file, not a symlink")
    if st.st_uid != os.getuid():
        raise ProfileError(f"{what} must be owned by the current user")
    if st.st_mode & 0o077:
        raise ProfileError(f"{what} must not be accessible by group or others (chmod 600)")
    if st.st_size > MAX_PROFILE_BYTES:
        raise ProfileError(f"{what} is too large")
    real = os.path.realpath(path)
    repo = os.path.realpath(REPO_ROOT)
    if real == repo or real.startswith(repo + os.sep):
        raise ProfileError(f"{what} must live outside the repository checkout")
    return real


def _parse_utc(text):
    if not isinstance(text, str) or not _TS.match(text):
        raise ProfileError("authorization timestamps must be UTC (YYYY-MM-DDTHH:MM:SSZ)")
    return datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def _require(cond, reason="lab profile is invalid"):
    if not cond:
        raise ProfileError(reason)


def _exact_keys(obj, required, optional=()):
    _require(isinstance(obj, dict) and set(required) <= set(obj) and set(obj) <= set(required) | set(optional),
             "lab profile has missing or unexpected keys")


class Authorization:
    def __init__(self, spec: dict):
        _exact_keys(spec, ("approved_by", "change_ref", "approved_at_utc", "expires_at_utc"), ("notes",))
        _require(isinstance(spec["approved_by"], str) and _FREE_REF.match(spec["approved_by"]), "authorization.approved_by is invalid")
        _require(isinstance(spec["change_ref"], str) and _FREE_REF.match(spec["change_ref"]), "authorization.change_ref is invalid")
        self.approved_by = spec["approved_by"]
        self.change_ref = spec["change_ref"]
        self.approved_at = _parse_utc(spec["approved_at_utc"])
        self.expires_at = _parse_utc(spec["expires_at_utc"])
        _require(self.expires_at > self.approved_at, "authorization window is empty")
        _require(self.expires_at - self.approved_at <= timedelta(days=MAX_AUTHORIZATION_DAYS),
                 "authorization window exceeds 90 days")

    def is_current(self, now: datetime = None) -> bool:
        now = now or datetime.now(timezone.utc)
        return self.approved_at <= now < self.expires_at


class LabTarget:
    def __init__(self, alias: str, spec: dict):
        _exact_keys(spec, ("environment_class", "connection", "credential", "expected", "allowed_system_privileges", "limits", "authorization"))
        _require(spec["environment_class"] in ENVIRONMENT_CLASSES, "only NON_PRODUCTION targets can be used by the lab launcher")
        self.alias = alias

        c = spec["connection"]
        _exact_keys(c, ("host", "port", "service_name", "transport", "username"), ("tcps",))
        _require(isinstance(c["host"], str) and (_HOST.match(c["host"]) or _IPV6.match(c["host"])), "connection.host is invalid")
        _require(isinstance(c["port"], int) and not isinstance(c["port"], bool) and 1 <= c["port"] <= 65535, "connection.port is invalid")
        _require(isinstance(c["service_name"], str) and _SERVICE.match(c["service_name"]), "connection.service_name is invalid")
        _require(c["transport"] in TRANSPORTS, "connection.transport must be tcp or tcps")
        _require(isinstance(c["username"], str) and _USER.match(c["username"]), "connection.username is invalid")
        self.host, self.port, self.service_name = c["host"], c["port"], c["service_name"]
        self.transport, self.username = c["transport"], c["username"]
        self.wallet_location = self.server_cert_dn = None
        if "tcps" in c:
            _require(self.transport == "tcps", "connection.tcps is only valid with transport tcps")
            t = c["tcps"]
            _exact_keys(t, (), ("wallet_location", "server_cert_dn"))
            if "wallet_location" in t:
                _require(isinstance(t["wallet_location"], str) and os.path.isabs(t["wallet_location"]) and os.path.isdir(t["wallet_location"]),
                         "connection.tcps.wallet_location must be an existing absolute directory")
                self.wallet_location = t["wallet_location"]
            if "server_cert_dn" in t:
                _require(isinstance(t["server_cert_dn"], str) and _CERT_DN.match(t["server_cert_dn"]), "connection.tcps.server_cert_dn is invalid")
                self.server_cert_dn = t["server_cert_dn"]

        cr = spec["credential"]
        _exact_keys(cr, ("provider", "service", "account"))
        _require(cr["provider"] in CREDENTIAL_PROVIDERS, "credential.provider is not an approved secret store")
        _require(isinstance(cr["service"], str) and _KEYCHAIN.match(cr["service"]) and isinstance(cr["account"], str) and _KEYCHAIN.match(cr["account"]),
                 "credential reference is invalid")
        self.credential = {"provider": cr["provider"], "service": cr["service"], "account": cr["account"]}

        e = spec["expected"]
        _exact_keys(e, ("oracle_version_family", "database_role", "container", "db_name"), ("con_name", "service_name"))
        _require(e["oracle_version_family"] == "19c", "expected.oracle_version_family must be 19c for this lab adapter")
        _require(e["database_role"] in DATABASE_ROLES, "expected.database_role is invalid")
        _require(e["container"] in CONTAINERS, "expected.container is invalid")
        _require(isinstance(e["db_name"], str) and _DBNAME.match(e["db_name"]), "expected.db_name is invalid")
        if e["container"] == "PDB":
            _require(isinstance(e.get("con_name"), str) and _DBNAME.match(e["con_name"]), "expected.con_name is required for a PDB")
        elif "con_name" in e:
            _require(isinstance(e["con_name"], str) and _SERVICE.match(e["con_name"]), "expected.con_name is invalid")
        if "service_name" in e:
            _require(isinstance(e["service_name"], str) and _SERVICE.match(e["service_name"]), "expected.service_name is invalid")
        self.expected_version_family = e["oracle_version_family"]
        self.expected_role = e["database_role"]
        self.expected_container = e["container"]
        self.expected_db_name = e["db_name"].upper()
        self.expected_con_name = e["con_name"].upper() if e.get("con_name") else ("CDB$ROOT" if e["container"] == "CDB_ROOT" else None)
        self.expected_service_name = (e.get("service_name") or self.service_name).upper()

        p = spec["allowed_system_privileges"]
        _require(isinstance(p, list) and all(isinstance(x, str) for x in p) and "CREATE SESSION" in p and set(p) <= PRIVILEGE_CEILING
                 and len(p) == len(set(p)), "allowed_system_privileges must include CREATE SESSION and stay within the ceiling")
        self.allowed_system_privileges = frozenset(p)

        lim = spec["limits"]
        _exact_keys(lim, tuple(LIMIT_BOUNDS))
        for k, (lo, hi) in LIMIT_BOUNDS.items():
            v = lim[k]
            _require(isinstance(v, int) and not isinstance(v, bool) and lo <= v <= hi, f"limits.{k} is outside its bounds")
        self.limits = dict(lim)

        self.authorization = Authorization(spec["authorization"])

    def gateway_role(self) -> str:
        return "PRIMARY" if self.expected_role == "PRIMARY" else "STANDBY"


class LabProfile:
    def __init__(self, doc: dict):
        _exact_keys(doc, ("schema_version", "profile_id", "targets"), ("description",))
        _require(doc["schema_version"] == "1.0.0", "unsupported lab profile schema_version")
        _require(isinstance(doc["profile_id"], str) and _FREE_REF.match(doc["profile_id"]), "profile_id is invalid")
        _require(not _forbidden_key_anywhere(doc), "lab profile must not contain secrets or connect strings")
        targets = doc["targets"]
        _require(isinstance(targets, dict) and len(targets) == 1, "the lab profile must name exactly one target")
        (alias, spec), = targets.items()
        _require(isinstance(alias, str) and ALIAS_RE.match(alias), "target alias is invalid")
        self.profile_id = doc["profile_id"]
        self.target = LabTarget(alias, spec)

    def get(self, alias: str) -> LabTarget:
        return self.target if alias == self.target.alias else None


def load_profile(path: str, now: datetime = None) -> LabProfile:
    real = check_private_file(path)
    try:
        with open(real, encoding="utf-8") as f:
            doc = json.load(f, object_pairs_hook=_no_dupes)
    except (OSError, ValueError):
        raise ProfileError("lab profile is not valid JSON")
    prof = LabProfile(doc)
    if not prof.target.authorization.is_current(now):
        raise ProfileError("human authorization for the lab target is missing or expired")
    return prof
