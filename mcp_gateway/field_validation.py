"""CHG-ESTACK-VALIDATION-MATRIX-001 — field validation level of a certified query for ONE target context.

config/field-validation-registry.json records which exact SQL (query_sha256) ran against a real Oracle, in which
context (version family + release update, container, role, RAC/ASM/Data Guard, OS), with evidence refs in an approved
change record. Levels (policies/field-validation-policy.md):

  FIELD_VALIDATED                the same SQL ran in a context that matches the target on every dimension
  FIELD_VALIDATED_OTHER_CONTEXT  the same SQL ran for real, but some dimension differs (listed, never hidden)
  DOCUMENTATION_ONLY             never ran for real, or the SQL changed since it did (stale validation)

Fail closed: an unreadable/invalid registry means DOCUMENTATION_ONLY for everything, never a validated claim.
A target dimension that is not declared (e.g. OS, release update) cannot be compared: it is reported under
`not_compared`, and never turns a mismatch into a match. Stdlib only, no I/O beyond reading the registry once.
"""
import json
import os
import re

from .versions import family_of

REGISTRY_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "field-validation-registry.json")
LEVELS = ("FIELD_VALIDATED", "FIELD_VALIDATED_OTHER_CONTEXT", "DOCUMENTATION_ONLY")
_SHA = re.compile(r"^[0-9a-f]{64}$")
_EVR = re.compile(r"^EVR-[0-9a-f]{24}$")
_RU = re.compile(r"^\d{1,2}\.\d{1,3}$")
_DIMS = ("oracle_version", "container", "role", "rac", "asm", "dataguard", "os")


def _valid(doc) -> bool:
    try:
        ctxs, vals = doc["contexts"], doc["validations"]
        for c in ctxs.values():
            if family_of(c["oracle_version"]) is None or not _RU.match(c["release_update"]):
                return False
            if not all(isinstance(c["architecture"][k], bool) for k in ("rac", "asm", "dataguard")):
                return False
            if not all(isinstance(c["os"][k], str) and c["os"][k] for k in ("family", "distribution", "version")):
                return False
        for v in vals:
            if not (_SHA.match(v["query_sha256"]) and v["context_id"] in ctxs and v["evidence_refs"]
                    and all(_EVR.match(e) for e in v["evidence_refs"]) and v["record"].startswith("docs/")):
                return False
        return True
    except (KeyError, TypeError, AttributeError):
        return False


def load(path: str = REGISTRY_FILE) -> dict:
    try:
        with open(path, encoding="utf-8") as f:
            doc = json.load(f)
    except (OSError, ValueError):
        return {"contexts": {}, "validations": [], "loaded": False}
    if not _valid(doc):
        return {"contexts": {}, "validations": [], "loaded": False}
    doc["loaded"] = True
    return doc


def _ru_tuple(text):
    return tuple(int(p) for p in text.split(".")) if text and _RU.match(text) else None


def _compare(ctx: dict, target) -> tuple:
    """(differences, not_compared) between a validated context and a gateway Target."""
    diff, unknown = [], []
    tv = target.oracle_version
    if tv is None:
        unknown.append("oracle_version")
    elif family_of(ctx["oracle_version"]) != tv:
        diff.append({"dimension": "oracle_version", "validated": ctx["oracle_version"], "target": tv})
    t_ru = getattr(target, "release_update", None)
    if tv is not None and family_of(ctx["oracle_version"]) == tv:
        if _ru_tuple(t_ru) is None:
            unknown.append("release_update")
        elif _ru_tuple(t_ru) < _ru_tuple(ctx["release_update"]):
            diff.append({"dimension": "release_update", "validated": ctx["release_update"], "target": t_ru})
    for dim, tval in (("container", target.container), ("role", target.role)):
        if tval in (None, "UNKNOWN"):
            unknown.append(dim)
        elif tval != ctx[dim]:
            diff.append({"dimension": dim, "validated": ctx[dim], "target": tval})
    arch = target.architecture or {}
    for dim in ("rac", "asm", "dataguard"):
        if not isinstance(arch.get(dim), bool):
            unknown.append(dim)
        elif arch[dim] != ctx["architecture"][dim]:
            diff.append({"dimension": dim, "validated": ctx["architecture"][dim], "target": arch[dim]})
    tos = getattr(target, "os", None) or {}
    if not tos.get("family"):
        unknown.append("os")
    elif (tos.get("family"), tos.get("distribution")) != (ctx["os"]["family"], ctx["os"]["distribution"]):
        diff.append({"dimension": "os", "validated": f'{ctx["os"]["family"]}/{ctx["os"]["distribution"]}',
                     "target": f'{tos.get("family")}/{tos.get("distribution")}'})
    return diff, unknown


def assess(registry: dict, collector, target) -> dict:
    """Field validation of `collector` (its current certified SQL) for `target`. Never raises."""
    qid, sha = getattr(collector, "query_id", None) or getattr(collector, "collector_id", None), getattr(collector, "query_sha256", None)
    out = {"level": "DOCUMENTATION_ONLY", "reason": "NO_FIELD_VALIDATION_RECORDED", "validated_context": None,
           "differences": [], "not_compared": [], "change_ids": [], "evidence_refs": []}
    if getattr(collector, "kind", "sql_query") != "sql_query" or not sha:
        out["reason"] = "NOT_A_CERTIFIED_QUERY"
        return out
    mine = [v for v in registry.get("validations", []) if v["query_id"] == qid]
    if not mine:
        return out
    current = [v for v in mine if v["query_sha256"] == sha]
    if not current:
        out["reason"] = "SQL_CHANGED_SINCE_FIELD_VALIDATION"
        return out
    best = None
    for v in current:
        ctx = registry["contexts"][v["context_id"]]
        diff, unknown = _compare(ctx, target)
        rank = (len(diff), len(unknown))
        if best is None or rank < best[0]:
            best = (rank, v, ctx, diff, unknown)
    _, v, ctx, diff, unknown = best
    out.update({"level": "FIELD_VALIDATED" if not diff else "FIELD_VALIDATED_OTHER_CONTEXT",
                "reason": "CONTEXT_MATCHES" if not diff else "CONTEXT_DIFFERS",
                "validated_context": {"context_id": v["context_id"], "oracle_version": ctx["oracle_version"],
                                      "release_update": ctx["release_update"], "container": ctx["container"],
                                      "role": ctx["role"], "architecture": dict(ctx["architecture"]),
                                      "os": dict(ctx["os"]), "validated_at_utc": v["validated_at_utc"]},
                "differences": diff, "not_compared": unknown,
                "change_ids": sorted({x["change_id"] for x in current}),
                "evidence_refs": sorted({e for x in current for e in x["evidence_refs"]})})
    return out


def assess_all_contexts(registry: dict, collector) -> list:
    """Every validated context of the collector's current SQL (for describe_collector)."""
    sha = getattr(collector, "query_sha256", None)
    qid = getattr(collector, "query_id", None) or getattr(collector, "collector_id", None)
    out = []
    for v in registry.get("validations", []):
        if v["query_id"] == qid and v["query_sha256"] == sha:
            ctx = registry["contexts"][v["context_id"]]
            out.append({"context_id": v["context_id"], "oracle_version": ctx["oracle_version"], "release_update": ctx["release_update"],
                        "container": ctx["container"], "role": ctx["role"], "architecture": dict(ctx["architecture"]),
                        "os": dict(ctx["os"]), "validated_at_utc": v["validated_at_utc"], "change_id": v["change_id"]})
    return out
