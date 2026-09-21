"""
mcp_gateway.versions — effective Oracle version resolution.

Rules (each one is exercised by tests/p14):
  * Versions are compared NUMERICALLY, component by component — never as strings ("9.2" < "10.1",
    "11.2.0.10" > "11.2.0.4"; lexicographic order gets both wrong).
  * A version maps to a supported FAMILY only through its numeric major (10→10g, 11→11g, 12→12c, 18→18c,
    19→19c, 21→21c, 23→23ai). A release update or patch level never changes the family.
  * Unknown, empty, non-string, "latest"/"current"/"newest" and majors outside the table resolve to None:
    the caller must degrade explicitly (ENVIRONMENT_UNKNOWN / UNSUPPORTED). "latest" is never assumed
    to be supported.
"""
from __future__ import annotations

import re

FAMILY_BY_MAJOR = {10: "10g", 11: "11g", 12: "12c", 18: "18c", 19: "19c", 21: "21c", 23: "23ai"}
FAMILIES = tuple(FAMILY_BY_MAJOR.values())
_FAMILY_TOKEN = re.compile(r'^([0-9]{2})(g|c|ai)\Z', re.IGNORECASE)
_DOTTED = re.compile(r'^[0-9]{1,3}(\.[0-9]{1,5}){0,5}\Z')
_MAX_LEN = 40


def parse_version(text):
    """Return a tuple of ints for a dotted version ('19.0.0.0.0' -> (19,0,0,0,0)) or None."""
    if not isinstance(text, str) or not (1 <= len(text) <= _MAX_LEN) or not _DOTTED.match(text):
        return None
    return tuple(int(part) for part in text.split("."))


def compare_versions(a: str, b: str):
    """-1, 0 or 1 comparing two dotted versions numerically; None if either is not a valid version.
    Missing trailing components count as zero ('19' == '19.0.0')."""
    pa, pb = parse_version(a), parse_version(b)
    if pa is None or pb is None:
        return None
    n = max(len(pa), len(pb))
    pa, pb = pa + (0,) * (n - len(pa)), pb + (0,) * (n - len(pb))
    return (pa > pb) - (pa < pb)


def family_of(text):
    """Supported family ('19c') for a family token or a dotted version, or None (unknown/unsupported)."""
    if not isinstance(text, str) or not (1 <= len(text) <= _MAX_LEN):
        return None
    token = _FAMILY_TOKEN.match(text.strip())
    if token:
        family = FAMILY_BY_MAJOR.get(int(token.group(1)))
        return family if family and family.lower() == text.strip().lower() else None
    parsed = parse_version(text.strip())
    if parsed is None:
        return None
    return FAMILY_BY_MAJOR.get(parsed[0])
