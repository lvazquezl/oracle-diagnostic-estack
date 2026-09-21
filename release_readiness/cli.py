"""
python -m release_readiness — local release tooling (read-only with respect to the repository and to Oracle).

  snapshot          print the fingerprint of the working tree (aggregate hash and counts)
  run               run the repository test runner and write an evidence package OUTSIDE the repository
  verify            verify an evidence package independently (exit 0 PASS, 1 FAIL, 2 INCONCLUSIVE)
  gate              run the release readiness gate (exit 0 PASS, 1 FAIL, 2 INCONCLUSIVE)
  registry-check    compare the capability registry with the code
  governance-check  validate the risk register and the lifecycle records

Nothing here commits, merges, pushes, tags, deploys or connects to a database or the network.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

from . import evidence, fingerprint, gate, governance, registry
from .common import FAIL, INCONCLUSIVE, PASS, ReadinessError

DEFAULT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_EXIT = {PASS: 0, FAIL: 1, INCONCLUSIVE: 2}


class _Parser(argparse.ArgumentParser):
    def error(self, message):                     # fixed text: never echo the offending value
        sys.stderr.write("release_readiness: invalid command line\n")
        raise SystemExit(3)


def build_parser() -> argparse.ArgumentParser:
    p = _Parser(prog="python -m release_readiness", description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="command", required=True, parser_class=_Parser)
    s = sub.add_parser("snapshot")
    s.add_argument("--root", default=DEFAULT_ROOT)
    r = sub.add_parser("run")
    r.add_argument("--root", default=DEFAULT_ROOT)
    r.add_argument("--out", required=True, help="new directory OUTSIDE the repository for the evidence package")
    r.add_argument("--runner", default="tests/run-all.sh", help="repository-relative *.sh runner")
    r.add_argument("--timeout-seconds", type=int, default=evidence.DEFAULT_TIMEOUT_SECONDS)
    v = sub.add_parser("verify")
    v.add_argument("--package", required=True)
    v.add_argument("--root", default=None, help="repository root; without it the tree identity stays UNVERIFIED")
    g = sub.add_parser("gate")
    g.add_argument("--root", default=DEFAULT_ROOT)
    g.add_argument("--evidence", default=None, help="evidence package produced by `run`")
    g.add_argument("--require-clean", action="store_true")
    g.add_argument("--format", choices=("json", "markdown"), default="json")
    g.add_argument("--out", default=None, help="new directory OUTSIDE the repository for gate-report.json/.md")
    c = sub.add_parser("registry-check")
    c.add_argument("--root", default=DEFAULT_ROOT)
    m = sub.add_parser("governance-check")
    m.add_argument("--root", default=DEFAULT_ROOT)
    return p


def _emit(obj) -> None:
    sys.stdout.write(json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=True) + "\n")


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        root = os.path.realpath(args.root) if getattr(args, "root", None) else None
        if args.command == "snapshot":
            fp = fingerprint.take(root)
            _emit({"algorithm": fp["algorithm"], "file_count": fp["file_count"], "deleted_count": fp["deleted_count"], "aggregate_sha256": fp["aggregate_sha256"]})
            return 0
        if args.command == "run":
            sec = []
            try:
                sec = registry.load_registry(root).get("security_scripts", [])
            except ReadinessError:
                pass
            m = evidence.run_and_package(root, args.out, runner_rel=args.runner, timeout_seconds=args.timeout_seconds, security_scripts=sec)
            _emit({"run_id": m["run_id"], "verdict": m["verdict"], "exit_code": m["exit_code"], "duration_seconds": m["duration_seconds"],
                   "unique_scripts": m["results"]["verified"]["unique_scripts"], "fingerprint_identical": m["fingerprint"]["identical"]})
            return _EXIT[m["verdict"]["result"]]
        if args.command == "verify":
            res = evidence.verify_package(args.package, root)
            _emit(res)
            return _EXIT[res["result"]]
        if args.command == "gate":
            report = gate.sanitize_report(gate.run_gate(root, evidence_dir=args.evidence, require_clean=args.require_clean), root)
            if args.out:
                gate.write_report(report, args.out, root)
            sys.stdout.write(gate.render_markdown(report) if args.format == "markdown" else json.dumps(report, indent=2, sort_keys=True, ensure_ascii=True) + "\n")
            return _EXIT[report["release_gate"]]
        if args.command == "registry-check":
            res = registry.verify_registry(root)
            _emit(res)
            return 1 if res["findings"] else 0
        if args.command == "governance-check":
            f = governance.validate_risk_register(registry.load_json_strict(os.path.join(root, gate.GOVERNANCE_FILES[0]))) + \
                governance.validate_records_document(registry.load_json_strict(os.path.join(root, gate.GOVERNANCE_FILES[1])))
            _emit({"findings": f})
            return 1 if f else 0
    except ReadinessError as e:
        sys.stderr.write(f"release_readiness: {e.message}\n")
        return 3
    except Exception:                                              # never leak a traceback or a path
        sys.stderr.write("release_readiness: internal error\n")
        return 3
    return 3


if __name__ == "__main__":
    sys.exit(main())
