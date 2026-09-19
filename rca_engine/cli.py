"""
rca_engine.cli — local adapter entrypoint (mirrors capacity_engine.cli's role for the incident
domain, PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING).

Demonstrates the real end-to-end path: local fixture (JSON) -> rca_engine -> structured RcaResult
-> Markdown RCA report + evidence manifest — fully invocable without any LLM, MCP, network access
or Oracle connection.

Runtime status of the slash-command entrypoints (/diagnose incident, /rca, /healthcheck incident):
  CONTRACT_ONLY / NOT_RUNTIME_CERTIFIED — they describe the orchestration a live agent runtime
  performs; that runtime is the MCP Gateway, out of scope until a later phase.
  this CLI (rca_engine.cli / `python3 -m rca_engine.cli`)
      -> LOCAL_RUNTIME_TESTED (exercised directly by tests/test_rca_*.sh)

Usage:
  python3 -m rca_engine.cli --fixture path/to/incident.json [--rules path/to/rules.json] \
      [--policy path/to/policy.json] [--out result.json] [--markdown report.md] \
      [--manifest evidence-manifest.json] [--token-map token-map.json] \
      [--out-dir path/to/allowed/output/dir]

Malformed input (schema violation, unreadable JSON, unknown rule operator) always exits non-zero
with a message on stderr — never a partial/best-effort result on invalid input, and never echoing
the raw offending value (PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION
HARDENING).

--token-map is the ONLY place a raw target_id/source_id can ever be recovered from a token — it is
written to its own separate file, never merged into --out/--markdown/--manifest. Treat it as
sensitive local operator material (same handling as evidence/raw), never send it to a model or
attach it to a shared report.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

from .engine import run_rca
from .intake import IntakeError
from .report import render_rca_report
from .rules import RulesError
from .sanitize import SanitizationError

MAX_FIXTURE_BYTES = 5_000_000  # ingestion safety limit — section 3 del prompt: "max bytes/rows"


def _load_json(path: str):
    size = os.path.getsize(path)
    if size > MAX_FIXTURE_BYTES:
        raise ValueError(f"{path}: {size} bytes exceeds the {MAX_FIXTURE_BYTES}-byte ingestion limit")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _validate_output_path(path: str, out_dir: str) -> str:
    """When --out-dir is given, every output path must resolve strictly inside it — rejects path
    traversal (`..`) and absolute paths outside the allowlisted directory. Returns the path to use
    (joined with out_dir when relative)."""
    if out_dir is None:
        return path
    candidate = path if os.path.isabs(path) else os.path.join(out_dir, path)
    real_out_dir = os.path.realpath(out_dir)
    real_candidate = os.path.realpath(candidate)
    if os.path.commonpath([real_out_dir, real_candidate]) != real_out_dir:
        raise ValueError(f"output path '{path}' resolves outside the allowed --out-dir '{out_dir}'")
    return candidate


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="rca_engine local adapter (LOCAL_RUNTIME_TESTED)")
    parser.add_argument("--fixture", required=True, help="path to a JSON fixture {incident, evidence}")
    parser.add_argument("--rules", help="path to a JSON rules catalog (default: bundled default_rules.json)")
    parser.add_argument("--policy", help="path to a JSON policy override")
    parser.add_argument("--out", help="path to write the JSON RcaResult (default: stdout)")
    parser.add_argument("--markdown", help="path to write the rendered Markdown RCA report")
    parser.add_argument("--manifest", help="path to write the evidence manifest JSON separately")
    parser.add_argument("--token-map", help="path to write the target_id/source_id token->raw map "
                                             "SEPARATELY — never merged into --out/--markdown/--manifest")
    parser.add_argument("--out-dir", help="if set, every output path is validated to resolve inside this directory")
    args = parser.parse_args(argv)

    try:
        fixture = _load_json(args.fixture)
        policy = _load_json(args.policy) if args.policy else None
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"rca_engine.cli: failed to read input: {exc}", file=sys.stderr)
        return 2

    try:
        result, token_map = run_rca(fixture, rules_path=args.rules, policy=policy)
    except (IntakeError, RulesError, SanitizationError) as exc:
        print(f"rca_engine.cli: invalid input rejected: {exc}", file=sys.stderr)
        return 2

    payload = json.dumps(result, indent=2, sort_keys=True)

    try:
        if args.out:
            out_path = _validate_output_path(args.out, args.out_dir)
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(payload)
        else:
            print(payload)

        if args.markdown:
            md_path = _validate_output_path(args.markdown, args.out_dir)
            with open(md_path, "w", encoding="utf-8") as f:
                f.write(render_rca_report(result))

        if args.manifest:
            manifest_path = _validate_output_path(args.manifest, args.out_dir)
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(result["evidence_manifest"], f, indent=2, sort_keys=True)

        if args.token_map:
            token_map_path = _validate_output_path(args.token_map, args.out_dir)
            with open(token_map_path, "w", encoding="utf-8") as f:
                json.dump(token_map, f, indent=2, sort_keys=True)
    except ValueError as exc:
        print(f"rca_engine.cli: {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
