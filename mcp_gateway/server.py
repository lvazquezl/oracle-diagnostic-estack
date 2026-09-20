"""
mcp_gateway.server — MCP over stdio (newline-delimited JSON-RPC 2.0), implemented locally.

Why a local implementation: no MCP SDK is installed in this repository and this phase does not install
dependencies from the network. The implementation is small, dependency-free and covered by protocol
tests that drive a REAL subprocess over stdin/stdout (tests/p13/): framing, initialize handshake and
version negotiation, `tools/list`, `tools/call`, method rejection, pre-initialize calls, malformed
messages, oversize/deep payloads and clean shutdown.

Rules:
  * stdout carries ONLY JSON-RPC messages (one per line, UTF-8, "\\n"); logs/audit go to stderr.
  * Fail closed: unknown methods, wrong lifecycle order, batches, oversize (bytes/depth/nodes), invalid
    ids and malformed JSON get a fixed-text error; the offending input is never echoed.
  * No listener, no network, no telemetry. The loop ends at EOF (client closed stdin) or `shutdown`-less
    exit as the MCP stdio transport defines (the client closes stdin, the server exits 0).
"""
from __future__ import annotations

import json
import sys

from .common import (
    GATEWAY_NAME, GATEWAY_VERSION, INTERNAL_ERROR, INVALID_PARAMS, INVALID_REQUEST, MAX_JSON_DEPTH, MAX_JSON_ITEMS,
    MAX_MESSAGE_BYTES, METHOD_NOT_FOUND, PARSE_ERROR, SUPPORTED_PROTOCOL_VERSIONS, ERROR_MESSAGES, GatewayError,
)
from .gateway import Gateway, Session, tool_list


def _measure(obj, depth=0, budget=None):
    """(max depth, node count) with early exit — protects against deep/wide JSON before any processing."""
    if budget is None:
        budget = [0]
    budget[0] += 1
    if depth > MAX_JSON_DEPTH or budget[0] > MAX_JSON_ITEMS:
        raise ValueError("too complex")
    if isinstance(obj, dict):
        for k, v in obj.items():
            _measure(v, depth + 1, budget)
    elif isinstance(obj, list):
        for v in obj:
            _measure(v, depth + 1, budget)


def _reject_constant(_name):
    raise ValueError("non-finite number")


def _no_dupes(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate key")
    return dict(pairs)


class McpServer:
    def __init__(self, gateway: Gateway, out=None, err=None):
        self.gateway = gateway
        self._out = out if out is not None else sys.stdout.buffer
        self._err = err if err is not None else sys.stderr
        self.state = "NEW"            # NEW -> INITIALIZING (initialize answered) -> READY (initialized notification)
        self.protocol_version = None
        self.session = None

    # -- transport ---------------------------------------------------------------------------------
    def _send(self, obj: dict) -> None:
        line = json.dumps(obj, ensure_ascii=True, separators=(",", ":")).encode("utf-8") + b"\n"
        self._out.write(line)
        self._out.flush()

    def _error(self, req_id, code: int, key: str) -> None:
        self._send({"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": ERROR_MESSAGES[key]}})

    def _log(self, text: str) -> None:
        try:
            self._err.write(text + "\n")
            self._err.flush()
        except Exception:
            pass

    # -- message handling --------------------------------------------------------------------------
    def handle_line(self, raw: bytes) -> None:
        if len(raw) > MAX_MESSAGE_BYTES:
            return self._error(None, INVALID_REQUEST, "E_MESSAGE_TOO_LARGE")
        try:
            text = raw.decode("utf-8")
            msg = json.loads(text, parse_constant=_reject_constant, object_pairs_hook=_no_dupes)
            _measure(msg)
        except (UnicodeDecodeError, ValueError, RecursionError):
            return self._error(None, PARSE_ERROR, "E_PARSE")
        if not isinstance(msg, dict):                     # batches (arrays) and scalars are not accepted
            return self._error(None, INVALID_REQUEST, "E_INVALID_REQUEST")
        if msg.get("jsonrpc") != "2.0" or not isinstance(msg.get("method"), str) or set(msg) - {"jsonrpc", "id", "method", "params"}:
            rid = msg.get("id") if isinstance(msg.get("id"), (int, str)) and not isinstance(msg.get("id"), bool) else None
            return self._error(rid, INVALID_REQUEST, "E_INVALID_REQUEST")
        has_id = "id" in msg
        req_id = msg.get("id")
        if has_id and (isinstance(req_id, bool) or not isinstance(req_id, (int, str)) or (isinstance(req_id, str) and len(req_id) > 64)):
            return self._error(None, INVALID_REQUEST, "E_INVALID_REQUEST")
        params = msg.get("params", {})
        if params is not None and not isinstance(params, dict):
            return self._error(req_id if has_id else None, INVALID_PARAMS, "E_INVALID_PARAMS")
        params = params or {}
        method = msg["method"]
        if not has_id:
            return self._notification(method, params)
        try:
            self._request(req_id, method, params)
        except GatewayError as e:
            self._error(req_id, INVALID_PARAMS if e.code in ("E_INVALID_PARAMS",) else INVALID_REQUEST, e.code)
        except Exception:
            self._error(req_id, INTERNAL_ERROR, "E_INTERNAL")

    def _notification(self, method: str, params: dict) -> None:
        # notifications never get a response
        if method == "notifications/initialized" and self.state == "INITIALIZING":
            self.state = "READY"
        # notifications/cancelled and anything else: accepted and ignored (handlers are synchronous and bounded)

    def _request(self, req_id, method: str, params: dict) -> None:
        if method == "initialize":
            if self.state != "NEW":
                raise GatewayError("E_INVALID_REQUEST")
            pv = params.get("protocolVersion")
            if not isinstance(pv, str) or not isinstance(params.get("capabilities", {}), dict) or not isinstance(params.get("clientInfo", {}), dict):
                raise GatewayError("E_INVALID_PARAMS")
            self.protocol_version = pv if pv in SUPPORTED_PROTOCOL_VERSIONS else SUPPORTED_PROTOCOL_VERSIONS[0]
            self.session = Session()
            self.state = "INITIALIZING"
            return self._send({"jsonrpc": "2.0", "id": req_id, "result": {
                "protocolVersion": self.protocol_version,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": GATEWAY_NAME, "version": GATEWAY_VERSION},
                "instructions": ("Local read-only diagnostic gateway. Data in this release is synthetic fixture data. Use "
                                 "diagnostics.list_capabilities first; tools accept only certified collector ids, registered target "
                                 "aliases and opaque evidence references.")}})
        if method == "ping":
            return self._send({"jsonrpc": "2.0", "id": req_id, "result": {}})
        if self.state != "READY":
            raise GatewayError("E_NOT_INITIALIZED")
        if method == "tools/list":
            return self._send({"jsonrpc": "2.0", "id": req_id, "result": {"tools": tool_list()}})
        if method == "tools/call":
            name, arguments = params.get("name"), params.get("arguments")
            if set(params) - {"name", "arguments"} or not isinstance(name, str) or (arguments is not None and not isinstance(arguments, dict)):
                raise GatewayError("E_INVALID_PARAMS")
            envelope, is_error = self.gateway.call(self.session, name, arguments)
            text = json.dumps(envelope, ensure_ascii=True, sort_keys=True)
            return self._send({"jsonrpc": "2.0", "id": req_id, "result": {
                "content": [{"type": "text", "text": text}], "structuredContent": envelope, "isError": bool(is_error)}})
        return self._error(req_id, METHOD_NOT_FOUND, "E_METHOD_NOT_FOUND")

    # -- loop ---------------------------------------------------------------------------------------
    def serve(self, stdin=None) -> int:
        stream = stdin if stdin is not None else sys.stdin.buffer
        while True:
            line = stream.readline(MAX_MESSAGE_BYTES + 2)
            if not line:
                break                                        # EOF: the client closed stdin — clean exit
            if len(line) > MAX_MESSAGE_BYTES and not line.endswith(b"\n"):
                # oversize line: discard the remainder of it without buffering, answer once
                while True:
                    rest = stream.readline(MAX_MESSAGE_BYTES + 2)
                    if not rest or rest.endswith(b"\n"):
                        break
                self._error(None, INVALID_REQUEST, "E_MESSAGE_TOO_LARGE")
                continue
            line = line.rstrip(b"\r\n")
            if not line.strip():
                continue
            self.handle_line(line)
        if self.session is not None:
            self.gateway.store.clear_session(self.session.scope.session_id)
        return 0
