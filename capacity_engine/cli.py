"""
capacity_engine.cli — local adapter entrypoint (# 9 del prompt de Fase 10 hardening).

Demonstrates the real end-to-end path: local fixture (JSON) -> capacity_engine -> structured
ForecastResult -> Markdown report — fully invocable without any LLM, MCP, or network access.

Runtime status of the slash-command entrypoints (# 9, # 12 del prompt):
  /healthcheck capacity, /assessment capacity  -> CONTRACT_ONLY / NOT_RUNTIME_CERTIFIED
      (they describe the orchestration a live agent runtime performs; that runtime is the MCP
       Gateway, out of scope until a later phase — see docs/PHASE_10_FORECASTING_EXECUTION_
       NUMERICAL_VALIDATION_HARDENING.md#workflow-integration-status)
  this CLI (capacity_engine.cli / `python3 -m capacity_engine.cli`)
      -> LOCAL_RUNTIME_TESTED (exercised directly by tests/test_capacity_engine_end_to_end.sh)

Usage:
  python3 -m capacity_engine.cli --fixture path/to/samples.json --policy path/to/policy.json \
      --thresholds path/to/thresholds.json [--as-of 2026-06-01T00:00:00+00:00] [--markdown out.md]

The fixture JSON is either a flat list of raw sample dicts, or {"samples": [...]}.
"""
from __future__ import annotations

import argparse
import json
import sys

from .engine import run_capacity_forecast
from .report import render_full_report


def _load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="capacity_engine local adapter (CONTRACT_ONLY slash commands, LOCAL_RUNTIME_TESTED here)")
    parser.add_argument("--fixture", required=True, help="path to a JSON fixture of raw metric samples")
    parser.add_argument("--policy", help="path to a JSON policy override")
    parser.add_argument("--thresholds", help="path to a JSON {name: percent} threshold map")
    parser.add_argument("--as-of", help="ISO-8601 timestamp for freshness/audit metadata only")
    parser.add_argument("--markdown", help="path to write the rendered Markdown report")
    parser.add_argument("--out", help="path to write the JSON ForecastResult (default: stdout)")
    args = parser.parse_args(argv)

    raw = _load_json(args.fixture)
    samples = raw["samples"] if isinstance(raw, dict) and "samples" in raw else raw
    policy = _load_json(args.policy) if args.policy else None
    thresholds = _load_json(args.thresholds) if args.thresholds else None

    result = run_capacity_forecast(samples, policy=policy, thresholds=thresholds, as_of=args.as_of)
    payload = json.dumps(result.to_dict(), indent=2, sort_keys=True)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(payload)
    else:
        print(payload)

    if args.markdown:
        report = render_full_report([result])
        with open(args.markdown, "w", encoding="utf-8") as f:
            f.write(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
