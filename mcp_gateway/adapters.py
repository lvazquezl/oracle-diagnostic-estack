"""
mcp_gateway.adapters — adapter registry. FIXTURE is the only adapter that can run.

  fixture           VERIFIED_FIXTURE   reads synthetic JSON from a confined directory (no SQL is executed)
  oracle_sql        DISABLED           contract stub: no driver is imported, no connection is ever attempted
  oracle_diag_file / os_readonly   CONTRACT_ONLY   (declared, not implemented)

A real adapter could only be enabled by an explicit, reviewed code + configuration change AND human
authorization per target; there is no runtime switch, environment variable or tool argument that turns one
on. Adapter output is UNTRUSTED data: it always goes through evidence.sanitize_rows().
"""
from __future__ import annotations

import os
import threading

from change_documentation_knowledge.common import AdvisoryError
from change_documentation_knowledge.safety import confine, read_json_file

from .common import DEFAULT_OPERATION_TIMEOUT_SECONDS, MAX_FIXTURE_BYTES, AdapterStatus, GatewayError


class FixtureAdapter:
    name = "fixture"
    status = AdapterStatus.VERIFIED_FIXTURE

    def __init__(self, fixtures_dir: str):
        if not isinstance(fixtures_dir, str) or not os.path.isdir(fixtures_dir) or os.path.islink(fixtures_dir):
            raise RuntimeError("fixtures directory is not usable")
        self.fixtures_dir = os.path.realpath(fixtures_dir)

    def fetch(self, target, collector, params: dict):
        """Return the untrusted rows recorded for (target alias, collector id). Path components are already
        validated by grammar (catalog.ALIAS_RE / COLLECTOR_ID_RE); confine() additionally rejects traversal
        and symlinks, and the file is size-bounded and parsed strictly."""
        try:
            path = confine(self.fixtures_dir, target.alias, collector.collector_id + ".json")
            doc = read_json_file(path, MAX_FIXTURE_BYTES)
        except AdvisoryError:
            raise GatewayError("E_ADAPTER_FAILED")
        if not isinstance(doc, dict) or "rows" not in doc:
            raise GatewayError("E_RESULT_INVALID")
        return doc["rows"]


class DisabledAdapter:
    """Contract-only stand-in for adapters that are not implemented/enabled. Never connects."""

    def __init__(self, name: str, status: str = AdapterStatus.DISABLED):
        self.name = name
        self.status = status

    def fetch(self, target, collector, params: dict):
        raise GatewayError("E_ADAPTER_DISABLED")


class AdapterRegistry:
    def __init__(self, fixtures_dir: str, extra: dict = None):
        self._adapters = {
            "fixture": FixtureAdapter(fixtures_dir),
            "oracle_sql": DisabledAdapter("oracle_sql", AdapterStatus.DISABLED),
            "oracle_diag_file": DisabledAdapter("oracle_diag_file", AdapterStatus.CONTRACT_ONLY),
            "os_readonly": DisabledAdapter("os_readonly", AdapterStatus.CONTRACT_ONLY),
        }
        if extra:                                    # test injection point only (never reachable from the CLI)
            self._adapters.update(extra)

    def get(self, name: str):
        a = self._adapters.get(name)
        if a is None:
            raise GatewayError("E_ADAPTER_DISABLED")
        return a

    def status_of(self, name: str) -> str:
        a = self._adapters.get(name)
        return a.status if a is not None else AdapterStatus.UNSUPPORTED

    def describe(self) -> dict:
        return {name: a.status for name, a in sorted(self._adapters.items())}


def run_with_timeout(fn, timeout_seconds: float):
    """Run an adapter call with a hard deadline. On timeout the worker thread is abandoned (daemon) and the
    caller gets E_TIMEOUT — a slow adapter can never block the protocol loop."""
    box = {}

    def work():
        try:
            box["value"] = fn()
        except GatewayError as e:
            box["error"] = e
        except BaseException:
            box["error"] = GatewayError("E_ADAPTER_FAILED")

    t = threading.Thread(target=work, daemon=True)
    t.start()
    t.join(min(timeout_seconds, DEFAULT_OPERATION_TIMEOUT_SECONDS))
    if t.is_alive():
        raise GatewayError("E_TIMEOUT")
    if "error" in box:
        raise box["error"]
    return box.get("value")
