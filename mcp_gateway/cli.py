"""
mcp_gateway.cli — entrypoint: `python -m mcp_gateway` starts the LOCAL stdio MCP server.

Operator-level options only (never reachable from a tool call):
  --targets FILE        JSON target catalog (default: the shipped SYNTHETIC fixture targets)
  --fixtures-dir DIR    directory of synthetic fixture data (default: the shipped fixtures)
  --audit {stderr,off}  local audit sink (default stderr, one JSON line per call, no arguments/evidence)
  --print-claude-config print a Claude Code MCP configuration example (no credentials) and exit
  --version

There is deliberately NO option to enable a real adapter, set a connection, add a collector or open a
network listener. stdout is reserved for the MCP protocol; every diagnostic goes to stderr.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

from . import catalog
from .adapters import AdapterRegistry
from .common import GATEWAY_NAME, GATEWAY_VERSION, SUPPORTED_PROTOCOL_VERSIONS
from .gateway import Audit, Gateway
from .server import McpServer


class _Parser(argparse.ArgumentParser):
    def error(self, message):            # argparse would echo the offending value; print a fixed text instead
        sys.stderr.write("mcp_gateway: invalid command line usage\n")
        raise SystemExit(2)


def claude_config_example() -> dict:
    return {"mcpServers": {"oracle-diagnostic-estack": {
        "command": "python", "args": ["-m", "mcp_gateway"], "cwd": "<ABSOLUTE_PATH_TO_YOUR_CHECKOUT_OF_THE_REPOSITORY>",
        "env": {"PYTHONUTF8": "1", "PYTHONDONTWRITEBYTECODE": "1"}}},
        "_note": "Example only, fixture mode. Nothing sensitive belongs in this file. Copy it into your own Claude Code MCP settings yourself."}


def build_gateway(targets_file=None, fixtures_dir=None, audit_sink=None) -> Gateway:
    collectors = catalog.load_collectors()
    targets = catalog.load_targets(targets_file or catalog.DEFAULT_TARGETS_FILE, collectors)
    adapters = AdapterRegistry(fixtures_dir or catalog.DEFAULT_FIXTURES_DIR)
    return Gateway(collectors, targets, adapters, Audit(audit_sink))


def main(argv=None) -> int:
    p = _Parser(prog="python -m mcp_gateway", description=__doc__.split("\n\n")[0],
                epilog="stdout is reserved for the MCP protocol; logs and audit go to stderr.")
    p.add_argument("--targets")
    p.add_argument("--fixtures-dir")
    p.add_argument("--audit", choices=("stderr", "off"), default="stderr")
    p.add_argument("--print-claude-config", action="store_true")
    p.add_argument("--version", action="store_true")
    args = p.parse_args(argv)
    if args.version:
        sys.stdout.write(f"{GATEWAY_NAME} {GATEWAY_VERSION} (MCP protocol versions: {', '.join(SUPPORTED_PROTOCOL_VERSIONS)})\n")
        return 0
    if args.print_claude_config:
        sys.stdout.write(json.dumps(claude_config_example(), indent=2) + "\n")
        return 0
    try:
        sink = (lambda line: (sys.stderr.write("AUDIT " + line + "\n"), sys.stderr.flush())) if args.audit == "stderr" else None
        gateway = build_gateway(args.targets, args.fixtures_dir, sink)
    except (RuntimeError, OSError, KeyError, ValueError, TypeError):
        sys.stderr.write("mcp_gateway: startup refused (catalog, target or fixture configuration is invalid)\n")
        return 2
    return McpServer(gateway).serve()


if __name__ == "__main__":
    sys.exit(main())
