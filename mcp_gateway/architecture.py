"""CHG-ESTACK-DISC-ARCHITECTURE-001 — observed architecture from Q-DISC-ARCHITECTURE-001, compared with the target.

The collector returns one row of aggregated facts (counts, a parameter flag, the database role, Oracle's platform
name). This module derives the context dimensions used by field validation and compares them with what the target
declares. Observed values win for field validation in the same session; every disagreement with the declaration is
reported (DECLARED_ARCHITECTURE_MISMATCH), never silently corrected in the target file.
"""

COLLECTOR_ID = "Q-DISC-ARCHITECTURE-001"
_OS_FAMILIES = (("linux", "LINUX"), ("aix", "AIX"), ("solaris", "SOLARIS"), ("hp-ux", "HPUX"), ("hp ", "HPUX"),
                ("windows", "WINDOWS"), ("mac os", "MACOS"), ("vms", "OPENVMS"))


def _os_family(platform_name):
    low = (platform_name or "").lower()
    for key, fam in _OS_FAMILIES:
        if key in low:
            return fam
    return None


def derive(rows) -> dict:
    """Observed dimensions from the sanitized row. A dimension whose facts were dropped/invalid is None (unknown)."""
    r = rows[0] if isinstance(rows, list) and len(rows) == 1 and isinstance(rows[0], dict) else {}

    def num(k):
        v = r.get(k)
        return v if isinstance(v, int) and not isinstance(v, bool) else None

    inst, cdb_flag = num("instance_count"), r.get("cluster_database")
    rac = None
    if inst is not None or cdb_flag in ("TRUE", "FALSE"):
        rac = bool((inst or 0) > 1 or cdb_flag == "TRUE")
    in_asm = num("datafiles_in_asm")
    asm = None if in_asm is None else in_asm > 0
    role_raw, dests = r.get("database_role"), num("standby_destinations")
    role = None if not role_raw else ("PRIMARY" if role_raw == "PRIMARY" else "STANDBY")
    dataguard = None
    if role is not None:
        dataguard = role == "STANDBY" or bool(dests and dests > 0)
    fam = _os_family(r.get("platform_name"))
    return {"rac": rac, "asm": asm, "dataguard": dataguard, "role": role, "os_family": fam,
            "facts": {k: r.get(k) for k in ("instance_count", "cluster_database", "datafiles_total", "datafiles_in_asm",
                                             "asm_diskgroups", "database_role", "standby_destinations", "platform_name")}}


def compare(observed: dict, target) -> list:
    """Disagreements between observed and declared dimensions (unknown on either side is not a disagreement)."""
    arch = target.architecture or {}
    out = []
    for dim in ("rac", "asm", "dataguard"):
        o, d = observed.get(dim), arch.get(dim)
        if isinstance(o, bool) and isinstance(d, bool) and o != d:
            out.append({"dimension": dim, "declared": d, "observed": o})
    if observed.get("role") and target.role not in (None, "UNKNOWN") and observed["role"] != target.role:
        out.append({"dimension": "role", "declared": target.role, "observed": observed["role"]})
    tos = (getattr(target, "os", None) or {}).get("family")
    if observed.get("os_family") and tos and observed["os_family"] != tos:
        out.append({"dimension": "os", "declared": tos, "observed": observed["os_family"]})
    return out


class ObservedTarget:
    """A view of a Target where observed dimensions replace declared ones (for field validation only)."""

    def __init__(self, target, observed: dict):
        self._t = target
        arch = dict(target.architecture or {})
        for dim in ("rac", "asm", "dataguard"):
            if isinstance(observed.get(dim), bool):
                arch[dim] = observed[dim]
        self.architecture = arch
        self.role = observed.get("role") or target.role
        tos = dict(getattr(target, "os", None) or {})
        if observed.get("os_family") and tos.get("family") != observed["os_family"]:
            tos = {"family": observed["os_family"]}          # distribution/version of a different family is meaningless
        self.os = tos

    def __getattr__(self, name):
        return getattr(self._t, name)
