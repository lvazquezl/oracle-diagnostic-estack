"""
rca_engine — local, deterministic RCA (root cause analysis) execution engine.

PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING. Closes the gap between the declarative
contracts of skills/incident/* (docs/INCIDENT_ROOT_CAUSE_MODEL.md, docs/INCIDENT_CAUSALITY_MODEL.md,
docs/INCIDENT_HYPOTHESIS_MODEL.md, docs/INCIDENT_TIMELINE_MODEL.md) and a real, testable rule-based
RCA engine — same pattern as capacity_engine for skills/capacity/*.

READ-ONLY ALWAYS. HUMAN-EXECUTED REMEDIATION ONLY. This package never connects to Oracle/OS/
network/any live resource, never executes SQL/shell, and exposes no execute_sql(sql)/
execute_shell(command)/read_file(path) function. It operates exclusively on already-collected,
sanitized evidence supplied as a local fixture — evidence_by_reference, never a new collector.
Every recommendation it produces is text only, execution_status is always the fixed constant
"NOT_EXECUTED" (see common.Recommendation).

All reasoning is local/deterministic rule matching (rules/default_rules.json, versioned and
allowlisted) — no LLM, no MCP, no clock read implicitly for causal logic (the analysis anchor is
the maximum evidence timestamp actually used, never wall-clock "now" — see engine.run_rca()).

Python 3 standard library only — no external dependencies, matching the existing convention of
capacity_engine and parsers/*/common.py.
"""
from __future__ import annotations

from .common import CONTRACT_VERSION, ENGINE_VERSION, RcaResult
from .engine import run_rca

__all__ = ["CONTRACT_VERSION", "ENGINE_VERSION", "RcaResult", "run_rca"]
