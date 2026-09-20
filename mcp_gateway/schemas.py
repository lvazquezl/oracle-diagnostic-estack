"""
mcp_gateway.schemas — strict, dependency-free validation for tool arguments.

The SAME schema dict is (a) published verbatim as the tool's `inputSchema` in `tools/list` (valid JSON
Schema, `additionalProperties: false`) and (b) enforced here on every `tools/call`. Supported keywords:
type (object|string|integer|number|boolean|array), properties, required, additionalProperties(false only),
enum, pattern, minLength, maxLength, minimum, maximum, items, maxItems. Anything else is a schema bug and
fails loudly at registration time (test_p13_unit).

Booleans are never accepted as integers/numbers; NaN/Infinity are rejected; strings are length-bounded and
must be plain (no control characters); patterns are anchored full matches.
"""
from __future__ import annotations

import math
import re

from .common import MAX_ARG_STRING, GatewayError

_ALLOWED_KEYWORDS = {"type", "properties", "required", "additionalProperties", "enum", "pattern", "minLength",
                     "maxLength", "minimum", "maximum", "items", "maxItems", "description"}
_CONTROL = re.compile(r'[\x00-\x1f\x7f-\x9f  ​-‏‪-‮⁦-⁩﻿]')


def check_schema(schema: dict, path: str = "$") -> None:
    """Registration-time sanity: unknown keywords or a permissive object are bugs, not runtime input."""
    if not isinstance(schema, dict):
        raise ValueError(f"{path}: schema must be an object")
    extra = set(schema) - _ALLOWED_KEYWORDS
    if extra:
        raise ValueError(f"{path}: unsupported keyword(s) {sorted(extra)}")
    t = schema.get("type")
    if t not in ("object", "string", "integer", "number", "boolean", "array"):
        raise ValueError(f"{path}: missing/unknown type")
    if t == "object":
        if schema.get("additionalProperties") is not False:
            raise ValueError(f"{path}: objects must declare additionalProperties: false")
        for name, sub in schema.get("properties", {}).items():
            check_schema(sub, f"{path}.{name}")
        if set(schema.get("required", [])) - set(schema.get("properties", {})):
            raise ValueError(f"{path}: required names an undeclared property")
    if t == "string" and "maxLength" not in schema and "enum" not in schema:
        raise ValueError(f"{path}: strings must be length-bounded")
    if t == "array":
        if "maxItems" not in schema or "items" not in schema:
            raise ValueError(f"{path}: arrays must declare items and maxItems")
        check_schema(schema["items"], f"{path}[]")


def validate(value, schema: dict, depth: int = 0):
    """Return the validated value or raise GatewayError('E_ARGS_INVALID'). Never echoes the value."""
    if depth > 6:
        raise GatewayError("E_ARGS_INVALID")
    t = schema["type"]
    if t == "object":
        if not isinstance(value, dict):
            raise GatewayError("E_ARGS_INVALID")
        props = schema.get("properties", {})
        if not all(isinstance(k, str) for k in value):
            raise GatewayError("E_ARGS_INVALID")
        if set(value) - set(props):                 # additionalProperties: false
            raise GatewayError("E_ARGS_INVALID")
        if set(schema.get("required", [])) - set(value):
            raise GatewayError("E_ARGS_INVALID")
        return {k: validate(v, props[k], depth + 1) for k, v in value.items()}
    if t == "string":
        if not isinstance(value, str) or len(value) > min(schema.get("maxLength", MAX_ARG_STRING), MAX_ARG_STRING):
            raise GatewayError("E_ARGS_INVALID")
        if len(value) < schema.get("minLength", 0) or _CONTROL.search(value):
            raise GatewayError("E_ARGS_INVALID")
        if "enum" in schema and value not in schema["enum"]:
            raise GatewayError("E_ARGS_INVALID")
        pat = schema.get("pattern")
        if pat is not None and not re.fullmatch(pat, value):
            raise GatewayError("E_ARGS_INVALID")
        return value
    if t == "integer":
        if isinstance(value, bool) or not isinstance(value, int):
            raise GatewayError("E_ARGS_INVALID")
    elif t == "number":
        if isinstance(value, bool) or not isinstance(value, (int, float)) or (isinstance(value, float) and not math.isfinite(value)):
            raise GatewayError("E_ARGS_INVALID")
    elif t == "boolean":
        if not isinstance(value, bool):
            raise GatewayError("E_ARGS_INVALID")
        return value
    elif t == "array":
        if not isinstance(value, list) or len(value) > schema["maxItems"]:
            raise GatewayError("E_ARGS_INVALID")
        return [validate(v, schema["items"], depth + 1) for v in value]
    if t in ("integer", "number"):
        if "minimum" in schema and value < schema["minimum"]:
            raise GatewayError("E_ARGS_INVALID")
        if "maximum" in schema and value > schema["maximum"]:
            raise GatewayError("E_ARGS_INVALID")
        if "enum" in schema and value not in schema["enum"]:
            raise GatewayError("E_ARGS_INVALID")
    return value
