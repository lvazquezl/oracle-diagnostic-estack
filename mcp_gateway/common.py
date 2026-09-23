"""
mcp_gateway.common — constants, stable error codes (FIXED messages only) and small helpers for the
Phase 13 local MCP Diagnostic Gateway.

Design invariants (asserted by tests/test_p13_*.sh):
  * READ-ONLY ALWAYS / HUMAN-EXECUTED REMEDIATION ONLY: no tool takes SQL, shell, paths, URLs or connection
    parameters; only certified collector ids + typed allowlisted parameters + registered target aliases.
  * Every error message is a fixed string from ERROR_MESSAGES — never built from client input.
  * Fixture mode is the ONLY adapter `python -m mcp_gateway` can run. Real adapters exist as DISABLED /
    CONTRACT_ONLY stubs; `oracle_sql` can only be LAB_ENABLED by the separate `python -m mcp_gateway_lab`
    launcher (one non-production target, human authorization, dedicated least-privilege account).
  * Python standard library only (plus the repository's own rca_engine / change_documentation_knowledge
    public helpers). No network, no telemetry, no listener: stdio only.
"""
from __future__ import annotations

GATEWAY_NAME = "oracle-diagnostic-estack-mcp-gateway"
GATEWAY_VERSION = "1.0.1"
SCHEMA_VERSION = "1.0.0"

# MCP protocol versions this gateway implements (newest first). The negotiated version is echoed in
# `initialize`; an unknown client version gets the newest one we support (the client then decides).
SUPPORTED_PROTOCOL_VERSIONS = ("2025-06-18", "2025-03-26", "2024-11-05")

# --- hard limits (fail closed) -------------------------------------------------------------------
MAX_MESSAGE_BYTES = 1_048_576          # one JSON-RPC line
MAX_JSON_DEPTH = 24
MAX_JSON_ITEMS = 2_000                 # total nodes accepted in a request
MAX_ARG_STRING = 256
MAX_RESPONSE_BYTES = 262_144
MAX_ROWS_HARD = 200
MAX_SESSION_CALLS = 200
MAX_EVIDENCE_ENTRIES = 300
EVIDENCE_TTL_SECONDS = 3600
DEFAULT_OPERATION_TIMEOUT_SECONDS = 15.0
MAX_FIXTURE_BYTES = 1_000_000


# Operators may only LOWER these limits (flags in cli.py), never raise them: ceiling = the values above.
LIMIT_BOUNDS = {
    "operation_timeout": (0.1, DEFAULT_OPERATION_TIMEOUT_SECONDS),
    "max_session_calls": (1, MAX_SESSION_CALLS),
    "max_rows": (1, MAX_ROWS_HARD),
    "max_message_bytes": (1_024, MAX_MESSAGE_BYTES),
}


def bounded_limit(name: str, value):
    """Return `value` if it lies inside LIMIT_BOUNDS[name] (numeric, finite, not bool), else raise ValueError."""
    lo, hi = LIMIT_BOUNDS[name]
    if isinstance(value, bool) or not isinstance(value, (int, float)) or value != value or not (lo <= value <= hi):
        raise ValueError("limit out of bounds")
    return value


# JSON-RPC error codes
PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
INTERNAL_ERROR = -32603

ERROR_MESSAGES = {
    "E_PARSE": "message is not valid JSON",
    "E_INVALID_REQUEST": "message is not a valid request",
    "E_METHOD_NOT_FOUND": "method is not supported",
    "E_NOT_INITIALIZED": "server is not initialized",
    "E_INVALID_PARAMS": "parameters are invalid",
    "E_MESSAGE_TOO_LARGE": "message exceeds the size limit",
    "E_TOOL_UNKNOWN": "tool is not available",
    "E_ARGS_INVALID": "arguments do not satisfy the tool schema",
    "E_TARGET_UNKNOWN": "target alias is not registered",
    "E_TARGET_DISABLED": "target is not enabled for diagnostics",
    "E_COLLECTOR_UNKNOWN": "collector is not certified in this gateway",
    "E_COLLECTOR_NOT_ALLOWED": "collector is not allowed for this target",
    "E_CAPABILITY": "capability is not available for this target",
    "E_BUDGET_EXCEEDED": "budget for this session or target is exhausted",
    "E_ADAPTER_DISABLED": "the adapter for this target is disabled",
    "E_ADAPTER_FAILED": "the adapter could not produce a result",
    "E_TIMEOUT": "operation exceeded its time limit",
    "E_RESULT_INVALID": "adapter result violates the collector contract",
    "E_EVIDENCE_NOT_FOUND": "evidence reference is not available in this scope",
    "E_OUTPUT_TOO_LARGE": "response exceeds the size limit",
    "E_SANITIZATION": "output could not be sanitized safely",
    "E_INSUFFICIENT_EVIDENCE": "not enough sanitized evidence to run this analysis",
    "E_ANALYSIS_FAILED": "analysis input was rejected by the analysis engine",
    "E_TARGET_MISMATCH": "connected target does not match its authorized identity",
    "E_PRIVILEGES_EXCESSIVE": "diagnostic account holds privileges beyond the approved minimum",
    "E_AUTHORIZATION_EXPIRED": "human authorization for this target is missing or expired",
    "E_BUSY": "a previous operation for this target is still in progress",
    "E_INTERNAL": "unexpected internal error (details suppressed)",
}


class GatewayError(Exception):
    """Fail-closed error carrying ONLY a stable code (+ optional capability status). Its text is a
    fixed message; nothing from the request is ever interpolated."""

    def __init__(self, code: str, capability_status: str = None):
        self.code = code if code in ERROR_MESSAGES else "E_INTERNAL"
        self.capability_status = capability_status
        super().__init__(ERROR_MESSAGES[self.code])

    @property
    def message(self) -> str:
        return ERROR_MESSAGES[self.code]


class CapabilityStatus:
    SUPPORTED = "SUPPORTED"
    UNSUPPORTED = "UNSUPPORTED"
    ENVIRONMENT_UNKNOWN = "ENVIRONMENT_UNKNOWN"
    LICENSE_RESTRICTED = "LICENSE_RESTRICTED"
    INSUFFICIENT_PRIVILEGES = "INSUFFICIENT_PRIVILEGES"
    DISABLED = "DISABLED"
    NOT_APPLICABLE = "NOT_APPLICABLE"


class AdapterStatus:
    VERIFIED_FIXTURE = "VERIFIED_FIXTURE"
    VERIFIED_LAB = "VERIFIED_LAB"
    # Real adapter enabled ONLY by the separate lab launcher (mcp_gateway_lab) for one human-authorized,
    # non-production target. It is NOT a verification claim: maturity stays below PILOT_VALIDATED.
    LAB_ENABLED = "LAB_ENABLED"
    CONTRACT_ONLY = "CONTRACT_ONLY"
    DISABLED = "DISABLED"
    UNSUPPORTED = "UNSUPPORTED"
    NOT_INTEGRATION_TESTED = "NOT_INTEGRATION_TESTED"
