"""
release_readiness.common — constants, maturity definitions, fixed error messages and small helpers.

This package is RELEASE TOOLING: it inspects the repository, runs the repository's own test runner and
verifies evidence. It never connects to Oracle, never opens a network socket, never executes arbitrary
commands and never commits, merges, pushes, tags or deploys anything.
"""
from __future__ import annotations

import hashlib
import json
import re
import secrets
from datetime import datetime, timezone

SCHEMA_VERSION = "1.0.0"
TOOL_VERSION = "release_readiness/1.0.0"

PASS, FAIL, INCONCLUSIVE, NOT_APPLICABLE = "PASS", "FAIL", "INCONCLUSIVE", "NOT_APPLICABLE"
TREE_VERIFIED, TREE_UNVERIFIED, TREE_CHANGED = "VERIFIED", "UNVERIFIED", "CHANGED_DURING_RUN"

# --- maturity states -----------------------------------------------------------------------------
# Lowest to highest. A state is a CLAIM about verifiable evidence; the registry verifier rejects any claim
# that lacks the evidence its definition requires.
MATURITY_ORDER = ("UNSUPPORTED", "DISABLED", "CONTRACT_ONLY", "TESTED_WITH_SYNTHETIC_FIXTURES", "PILOT_VALIDATED", "CERTIFIED")
MATURITY_DEFINITIONS = {
    "UNSUPPORTED": "Not supported (the Oracle feature does not exist for the target, or the e-stack does not cover it). Requires a reason.",
    "DISABLED": "Implemented or declared but cannot run: there is no runtime switch, flag or tool argument that turns it on. Requires a reason.",
    "CONTRACT_ONLY": "Specified and statically certified (contract, schema, query text) but never executed against a real target.",
    "TESTED_WITH_SYNTHETIC_FIXTURES": "Executed by automated tests against SYNTHETIC fixtures only. Requires at least one existing test script.",
    "PILOT_VALIDATED": "Validated in an approved non-production, representative environment. Requires a valid pilot record (schema in registry.py) with verifiable evidence files.",
    "CERTIFIED": "PILOT_VALIDATED plus formal administrator acceptance recorded in the pilot record. Requires a valid pilot record.",
}
REAL_ENVIRONMENT_STATES = ("PILOT_VALIDATED", "CERTIFIED")

ERROR_MESSAGES = {
    "E_USAGE": "invalid command line",
    "E_ROOT": "repository root is not usable",
    "E_GIT": "git information could not be obtained",
    "E_OUTPUT_DIR": "output directory is not acceptable",
    "E_COMMAND": "command is not allowed",
    "E_INPUT": "input file is missing, too large or malformed",
    "E_REGISTRY": "capability registry is malformed",
    "E_PACKAGE": "evidence package is malformed",
    "E_INTERNAL": "internal error",
}


class ReadinessError(Exception):
    """Raised with a fixed message only; the offending input is never echoed."""

    def __init__(self, code: str):
        self.code = code if code in ERROR_MESSAGES else "E_INTERNAL"
        self.message = ERROR_MESSAGES[self.code]
        super().__init__(self.message)


# --- time ----------------------------------------------------------------------------------------
_UTC = re.compile(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]{1,6})?(Z|\+00:00)\Z')


def parse_utc(value):
    """datetime (UTC) for a strict ISO-8601 UTC timestamp, else None. Impossible dates (month 13) are rejected."""
    if not isinstance(value, str) or not _UTC.match(value):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def new_run_id() -> str:
    return datetime.now(timezone.utc).strftime("RUN-%Y%m%dT%H%M%SZ-") + secrets.token_hex(4)


# --- hashing / json ------------------------------------------------------------------------------
def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_json(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def dumps_pretty(obj) -> str:
    return json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=True) + "\n"


def worst(results) -> str:
    """Combine check results: any FAIL wins, then INCONCLUSIVE, else PASS (NOT_APPLICABLE is neutral)."""
    results = [r for r in results if r != NOT_APPLICABLE]
    if FAIL in results:
        return FAIL
    if INCONCLUSIVE in results or not results:
        return INCONCLUSIVE
    return PASS
