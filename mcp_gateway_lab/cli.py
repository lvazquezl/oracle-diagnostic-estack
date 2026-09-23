"""
mcp_gateway_lab.cli — `python -m mcp_gateway_lab <command>` (operator-level only, never reachable from a tool call).

  validate-config --targets FILE --lab-profile FILE   offline: validates both files, prints a summary without
                                                      host, user or secret references; no connection is made
  check           --targets FILE --lab-profile FILE   human smoke test: ONE diagnostics.collect of Q-DISC-IDENTITY-001
                                                      through the full gateway path; prints the SANITIZED envelope and
                                                      a coarse failure category (fixed enum) on stdout
  serve           --targets FILE --lab-profile FILE   stdio MCP server for Claude Code (stdout = protocol only)
                  [--audit {stderr,off}] [--operation-timeout S] [--max-session-calls N] [--max-rows N]
  --version

There is no option to pass SQL, a DSN, a host, a user, a password or an environment switch: connection coordinates
and the secret-store reference live in the private lab profile; the password lives in the secret store.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

from mcp_gateway import catalog
from mcp_gateway.adapters import AdapterRegistry
from mcp_gateway.common import GATEWAY_NAME, GATEWAY_VERSION, LIMIT_BOUNDS, bounded_limit
from mcp_gateway.gateway import Audit, Gateway, Session
from mcp_gateway.server import McpServer

from .oracle_sql import IDENTITY_COLLECTOR, SUPPORTED_COLLECTORS, OracleSqlAdapter
from .profile import CONTAINERS, ProfileError, load_profile

LAB_VERSION = "0.4.0"
REFUSED = "mcp_gateway_lab: startup refused ({})\n"


class _Parser(argparse.ArgumentParser):
    def error(self, message):            # never echo the offending value
        sys.stderr.write("mcp_gateway_lab: invalid command line usage\n")
        raise SystemExit(2)


def _load_driver():
    try:
        import oracledb                                    # python-oracledb, THIN mode (init_oracle_client is never called)
    except ImportError:
        raise ProfileError("python-oracledb is not installed in this Python environment")
    if not oracledb.is_thin_mode():
        raise ProfileError("python-oracledb must run in thin mode")
    return oracledb


def build_lab_gateway(targets_file: str, profile_file: str, audit_sink=None, driver=None, credential_runner=None, wallclock=None):
    """Returns (gateway, adapter). Raises ProfileError / RuntimeError with fixed text on any refusal."""
    profile = load_profile(profile_file)
    if not isinstance(targets_file, str) or not os.path.isabs(targets_file) or os.path.islink(targets_file) or not os.path.isfile(targets_file):
        raise ProfileError("lab targets file must be an absolute path to a regular file")
    collectors = catalog.load_collectors()
    targets = catalog.load_targets(targets_file, collectors)
    if len(targets) != 1:
        raise ProfileError("the lab targets file must register exactly one target")
    (alias, t), = targets.items()
    spec = profile.get(alias)
    if spec is None:
        raise ProfileError("the lab target is not the target named by the lab profile")
    if t.adapter != "oracle_sql" or not t.enabled:
        raise ProfileError("the lab target must use the oracle_sql adapter and be enabled")
    if not t.allowed_collectors or not t.allowed_collectors <= set(SUPPORTED_COLLECTORS):
        raise ProfileError("the lab target allows a collector the oracle_sql adapter does not implement")
    if t.oracle_version != spec.expected_version_family or t.role != spec.gateway_role() or t.container not in CONTAINERS \
            or t.container != spec.expected_container:
        raise ProfileError("the lab target registration does not match the lab profile")
    adapter = OracleSqlAdapter(profile, driver if driver is not None else _load_driver(), collectors[IDENTITY_COLLECTOR],
                               credential_runner=credential_runner, wallclock=wallclock)
    registry = AdapterRegistry(catalog.DEFAULT_FIXTURES_DIR, extra={"oracle_sql": adapter})
    return Gateway(collectors, targets, registry, Audit(audit_sink), lab_mode=True), adapter


def _summary(gateway) -> dict:
    (alias, t), = gateway.targets.items()
    return {"target_alias": alias, "adapter": t.adapter, "adapter_status": gateway.adapters.status_of(t.adapter),
            "oracle_version": t.oracle_version, "role": t.role, "container": t.container,
            "allowed_collectors": sorted(t.allowed_collectors)}


def run_check(gateway, adapter) -> tuple:
    (alias, _t), = gateway.targets.items()
    session = Session()
    env, is_error = gateway.call(session, "diagnostics.collect", {"collector_id": IDENTITY_COLLECTOR, "target_alias": alias})
    report = {"check": "oracle_sql lab smoke test", "lab_version": LAB_VERSION, "gateway": f"{GATEWAY_NAME} {GATEWAY_VERSION}",
              "target": _summary(gateway), "result": "PASS" if not is_error else "FAIL",
              "failure_category": adapter.last_failure, "envelope": env,
              "note": "sanitized envelope only; a lab PASS is not production readiness"}
    return report, (0 if not is_error else 1)


def build_parser() -> argparse.ArgumentParser:
    p = _Parser(prog="python -m mcp_gateway_lab", description="LAB launcher for the read-only oracle_sql adapter.")
    p.add_argument("--version", action="store_true")
    sub = p.add_subparsers(dest="command")
    for name in ("validate-config", "check", "serve"):
        s = sub.add_parser(name)
        s.error = p.error
        s.add_argument("--targets", required=True)
        s.add_argument("--lab-profile", required=True)
        if name == "serve":
            s.add_argument("--audit", choices=("stderr", "off"), default="stderr")
            s.add_argument("--operation-timeout", type=float)
            s.add_argument("--max-session-calls", type=int)
            s.add_argument("--max-rows", type=int)
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if args.version:
        sys.stdout.write(f"mcp_gateway_lab {LAB_VERSION} ({GATEWAY_NAME} {GATEWAY_VERSION})\n")
        return 0
    if not args.command:
        sys.stderr.write("mcp_gateway_lab: invalid command line usage\n")
        return 2
    sink = None
    if args.command == "serve" and args.audit == "stderr":
        sink = lambda line: (sys.stderr.write("AUDIT " + line + "\n"), sys.stderr.flush())
    try:
        gateway, adapter = build_lab_gateway(args.targets, args.lab_profile, sink)
        if args.command == "serve":
            for k in ("operation_timeout", "max_session_calls", "max_rows"):
                v = getattr(args, k)
                if v is not None:
                    setattr(gateway, k, type(LIMIT_BOUNDS[k][1])(bounded_limit(k, v)))
    except ProfileError as e:
        sys.stderr.write(REFUSED.format(e))
        return 2
    except (RuntimeError, OSError, KeyError, ValueError, TypeError):
        sys.stderr.write(REFUSED.format("catalog, target or lab profile configuration is invalid"))
        return 2
    if args.command == "validate-config":
        exp = adapter._profile.target.authorization.expires_at.strftime("%Y-%m-%dT%H:%M:%SZ")
        out = dict(_summary(gateway), environment_class="NON_PRODUCTION", transport=adapter._profile.target.transport,
                   authorization_expires_at_utc=exp, limits=adapter._profile.target.limits, connection_attempted=False)
        sys.stdout.write(json.dumps(out, indent=2, sort_keys=True) + "\n")
        return 0
    if args.command == "check":
        report, rc = run_check(gateway, adapter)
        sys.stdout.write(json.dumps(report, indent=2, sort_keys=True) + "\n")
        return rc
    return McpServer(gateway).serve()


if __name__ == "__main__":
    sys.exit(main())
