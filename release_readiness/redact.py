"""
release_readiness.redact — personal path redaction for evidence and reports.

Evidence must not carry personal absolute paths. The repository root (in every spelling it can take on
Windows/Git Bash/WSL/POSIX) becomes `<REPO_ROOT>`; any other user-home path becomes `<USER_HOME>`. A
residual scan proves nothing was left: if a personal path survives, the caller must NOT publish the artifact.
"""
from __future__ import annotations

import os
import re

REPO_TOKEN = b"<REPO_ROOT>"
HOME_TOKEN = b"<USER_HOME>"

# Generic personal-home shapes (bytes patterns).
_HOME_PATTERNS = (
    re.compile(rb'[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s"\'<>|*?:]+'),      # C:\Users\name   C:/Users/name
    re.compile(rb'/(?:mnt/)?[a-zA-Z]/Users/[^/\s"\'<>|*?:]+'),           # /c/Users/name   /mnt/c/Users/name
    re.compile(rb'/home/[^/\s"\'<>|*?:]+'),                              # /home/name
    re.compile(rb'/Users/[^/\s"\'<>|*?:]+'),                             # /Users/name (macOS)
)
_RESIDUAL = re.compile(rb'(?:[A-Za-z]:[\\/]+Users[\\/]+|/(?:mnt/)?[a-zA-Z]/Users/|/home/[^<\s]|/Users/[^<\s])')


def root_spellings(root: str) -> list:
    """Every plausible textual form of the repository root, longest first."""
    real = os.path.realpath(root)
    forms = {root, real, root.replace("\\", "/"), real.replace("\\", "/"), root.replace("/", "\\"), real.replace("/", "\\")}
    for spelled in (root, real):                             # Git Bash and WSL spellings of a Windows drive path (as given AND resolved)
        m = re.match(r'^([A-Za-z]):[\\/]+(.*)$', spelled)
        if m:
            drive, rest = m.group(1).lower(), m.group(2).replace("\\", "/")
            forms.update({f"/{drive}/{rest}", f"/mnt/{drive}/{rest}"})
    forms = {f.rstrip("\\/") for f in forms if f}
    return sorted((f.encode("utf-8") for f in forms), key=len, reverse=True)


def redact_bytes(data: bytes, root: str) -> tuple:
    """Return (redacted_bytes, replaced_line_count). Case-insensitive on the drive letter only."""
    out = data
    for form in root_spellings(root):
        pattern = re.compile(re.escape(form), re.IGNORECASE if re.match(rb'^[A-Za-z]:', form) else 0)
        out = pattern.sub(REPO_TOKEN, out)
    for pattern in _HOME_PATTERNS:
        out = pattern.sub(HOME_TOKEN, out)
    before, after = data.split(b"\n"), out.split(b"\n")
    changed = sum(1 for a, b in zip(before, after) if a != b)
    return out, changed


def redact_text(text: str, root: str) -> str:
    return redact_bytes(text.encode("utf-8"), root)[0].decode("utf-8", errors="replace")


def residual_personal_paths(data: bytes) -> int:
    """Number of lines that still contain a personal-path shape (placeholders are ignored)."""
    cleaned = data.replace(REPO_TOKEN, b"").replace(HOME_TOKEN, b"")
    return sum(1 for line in cleaned.split(b"\n") if _RESIDUAL.search(line))
