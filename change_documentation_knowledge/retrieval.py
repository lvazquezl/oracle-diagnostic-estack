"""
change_documentation_knowledge.retrieval — local, read-only knowledge search (Phase 12).

Design constraints (see docs/PHASE_12_*.md, "Retrieval"):
  * the query is DATA: it is sanitized, reduced to lowercase alphanumeric/hyphen terms and matched by
    plain string comparison. It is never used as a path, regex, glob, SQL, shell or template, and it is
    never echoed back in the output;
  * only files declared by the manifest are opened, each confined to the KB root (no traversal, no
    symlinks, size-bounded) and integrity-verified — an unlisted file is never read;
  * PUBLISHED and REVIEW_DUE are the only "current guidance" states. DRAFT/CANDIDATE/PENDING/APPROVED
    appear only when explicitly requested and are labelled `current_guidance: false`; DEPRECATED and
    SUPERSEDED likewise; RETIRED (and REJECTED) are never returned;
  * a result never claims to replace current evidence, and an empty result is the explicit status
    NO_CERTIFIED_MATCH — nothing is invented.
"""
from __future__ import annotations

import re

from .common import SCHEMA_VERSION, AdvisoryError, KbState
from .kb_store import load_article, load_manifest
from .safety import clean_text, require_sanitizer

MAX_TOP_K = 20
DEFAULT_TOP_K = 5
MAX_QUERY_LEN = 200
_TERM = re.compile(r'[a-z0-9][a-z0-9-]{1,40}')
_NEVER_RETURNED = frozenset({KbState.RETIRED, KbState.REJECTED})
_NOTICE = ("A KB article does not replace current evidence: confirm against the current environment "
           "before forming an RCA or a recommendation.")


def _terms(query: str) -> list:
    q = clean_text(query, MAX_QUERY_LEN, "query").lower()
    return sorted(set(_TERM.findall(q)))[:12]


def _haystack(art: dict) -> set:
    a = art["article"]
    words = " ".join([a["title"], a["hypothesis"]["statement"], " ".join(a["symptoms_observable"]),
                      " ".join(a["error_codes"])]).lower()
    return set(_TERM.findall(words))


def search(root: str, query: str, *, domain: str = None, version: str = None, error_code: str = None,
           article_type: str = None, architecture: str = None, exclude_license_dependent: bool = False,
           validated_after_utc: str = None, states=None, top_k: int = DEFAULT_TOP_K) -> dict:
    require_sanitizer()
    if not isinstance(top_k, int) or isinstance(top_k, bool) or not (1 <= top_k <= MAX_TOP_K):
        raise AdvisoryError("E_USAGE", "top_k")
    wanted_states = set(states) if states else set(KbState.CURRENT_GUIDANCE)
    if not wanted_states <= KbState.ALL:
        raise AdvisoryError("E_USAGE", "states")
    wanted_states -= _NEVER_RETURNED
    terms = _terms(query) if query else []
    code = error_code.upper() if isinstance(error_code, str) else None
    if code is not None and not re.match(r'^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\d{3,6}$', code):
        raise AdvisoryError("E_USAGE", "error_code")
    if not query and not code:
        raise AdvisoryError("E_USAGE", "query")     # a non-empty query with no usable terms is simply NO_CERTIFIED_MATCH
    manifest = load_manifest(root)
    hits = []
    for kb_id in sorted(manifest["entries"]):
        for v, rec in manifest["entries"][kb_id]["versions"].items():
            state = rec["state"]
            if state not in wanted_states:
                continue
            art = load_article(root, manifest, kb_id, v)
            a = art["article"]
            sc = a["scope"]
            if domain and sc["domain"] != domain:
                continue
            if version and version not in sc["oracle_versions"]:      # UNKNOWN scope never matches an explicit version
                continue
            if article_type and a["article_type"] != article_type:
                continue
            if architecture and sc["architecture"].get(architecture) is not True:
                continue
            if exclude_license_dependent and a["prerequisites_and_license"]["license_dependent"]:
                continue
            if validated_after_utc and a["validated_at_utc"] < validated_after_utc:
                continue
            matched = []
            if code:
                if code not in a["error_codes"]:
                    continue
                matched.append(f"error_code:{code}")
            hay = _haystack(art)
            term_hits = [t for t in terms if t in hay]
            if not term_hits and not code:
                continue
            matched += [f"term:{t}" for t in term_hits]
            current = state in KbState.CURRENT_GUIDANCE
            hits.append({
                "kb_id": kb_id, "version": v, "status": state, "current_guidance": current,
                "certified": current, "title": a["title"], "scope": sc, "article_type": a["article_type"],
                "error_codes": a["error_codes"],
                "evidence_citation": {"incident_id": a["provenance"]["incident_id"], "rca_id": a["provenance"]["rca_id"],
                                      "evidence_ids": a["provenance"]["evidence_ids"], "hypothesis_ids": a["provenance"]["hypothesis_ids"],
                                      "finding_ids": a["provenance"]["finding_ids"]},
                "validated_at_utc": a["validated_at_utc"], "review_due_utc": a["review_due_utc"],
                "matched": sorted(matched), "match_count": len(matched),
                "warning": None if current else "NOT current guidance: state is " + state + "; do not apply without human review",
            })
    hits.sort(key=lambda h: (-h["match_count"], not h["current_guidance"], h["kb_id"], int(h["version"])))
    hits = hits[:top_k]
    certified = [h for h in hits if h["certified"]]
    return {"schema_version": SCHEMA_VERSION, "artifact_type": "kb_search_result",
            "status": "MATCH" if certified else "NO_CERTIFIED_MATCH",   # uncertified hits (explicitly requested) never count
            "top_k": top_k, "query_term_count": len(terms), "results": hits, "notice": _NOTICE}
