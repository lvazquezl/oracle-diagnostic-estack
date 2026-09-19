"""
change_documentation_knowledge.kb_store — local Markdown + JSON knowledge base with an explicit,
verifiable lifecycle (Phase 12). Development working directory only.

Layout (under a caller-chosen KB root):
    manifest.json                      mutable state + append-only logical history
    articles/<KB-id>/v<N>.json         immutable article content (canonical, digest-verified)
    articles/<KB-id>/v<N>.md           immutable derived rendering

Guarantees enforced here (and asserted by tests/test_p12_knowledge_*.sh):
  * article files are written once (no overwrite); a change of content is a NEW version;
  * `manifest.json` is updated with an atomic replace; history is append-only (a transition can only
    add an event, never edit one);
  * every transition is validated against common.KB_TRANSITIONS; transitions that are human decisions
    (approve, publish, deprecate, supersede, retire, re-affirm) require an EXTERNAL authorization record
    matching the CURRENT artifact id + digest + version (authorization.verify_authorization). An
    approval for version N is invalid for version N+1 because the digest/version differ;
  * an authorization id is single-use and decisions are chronologically monotonic;
  * quality gate and open conflicts block PENDING_HUMAN_REVIEW / APPROVED / PUBLISHED;
  * the store performs no network access, no subprocess, no git operation, and starts no background job.
    Review-due is metadata + a read-only query (`review_due`); nothing is scheduled.
"""
from __future__ import annotations

import os
import re

from .authorization import verify_authorization
from .common import (
    HUMAN_DECISION_TRANSITIONS, KB_TRANSITIONS, SCHEMA_VERSION, AdvisoryError, KbState, content_digest,
    is_utc_timestamp,
)
from .knowledge import quality_gate, recommendation_digest, review_duplicates
from .safety import (
    MAX_OUTPUT_BYTES, atomic_write_text, audit_strings, confine, dumps_pretty, ensure_output_dir, md_code,
    md_escape, read_json_file, require_id,
)

MANIFEST = "manifest.json"
MAX_ENTRIES = 2000
_KB_ID = re.compile(r'^KB-[0-9a-f]{16}$')
_VERSION = re.compile(r'^[1-9][0-9]{0,3}$')
_GATED = frozenset({KbState.PENDING_HUMAN_REVIEW, KbState.APPROVED_BY_HUMAN, KbState.PUBLISHED})
_OPEN_STATES = frozenset({KbState.CANDIDATE, KbState.DRAFT, KbState.PENDING_HUMAN_REVIEW, KbState.APPROVED_BY_HUMAN,
                          KbState.PUBLISHED, KbState.REVIEW_DUE})


def _article_rel(kb_id: str, version: str, ext: str) -> tuple:
    return ("articles", kb_id, f"v{version}.{ext}")


def _empty_manifest() -> dict:
    return {"schema_version": SCHEMA_VERSION, "artifact_type": "kb_manifest", "entries": {}}


def load_manifest(root: str, create: bool = False) -> dict:
    root_real = ensure_output_dir(root) if create else _existing_root(root)
    path = confine(root_real, MANIFEST)
    if not os.path.isfile(path):
        if create:
            return _empty_manifest()
        raise AdvisoryError("E_KB_NOT_FOUND")
    m = read_json_file(path, MAX_OUTPUT_BYTES * 4)
    if not isinstance(m, dict) or m.get("schema_version") != SCHEMA_VERSION or m.get("artifact_type") != "kb_manifest":
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION" if isinstance(m, dict) and m.get("schema_version") != SCHEMA_VERSION else "E_KB_INTEGRITY")
    entries = m.get("entries")
    if not isinstance(entries, dict) or len(entries) > MAX_ENTRIES:
        raise AdvisoryError("E_KB_INTEGRITY")
    for kb_id, e in entries.items():
        if not _KB_ID.match(kb_id) or not isinstance(e, dict) or not isinstance(e.get("versions"), dict):
            raise AdvisoryError("E_KB_INTEGRITY")
        for v, rec in e["versions"].items():
            if not _VERSION.match(v) or rec.get("state") not in KbState.ALL:
                raise AdvisoryError("E_KB_INTEGRITY")
    return m


def _existing_root(root: str) -> str:
    if not isinstance(root, str) or not root or "\x00" in root or os.path.islink(root) or not os.path.isdir(root):
        raise AdvisoryError("E_KB_NOT_FOUND")
    return os.path.realpath(root)


def _save_manifest(root: str, manifest: dict) -> None:
    audit_strings(manifest)
    atomic_write_text(confine(os.path.realpath(root), MANIFEST), dumps_pretty(manifest), allow_overwrite=True)


def load_article(root: str, manifest: dict, kb_id: str, version: str) -> dict:
    """Load one immutable article and verify its integrity against the manifest (E_KB_INTEGRITY)."""
    try:
        rec = manifest["entries"][kb_id]["versions"][version]
    except KeyError:
        raise AdvisoryError("E_KB_NOT_FOUND")
    root_real = _existing_root(root)
    path = confine(root_real, *_article_rel(kb_id, version, "json"))
    if not os.path.isfile(path):
        raise AdvisoryError("E_KB_INTEGRITY")
    art = read_json_file(path, MAX_OUTPUT_BYTES)
    if not isinstance(art, dict) or content_digest(art) != art.get("content_digest") or art.get("content_digest") != rec.get("digest"):
        raise AdvisoryError("E_KB_INTEGRITY")
    if art.get("kb_id") != kb_id or str(art.get("version")) != version:
        raise AdvisoryError("E_KB_INTEGRITY")
    return art


def _existing_for_review(root, manifest) -> list:
    out = []
    for kb_id, e in manifest["entries"].items():
        for v, rec in e["versions"].items():
            out.append({"kb_id": kb_id, "version": v, "state": rec["state"], "dedup_key": rec["dedup_key"],
                        "recommendation_digest": rec["recommendation_digest"]})
    return out


def render_article_md(art: dict) -> str:
    a = art["article"]
    L = [f"# {md_escape(a['title'])}", "", f"KB entry {md_code(art['kb_id'])} — version {md_escape(art['version'])}", "",
         "> A KB article does not replace current evidence. Confirm against the current environment before forming an RCA or a recommendation. "
         "State (draft/published/deprecated) is recorded in the KB manifest, not in this file.", "",
         "| Field | Value |", "|---|---|"]
    for k, v in (("Type", a["article_type"]), ("Domain", a["scope"]["domain"]),
                 ("Oracle versions", ", ".join(a["scope"]["oracle_versions"])), ("Release update", a["scope"]["release_update"]),
                 ("Platform", a["scope"]["platform"]), ("Certified error codes", ", ".join(a["error_codes"]) or "none"),
                 ("Owner", a["owner"]), ("Validated (UTC)", a["validated_at_utc"]), ("Review due (UTC)", a["review_due_utc"]),
                 ("Supersedes", a["supersedes"] or "none"), ("Content digest", art["content_digest"])):
        L.append(f"| {md_escape(k)} | {md_escape(v)} |")
    def sec(title, items):
        L.extend(["", f"## {title}"])
        L.extend([f"- {md_escape(i)}" for i in items] or ["- _none_"])
    sec("Observable symptoms", a["symptoms_observable"])
    L.extend(["", "## Minimal reproducible evidence",
              f"- Evidence references: {', '.join(md_code(e) for e in a['minimal_reproducible_evidence']['evidence_refs']) or '_none_'}"])
    L.extend([f"- Required condition: {md_escape(c)}" for c in a["minimal_reproducible_evidence"]["required_conditions"]])
    L.extend([f"- Contradicting condition: {md_escape(c)}" for c in a["minimal_reproducible_evidence"]["contradicting_conditions"]])
    h = a["hypothesis"]
    sec("Cause and status", [f"{h['statement']} (status {h['status']}, confidence {h['confidence']}, publishable as fact: {'yes' if h['publishable_as_fact'] else 'NO'})"])
    sec("Read-only diagnostics", a["readonly_diagnostics"])
    sec("Interpretation and limits", a["interpretation_and_limits"])
    sec("Manual recommendations (text for a human; never executed by the e-stack)",
        [f"{m['action']} — risk: {m['risk']}; post-check: {m['postcheck']}" for m in a["manual_recommendations"]])
    sec("Prerequisites and licensing", [f"License dependent: {'yes' if a['prerequisites_and_license']['license_dependent'] else 'no'}. {a['prerequisites_and_license']['note']}"])
    p = a["provenance"]
    sec("Provenance", [f"Incident {p['incident_id']}; RCA {p['rca_id']}; rule {p['rule_id']}",
                       "Hypotheses: " + ", ".join(p["hypothesis_ids"]), "Evidence: " + ", ".join(p["evidence_ids"]),
                       "Findings: " + ", ".join(p["finding_ids"]), "Recommendations: " + ", ".join(p["recommendation_ids"])])
    L.append("")
    return "\n".join(L)


# --- add -----------------------------------------------------------------------------------------

def add_candidate(root: str, cand: dict, generated_at: str) -> dict:
    """Store a candidate as an immutable article version with its initial lifecycle state.
    Returns a result dict; a DUPLICATE is not added."""
    if cand.get("artifact_type") != "kb_candidate" or cand.get("schema_version") != SCHEMA_VERSION:
        raise AdvisoryError("E_INPUT_INVALID", "candidate")
    digest = cand.get("content_digest")
    if content_digest(cand) != digest:
        raise AdvisoryError("E_INPUT_INVALID", "candidate.content_digest")
    audit_strings(cand)
    if cand["lifecycle_state"] not in (KbState.CANDIDATE, KbState.DRAFT):
        raise AdvisoryError("E_QUALITY_GATE")   # REJECTED (e.g. RCA not confirmed) never enters the KB
    kb_id = require_id(cand["kb_id"], ("KB",), "candidate.kb_id")
    manifest = load_manifest(root, create=True)
    review = review_duplicates(cand, _existing_for_review(root, manifest))
    if review["result"] == "DUPLICATE":
        return {"result": "DUPLICATE_NOT_ADDED", "review": review, "kb_id": kb_id}
    art_meta = cand["article"]
    if art_meta["supersedes"] not in (None, kb_id):
        raise AdvisoryError("E_INPUT_INVALID", "candidate.supersedes")
    entry = manifest["entries"].setdefault(kb_id, {"versions": {}})
    if len(manifest["entries"]) > MAX_ENTRIES:
        raise AdvisoryError("E_KB_INTEGRITY")
    version = str(max([int(v) for v in entry["versions"]] or [0]) + 1)
    art = {k: v for k, v in cand.items() if k not in ("lifecycle_state", "review_status", "kb_candidate_id", "quality_gate", "content_digest")}
    art.update({"artifact_type": "kb_article", "version": version, "kb_version_id": f"KBV-{kb_id[3:]}-V{version}",
                "origin_candidate_id": cand["kb_candidate_id"], "generated_at_utc": generated_at})
    art["content_digest"] = content_digest(art)
    audit_strings(art)
    root_real = ensure_output_dir(root)
    jpath = confine(root_real, *_article_rel(kb_id, version, "json"))
    mpath = confine(root_real, *_article_rel(kb_id, version, "md"))
    atomic_write_text(jpath, dumps_pretty(art))                # no overwrite: E_OUTPUT_EXISTS
    atomic_write_text(mpath, render_article_md(art))
    conflict = review["result"] == "CONFLICT"
    entry["versions"][version] = {
        "state": cand["lifecycle_state"], "digest": art["content_digest"], "recommendation_digest": recommendation_digest(art_meta),
        "dedup_key": cand["dedup_key"], "title": art_meta["title"], "article_type": art_meta["article_type"],
        "review_due_utc": art_meta["review_due_utc"], "supersedes": art_meta["supersedes"], "superseded_by_version": None,
        "proposer_ids": list(cand["proposer_ids"]), "origin_incident_id": cand["source_refs"]["incident_id"],
        "history": [{"seq": 1, "from": None, "to": cand["lifecycle_state"], "at_utc": generated_at, "authorization_id": None,
                     "reviewer_id": None, "note": "added from candidate"}],
    }
    _save_manifest(root, manifest)
    return {"result": "ADDED_CONFLICT_OPEN" if conflict else "ADDED", "kb_id": kb_id, "version": version, "review": review,
            "state": cand["lifecycle_state"]}


# --- lifecycle transition ------------------------------------------------------------------------

def _open_conflicts(manifest: dict, kb_id: str, version: str, art: dict) -> list:
    mine = recommendation_digest(art["article"])
    out = []
    for v, rec in manifest["entries"][kb_id]["versions"].items():
        if v == version or rec["state"] not in _OPEN_STATES:
            continue
        if rec["recommendation_digest"] != mine and art["article"]["supersedes"] != kb_id:
            out.append(v)
    return sorted(out)


def transition(root: str, kb_id: str, version: str, to_state: str, at_utc: str, authorization_raw=None) -> dict:
    if not (isinstance(kb_id, str) and _KB_ID.match(kb_id)) or not (isinstance(version, str) and _VERSION.match(version)):
        raise AdvisoryError("E_USAGE", "kb_id")
    if to_state not in KbState.ALL or not is_utc_timestamp(at_utc):
        raise AdvisoryError("E_USAGE", "to_state")
    manifest = load_manifest(root)
    rec = manifest["entries"].get(kb_id, {}).get("versions", {}).get(version)
    if rec is None:
        raise AdvisoryError("E_KB_NOT_FOUND")
    art = load_article(root, manifest, kb_id, version)      # integrity first
    frm = rec["state"]
    if to_state not in KB_TRANSITIONS[frm]:
        raise AdvisoryError("E_TRANSITION_DENIED", "to_state")
    if to_state in _GATED:
        # the gate is evaluated on the immutable article: an RCA that was not CONFIRMED at extraction
        # can never be promoted, whatever text the article (or a reviewer note) contains.
        cand_view = {"source_refs": art["source_refs"], "article": art["article"]}
        gate = quality_gate(cand_view)
        if gate["status"] != "PASS":
            raise AdvisoryError("E_QUALITY_GATE")
        if _open_conflicts(manifest, kb_id, version, art):
            raise AdvisoryError("E_CONFLICT")
    decl = None
    if (frm, to_state) in HUMAN_DECISION_TRANSITIONS:
        history = rec["history"]
        used = {h["authorization_id"] for v in manifest["entries"][kb_id]["versions"].values() for h in v["history"] if h.get("authorization_id")}
        decl = verify_authorization(authorization_raw, artifact_id=kb_id, artifact_digest=rec["digest"], version=version,
                                    proposer_ids=rec["proposer_ids"])
        if decl["authorization_id"] in used:
            raise AdvisoryError("E_AUTH_INVALID", "authorization.authorization_id")     # single use
        prev = [h["decision_at_utc"] for h in history if h.get("decision_at_utc")]
        if prev and decl["decision_at_utc"] < max(prev):
            raise AdvisoryError("E_AUTH_INVALID", "authorization.decision_at_utc")
    event = {"seq": len(rec["history"]) + 1, "from": frm, "to": to_state, "at_utc": at_utc,
             "authorization_id": decl["authorization_id"] if decl else None,
             "reviewer_id": decl["reviewer_id"] if decl else None,
             "decision_at_utc": decl["decision_at_utc"] if decl else None,
             "artifact_digest": decl["artifact_digest"] if decl else None,
             "verification": decl["verification"] if decl else None,
             "review_notes_sanitized": decl["review_notes_sanitized"] if decl else None}
    rec["state"] = to_state
    rec["history"].append(event)
    superseded = None
    if to_state == KbState.PUBLISHED and art["article"]["supersedes"] == kb_id:
        for v, prev_rec in manifest["entries"][kb_id]["versions"].items():
            if v != version and prev_rec["state"] in (KbState.PUBLISHED, KbState.REVIEW_DUE):
                prev_rec["state"] = KbState.SUPERSEDED
                prev_rec["superseded_by_version"] = version
                prev_rec["history"].append({"seq": len(prev_rec["history"]) + 1, "from": KbState.PUBLISHED, "to": KbState.SUPERSEDED,
                                            "at_utc": at_utc, "authorization_id": decl["authorization_id"], "reviewer_id": decl["reviewer_id"],
                                            "decision_at_utc": decl["decision_at_utc"], "artifact_digest": prev_rec["digest"],
                                            "verification": decl["verification"], "review_notes_sanitized": "superseded by publication of a newer authorized version"})
                superseded = v
    _save_manifest(root, manifest)
    return {"kb_id": kb_id, "version": version, "from": frm, "to": to_state, "superseded_version": superseded,
            "authorization_verification": decl["verification"] if decl else None}


# --- read-only queries ---------------------------------------------------------------------------

def review_due(root: str, as_of_utc: str) -> list:
    """Read-only: published entries whose review date has passed. Nothing is changed or scheduled."""
    if not is_utc_timestamp(as_of_utc):
        raise AdvisoryError("E_USAGE", "as_of")
    manifest = load_manifest(root)
    out = []
    for kb_id in sorted(manifest["entries"]):
        for v in sorted(manifest["entries"][kb_id]["versions"], key=int):
            rec = manifest["entries"][kb_id]["versions"][v]
            if rec["state"] in (KbState.PUBLISHED, KbState.REVIEW_DUE) and rec["review_due_utc"] <= as_of_utc:
                out.append({"kb_id": kb_id, "version": v, "state": rec["state"], "review_due_utc": rec["review_due_utc"]})
    return out


def status(root: str) -> dict:
    manifest = load_manifest(root)
    return {"entries": {kb: {v: r["state"] for v, r in sorted(e["versions"].items(), key=lambda x: int(x[0]))}
                        for kb, e in sorted(manifest["entries"].items())}}
