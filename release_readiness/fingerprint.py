"""
release_readiness.fingerprint — reproducible identity of the working tree.

The fingerprint covers every file git considers part of the project: tracked files plus untracked files that
are not ignored (so a new, uncommitted file is part of the identity, and `.pyc`/`__pycache__`/local config that
`.gitignore` excludes are not). Each file contributes its SHA-256; a tracked file that was deleted contributes
a DELETED marker; a symlink contributes its target text, never the pointed-to content. The aggregate is the
SHA-256 of the sorted `<sha256>  <path>` manifest, so it does not depend on HEAD: the same files give the same
fingerprint before and after a commit.

Identity is proven by comparing a fingerprint taken BEFORE a run with one taken AFTER it. Nothing here proves
the tree was unchanged at any instant in between — only that it is the same at both ends.
"""
from __future__ import annotations

import os

from .common import ReadinessError, sha256_bytes, sha256_file
from .runner import git

ALGORITHM = "sha256-of-sorted-manifest/v1"
_SKIP_TOP = (".git",)


def _split_z(raw: bytes) -> list:
    return [p.decode("utf-8", errors="surrogateescape") for p in raw.split(b"\0") if p]


def list_project_files(root: str) -> tuple:
    """(existing_paths, deleted_tracked_paths), repo-relative with forward slashes, sorted."""
    tracked = set(_split_z(git(root, "ls-files", "-z").stdout))
    untracked = set(_split_z(git(root, "ls-files", "-z", "--others", "--exclude-standard").stdout))
    existing, deleted = [], []
    for rel in sorted(tracked | untracked):
        if rel.split("/", 1)[0] in _SKIP_TOP:
            continue
        full = os.path.join(root, rel)
        if os.path.lexists(full):
            existing.append(rel)
        else:
            deleted.append(rel)
    return existing, deleted


def _entry(root: str, rel: str) -> str:
    full = os.path.join(root, rel)
    try:
        if os.path.islink(full):
            return "symlink:" + sha256_bytes(os.readlink(full).encode("utf-8", errors="surrogateescape"))
        if os.path.isdir(full):
            return "directory"                               # e.g. a gitlink/submodule placeholder
        return sha256_file(full)
    except OSError:
        return "UNREADABLE"


def aggregate(entries: dict) -> str:
    lines = "".join(f"{entries[p]}  {p}\n" for p in sorted(entries))
    return sha256_bytes(lines.encode("utf-8", errors="surrogateescape"))


def take(root: str) -> dict:
    """{algorithm, file_count, deleted_count, aggregate_sha256, entries{path: sha}} for the working tree at `root`."""
    if not isinstance(root, str) or not os.path.isdir(root):
        raise ReadinessError("E_ROOT")
    existing, deleted = list_project_files(root)
    entries = {rel: _entry(root, rel) for rel in existing}
    for rel in deleted:
        entries[rel] = "DELETED"
    return {"algorithm": ALGORITHM, "file_count": len(existing), "deleted_count": len(deleted),
            "aggregate_sha256": aggregate(entries), "entries": entries}


def verify_self_consistency(fp: dict) -> bool:
    """The stated aggregate must be recomputable from the stated entries (detects a hand-edited fingerprint)."""
    try:
        entries = fp["entries"]
        return (fp.get("algorithm") == ALGORITHM and isinstance(entries, dict)
                and all(isinstance(k, str) and isinstance(v, str) for k, v in entries.items())
                and fp["aggregate_sha256"] == aggregate(entries)
                and fp["file_count"] == sum(1 for v in entries.values() if v != "DELETED")
                and fp["deleted_count"] == sum(1 for v in entries.values() if v == "DELETED"))
    except (KeyError, TypeError):
        return False


def diff(a: dict, b: dict) -> dict:
    """Paths added / removed / changed between two fingerprints (entries maps)."""
    ea, eb = a["entries"], b["entries"]
    return {"added": sorted(set(eb) - set(ea)), "removed": sorted(set(ea) - set(eb)),
            "changed": sorted(p for p in set(ea) & set(eb) if ea[p] != eb[p])}
