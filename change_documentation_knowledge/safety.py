"""
change_documentation_knowledge.safety — the Phase 12 sanitization / confinement boundary.

Every string that reaches a JSON/Markdown/manifest/index/error surface goes through this module
first. It layers on top of (never replaces) the Phase 11 public sanitizer API:

  rca_engine.sanitize.deep_sanitize / sanitize_text / contains_secret_pattern

and adds what Phase 12 needs on top of it:
  * strict, prefix-anchored identifier validation (INC/EVD/FND/HYP/RCA/REC/CHG/DOC/KBC/KB/KBV) that
    rejects secret-shaped ids without ever echoing them;
  * single-line normalization of free text (no newline can start a YAML frontmatter / heading /
    list / fence inside a value), Markdown + HTML escaping, blocked URI schemes;
  * an executable-content guard: manual steps are TEXT for a human, never command syntax;
  * instruction-like text detection (prompt-injection markers): untrusted text is DATA and never
    changes a state — it is only flagged;
  * path confinement (no traversal, no symlink escape) and atomic no-overwrite writes.

Fails CLOSED if the Phase 11 sanitizer cannot be imported.
"""
from __future__ import annotations

import json
import os
import re
import tempfile

from .common import AdvisoryError

try:  # fail closed if the Phase 11 sanitizer is not loadable
    from rca_engine.sanitize import (  # noqa: E402
        SanitizationError, contains_secret_pattern, deep_sanitize, sanitize_text,
    )
    # Structured (prefix-anchored) Phase 11 patterns, reused as-is for the output self-audit. They are
    # module-private in rca_engine.sanitize; importing them (instead of copying) keeps one source of
    # truth, and an import failure fails closed like the public API above.
    from rca_engine.sanitize import _CONNECTION_STRING_CREDENTIALS, _KEY_VALUE_SECRET, _STRUCTURED_PATTERNS
    _SANITIZER_OK = True
except Exception:  # pragma: no cover - exercised by a dedicated test through monkeypatching
    _SANITIZER_OK = False
    SanitizationError = ValueError  # type: ignore

MAX_INPUT_BYTES = 2_000_000
MAX_OUTPUT_BYTES = 512_000
MAX_TEXT_LEN = 400
MAX_LIST_ITEMS = 100

_ID_PREFIXES = ("INC", "EVD", "FND", "HYP", "RCA", "REC", "CHG", "DOC", "KBC", "KB", "KBV", "TGT", "SRC", "SIG", "ADV", "REV", "AUTH", "ASM")
_ID_SHAPE = re.compile(r'^(?:%s)-[A-Za-z0-9._-]{1,60}$' % "|".join(_ID_PREFIXES))
_SLUG_SHAPE = re.compile(r'^[A-Za-z][A-Za-z0-9._-]{0,63}$')
# Canonical grammars (repo convention INC-YYYYMMDD-NNN; EVD-<short alnum>; REV-<opaque token>). A
# secret-shaped marker (underscores, long words, mixed punctuation) can never satisfy them.
_STRICT_BODY = {"INC": re.compile(r'^[0-9]{8}-[0-9]{3,4}$'), "EVD": re.compile(r'^[A-Za-z0-9]{1,12}(-[A-Za-z0-9]{1,12}){0,2}$'),
                "REV": re.compile(r'^[A-Za-z0-9]{6,16}$')}
_MAX_ID_SEGMENT = 19  # a >=20-char unbroken word would be treated as a bare secret by Phase 11


def require_sanitizer() -> None:
    if not _SANITIZER_OK:
        raise AdvisoryError("E_SANITIZATION")


# --- identifiers ---------------------------------------------------------------------------------

def is_safe_id(value, prefixes=None) -> bool:
    """Prefix-anchored identifier check. Rejects secret-shaped ids: every '-', '_' or '.'-separated
    segment must be shorter than the bare-secret heuristic threshold and must not itself match a
    Phase 11 secret pattern."""
    require_sanitizer()
    if not isinstance(value, str) or not _ID_SHAPE.match(value):
        return False
    prefix, _, body = value.partition("-")
    if prefixes is not None and prefix not in prefixes:
        return False
    strict = _STRICT_BODY.get(prefix)          # INC / EVD / REV ids have a canonical, narrow grammar
    if strict is not None and not strict.match(body):
        return False
    for seg in re.split(r'[-_.]', value):
        if len(seg) > _MAX_ID_SEGMENT or contains_secret_pattern(seg):
            return False
    return not contains_secret_pattern(value.replace("-", " ").replace("_", " ").replace(".", " "))


def require_id(value, prefixes=None, field: str = None) -> str:
    if not is_safe_id(value, prefixes):
        raise AdvisoryError("E_INPUT_INVALID", field)
    return value


def is_safe_slug(value) -> bool:
    require_sanitizer()
    if not isinstance(value, str) or not _SLUG_SHAPE.match(value):
        return False
    return all(len(s) <= _MAX_ID_SEGMENT and not contains_secret_pattern(s) for s in re.split(r'[-_.]', value))


# --- free text -----------------------------------------------------------------------------------

_CONTROL_CHARS = re.compile(r'[\x00-\x1f\x7f-\x9f  ​-‏‪-‮⁦-⁩﻿]')
_BLOCKED_SCHEMES = re.compile(r'(?i)\b(javascript|vbscript|data|file|ftp|smb|jar)\s*:')
_URL_LIKE = re.compile(r'(?i)\b(?:https?://|www\.)\S+')

# Command-shaped content. English verbs ("restart the listener") are fine — this targets syntax a
# human could paste into a terminal / SQL client, which a manual step must never contain here.
_EXECUTABLE_PATTERNS = [
    re.compile(r'(?i)\b(sudo|srvctl|crsctl|lsnrctl|asmcmd|sqlplus|dgmgrl|rman\s+target|tnsping|systemctl|'
               r'service\s+\w+\s+(start|stop|restart)|kill\s+-\d+|pkill|killall|chmod|chown|chattr|'
               r'rm\s+-[rf]+|mkfs|fdisk|mount\s+-|umount|iptables|ifconfig|nmcli|sysctl\s+-w|'
               r'curl\s+-|wget\s+|nc\s+-|bash\s+-c|sh\s+-c|powershell(\.exe)?\s+-|cmd(\.exe)?\s+/c|'
               r'python\d?\s+-c|eval\s*\(|exec\s*\(|os\.system|subprocess)\b'),
    re.compile(r'(?i)\balter\s+(system|database|session|user|diskgroup|tablespace|profile|pluggable)\b'),
    re.compile(r'(?i)\b(drop|truncate|create|grant|revoke)\s+(table|user|database|tablespace|role|any|public)\b'),
    re.compile(r'(?i)\b(shutdown\s+(immediate|abort|transactional)|startup\s+(nomount|mount|force|open))\b'),
    re.compile(r'(?i)\b(select|insert|update|delete)\b[^.\n]{0,80}\b(from|into|set)\b[^.\n]{0,80}[;$]'),
    re.compile(r'(?i)\bswitchover\s+to\b|\bfailover\s+to\b'),
    re.compile(r'`[^`]{1,200}`|```'),
    re.compile(r'\$\(|`|\|\s*(sh|bash)\b|&&|;\s*(rm|cat|curl|wget)\b'),
]

# Untrusted text that tries to address the agent. It is DATA: flagged, never obeyed.
_INSTRUCTION_MARKERS = re.compile(
    r'(?i)\b(ignore|disregard|forget|override|bypass)\b[^.\n]{0,40}\b(previous|prior|above|all|any|the)\b[^.\n]{0,40}'
    r'\b(instruction|instructions|polic(y|ies)|rules?|guardrails?|constraints?)\b'
    r'|\bsystem\s+prompt\b|\byou\s+are\s+now\b|\bnew\s+instructions?\b|\bas\s+an?\s+(ai|assistant|admin)\b'
    r'|\b(auto[- ]?)?(publish|approve|promote)\s+(this|it|now|immediately)\b|\bmark\s+(it\s+)?(as\s+)?approved\b'
    r'|\brun\s+(this|the\s+following)\s+(command|script|query)\b')


def has_instruction_markers(value) -> bool:
    return isinstance(value, str) and bool(_INSTRUCTION_MARKERS.search(value))


def has_executable_content(value) -> bool:
    return isinstance(value, str) and any(p.search(value) for p in _EXECUTABLE_PATTERNS)


def clean_text(value, max_len: int = MAX_TEXT_LEN, field: str = None) -> str:
    """Sanitized, single-line, bounded text. Non-strings are rejected (fail closed). The Phase 11
    sanitizer runs first; control/bidi characters are then stripped, whitespace collapsed and the
    result truncated. Instruction-like and command-shaped text is NOT rewritten here — callers that
    need to reject/flag it use has_instruction_markers()/has_executable_content()."""
    require_sanitizer()
    if not isinstance(value, str):
        raise AdvisoryError("E_INPUT_INVALID", field)
    try:
        out = sanitize_text(value[:max_len * 4])
    except Exception:
        raise AdvisoryError("E_SANITIZATION", field)
    out = _CONTROL_CHARS.sub(" ", out or "")
    out = re.sub(r'\s+', ' ', out).strip()
    out = _BLOCKED_SCHEMES.sub("[blocked-scheme]:", out)
    out = _URL_LIKE.sub("[url-removed]", out)
    return out[:max_len]


def clean_optional_text(value, max_len: int = MAX_TEXT_LEN, field: str = None):
    if value is None:
        return None
    return clean_text(value, max_len, field)


def sanitize_struct(value):
    """Structural sanitization through the Phase 11 deep sanitizer (depth/size/cycle/type bounded)."""
    require_sanitizer()
    try:
        return deep_sanitize(value)
    except SanitizationError:
        raise AdvisoryError("E_SANITIZATION")
    except RecursionError:
        raise AdvisoryError("E_SANITIZATION")


_HEX_DIGEST = re.compile(r'^[0-9a-f]{64}$')


def contains_structured_secret(text: str) -> bool:
    """Structured-only leak check (no bare-token heuristic): used to self-audit generated artifacts
    that legitimately contain long identifiers/catalog text the broad heuristic would over-redact."""
    require_sanitizer()
    if not isinstance(text, str) or _HEX_DIGEST.match(text):
        return False
    for p in _STRUCTURED_PATTERNS:
        if p is _KEY_VALUE_SECRET:
            # the Phase 11 redaction output ("token=[REDACTED]") still has key=value SHAPE but no value
            if any(not m.group(2).startswith("[REDACTED]") for m in p.finditer(text)):
                return True
        elif p.search(text):
            return True
    return bool(_CONNECTION_STRING_CREDENTIALS.search(text))


def audit_strings(obj, _depth: int = 0) -> None:
    """Fail closed if ANY string (key or value) anywhere in a generated/loaded artifact still looks
    secret-shaped by the structured patterns. Defense in depth run on every artifact right before it
    is written or rendered."""
    if _depth > 12:
        raise AdvisoryError("E_SANITIZATION")
    if isinstance(obj, dict):
        for k, v in obj.items():
            if contains_structured_secret(k):
                raise AdvisoryError("E_SANITIZATION")
            audit_strings(v, _depth + 1)
    elif isinstance(obj, (list, tuple)):
        for v in obj:
            audit_strings(v, _depth + 1)
    elif isinstance(obj, str):
        if contains_structured_secret(obj):
            raise AdvisoryError("E_SANITIZATION")


def audit_rendered(text: str) -> None:
    """Self-audit of rendered text (Markdown/JSON) right before writing. SHA-256 digests are the only
    legitimate long hex strings in our artifacts, so they are removed before the structured check."""
    require_sanitizer()
    stripped = re.sub(r'[0-9a-f]{64}', '', text)
    if contains_structured_secret(stripped):
        raise AdvisoryError("E_SANITIZATION")


def assert_no_secret(text: str, field: str = None) -> None:
    require_sanitizer()
    if contains_secret_pattern(text):
        raise AdvisoryError("E_SANITIZATION", field)


# --- markdown / html escaping --------------------------------------------------------------------

_MD_SPECIALS = re.compile(r'([\\`*\[\]<>#+|~])')
# '_' only opens/closes emphasis at a word boundary; intra-word underscores (ids, enums) stay readable.
_MD_UNDERSCORE = re.compile(r'(?<![A-Za-z0-9])_|_(?![A-Za-z0-9])')


def md_escape(value) -> str:
    """Escape a single-line value for safe inclusion in Markdown prose or a table cell. HTML angle
    brackets, link/image/heading/list/table syntax are all neutralized; '&' is entity-encoded."""
    text = "" if value is None else str(value)
    text = text.replace("&", "&amp;")
    text = _MD_SPECIALS.sub(r'\\\1', text)
    text = _MD_UNDERSCORE.sub(r'\\_', text)
    text = re.sub(r'(?m)^(\s*)([-:.])', r'\1\\\2', text)
    return text


def md_code(value) -> str:
    """Inline code span for tokens/ids that were already validated (no backticks possible)."""
    text = "" if value is None else str(value)
    return "`" + text.replace("`", "'") + "`"


# --- path confinement / IO -----------------------------------------------------------------------

def read_json_file(path: str, max_bytes: int = MAX_INPUT_BYTES):
    """Read + strictly parse a JSON input file. Rejects: missing/dir/oversized files, invalid UTF-8,
    duplicate object keys, NaN/Infinity, non-object/array roots, pathological nesting."""
    if not isinstance(path, str) or not path or "\x00" in path:
        raise AdvisoryError("E_USAGE", "input")
    try:
        if not os.path.isfile(path):
            raise AdvisoryError("E_INPUT_UNREADABLE")
        if os.path.getsize(path) > max_bytes:
            raise AdvisoryError("E_INPUT_TOO_LARGE")
        with open(path, "rb") as f:
            raw = f.read(max_bytes + 1)
    except AdvisoryError:
        raise
    except OSError:
        raise AdvisoryError("E_INPUT_UNREADABLE")
    if len(raw) > max_bytes:
        raise AdvisoryError("E_INPUT_TOO_LARGE")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise AdvisoryError("E_INPUT_INVALID")

    def _no_dupes(pairs):
        keys = [k for k, _ in pairs]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate key")
        return dict(pairs)

    def _no_constants(_name):
        raise ValueError("non-finite number")

    try:
        data = json.loads(text, object_pairs_hook=_no_dupes, parse_constant=_no_constants)
    except (ValueError, RecursionError):
        raise AdvisoryError("E_INPUT_INVALID")
    if not isinstance(data, (dict, list)):
        raise AdvisoryError("E_INPUT_INVALID")
    return data


def _has_symlink_component(root_real: str, target: str) -> bool:
    rel = os.path.relpath(target, root_real)
    cur = root_real
    for part in rel.split(os.sep):
        if part in ("", "."):
            continue
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            return True
    return False


def confine(root: str, *parts: str) -> str:
    """Resolve <root>/<parts...> and prove it stays inside <root>: no '..', no absolute part, no
    symlinked component. Returns the joined path (not the realpath) for writing."""
    if not isinstance(root, str) or not root or "\x00" in root:
        raise AdvisoryError("E_USAGE", "output_dir")
    root_real = os.path.realpath(root)
    for p in parts:
        if not isinstance(p, str) or not p or os.path.isabs(p) or ".." in p.replace("\\", "/").split("/") or "\x00" in p:
            raise AdvisoryError("E_PATH_ESCAPE")
    candidate = os.path.join(root_real, *parts)
    real_candidate = os.path.realpath(candidate)
    try:
        inside = os.path.commonpath([root_real, real_candidate]) == root_real
    except ValueError:
        inside = False
    if not inside or _has_symlink_component(root_real, candidate):
        raise AdvisoryError("E_PATH_ESCAPE")
    return candidate


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Directories that hold managed/published repository content: derived artifacts and the development KB
# must never be written there (no accidental publication, no touching Oracle/production material).
_MANAGED_DIRS = ("agents", "skills", "workflows", "policies", "queries", "config", "docs", "knowledge", "rca_engine",
                 "change_documentation_knowledge", "capacity_engine", "sanitizers", "collectors", "parsers", "mcp",
                 "compatibility", "commands", "templates", "evidence", "playbooks", "analysis", "reports",
                 os.path.join("tests", "fixtures"), ".claude", ".git")


def assert_dev_workdir(path: str, *, is_kb_root: bool = False) -> None:
    """Refuse an output/KB directory that is inside managed repository content, and (for derived-artifact
    output) refuse a directory that is already a KB root (never write derived artifacts into a KB)."""
    if not isinstance(path, str) or not path or "\x00" in path:
        raise AdvisoryError("E_USAGE", "output_dir")
    real = os.path.realpath(path)
    for d in _MANAGED_DIRS:
        base = os.path.realpath(os.path.join(_REPO_ROOT, d))
        if real == base or real.startswith(base + os.sep):
            raise AdvisoryError("E_PATH_ESCAPE")
    if not is_kb_root and os.path.isfile(os.path.join(real, "manifest.json")):
        raise AdvisoryError("E_PATH_ESCAPE")


def ensure_output_dir(output_dir: str) -> str:
    if not isinstance(output_dir, str) or not output_dir or "\x00" in output_dir:
        raise AdvisoryError("E_USAGE", "output_dir")
    if os.path.islink(output_dir):
        raise AdvisoryError("E_PATH_ESCAPE")
    try:
        os.makedirs(output_dir, exist_ok=True)
    except OSError:
        raise AdvisoryError("E_IO")
    return os.path.realpath(output_dir)


def atomic_write_text(path: str, text: str, *, allow_overwrite: bool = False) -> None:
    """Atomic UTF-8 write (temp file in the same directory + os.replace). Refuses to overwrite an
    existing file unless explicitly allowed — approved KB versions never use allow_overwrite."""
    data = text.encode("utf-8")
    if len(data) > MAX_OUTPUT_BYTES:
        raise AdvisoryError("E_OUTPUT_TOO_LARGE")
    if os.path.lexists(path) and not allow_overwrite:
        raise AdvisoryError("E_OUTPUT_EXISTS")
    directory = os.path.dirname(path) or "."
    try:
        os.makedirs(directory, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=".tmp-", suffix=".part", dir=directory)
        try:
            with os.fdopen(fd, "wb") as f:
                f.write(data)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, path)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    except AdvisoryError:
        raise
    except OSError:
        raise AdvisoryError("E_IO")


def dumps_pretty(obj) -> str:
    return json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
