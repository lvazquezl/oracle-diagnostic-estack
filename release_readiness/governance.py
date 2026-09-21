"""
release_readiness.governance — validators for e-stack evolution records and the risk register.

Lifecycle of an e-stack artifact (agent, skill, query, workflow, policy, knowledge, adapter, MCP tool, documentation):

    PROPOSED -> REVIEWED -> APPROVED -> RELEASED -> DEPRECATED -> RETIRED        (REVIEWED may return to PROPOSED)

Rules enforced here (each has a test):
  * transitions are single legal steps; the history is the proof and must end in the current state;
  * segregation of duties: the reviewer/approver is never the proposer;
  * post-approval states need a review record, a release-gate reference and evidence references;
  * urgent changes still need approval and a post-review due date; exceptions need a risk id, compensating
    controls, a different approver and an expiry (<= 90 days); expired exceptions/revalidations are findings;
  * an approval is ALWAYS `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: this repository has no authentication or
    signature mechanism, so a record is a declaration, never proof of who decided. Nothing here approves,
    promotes, merges, tags or publishes anything; it only VALIDATES records a human supplied.
"""
from __future__ import annotations

import re
from datetime import timedelta

from .common import ReadinessError, now_utc, parse_utc

STATES = ("PROPOSED", "REVIEWED", "APPROVED", "RELEASED", "DEPRECATED", "RETIRED")
NEXT = {"PROPOSED": {"REVIEWED"}, "REVIEWED": {"APPROVED", "PROPOSED"}, "APPROVED": {"RELEASED"}, "RELEASED": {"DEPRECATED"},
        "DEPRECATED": {"RETIRED"}, "RETIRED": set()}
POST_APPROVAL = ("APPROVED", "RELEASED", "DEPRECATED", "RETIRED")
POST_RELEASE = ("RELEASED", "DEPRECATED", "RETIRED")
ARTIFACT_TYPES = ("agent", "skill", "query", "workflow", "policy", "knowledge", "adapter", "mcp_tool", "documentation", "tooling")
CHANGE_CLASSES = ("NORMAL", "URGENT", "EXCEPTION")
VERIFICATION = "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"
MAX_EXCEPTION_DAYS = 90

_REC = re.compile(r'^GOV-[A-Z0-9-]{3,40}\Z')
_REV = re.compile(r'^REV-[A-Za-z0-9-]{3,40}\Z')
_SEMVER = re.compile(r'^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}\Z')
_ARTIFACT_ID = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_./:-]{2,80}\Z')
_ROLE = re.compile(r'^[a-z]{2,20}(-[a-z]{2,20}){1,3}\Z')          # a compound role slug (dba-lead); a single word looks like a person
_RISK = re.compile(r'^RSK-[0-9]{3}\Z')
_RELEASE_REF = re.compile(r'^(RUN-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}|docs/[A-Za-z0-9_./-]{3,80})\Z')
_EVIDENCE_REF = re.compile(r'^(EVD|FND|HYP|RCA|REC|CHG|INC|ANA|KB)-[A-Za-z0-9-]{3,40}$|^[A-Za-z0-9_./-]{3,120}\Z')
_REQUIRED = {"record_id", "artifact_type", "artifact_id", "semver", "state", "change_class", "owner_role", "proposer_id", "sources",
             "evidence_refs", "compatibility", "history", "revalidate_by_utc"}
_OPTIONAL = {"review", "release_gate_ref", "urgent", "exception"}
_RISK_REQUIRED = {"risk_id", "title", "description", "likelihood", "impact", "status", "owner_role", "mitigation", "closure_condition"}
_RISK_OPTIONAL = {"residual_notes", "acceptance"}
LEVELS = ("LOW", "MEDIUM", "HIGH")
RISK_STATUS = ("OPEN", "MITIGATED", "ACCEPTED", "CLOSED")


def _f(out: list, code: str, rec, detail: str = "") -> None:
    out.append({"code": code, "record": rec if isinstance(rec, str) else "?", "detail": detail})


def _strs(v, lo=0, hi=20, maxlen=200) -> bool:
    return isinstance(v, list) and lo <= len(v) <= hi and all(isinstance(x, str) and 0 < len(x) <= maxlen for x in v)


def validate_record(rec, now: str = None) -> list:
    """Findings (list of {code, record, detail}) for ONE lifecycle record. Empty list = valid."""
    out, now_dt = [], parse_utc(now or now_utc())
    rid = rec.get("record_id") if isinstance(rec, dict) else None
    if not isinstance(rec, dict) or (_REQUIRED - set(rec)) or (set(rec) - _REQUIRED - _OPTIONAL):
        _f(out, "GOV_SCHEMA", rid, "record keys differ from the schema")
        return out
    if not (isinstance(rec["record_id"], str) and _REC.match(rec["record_id"])):
        _f(out, "GOV_ID", rid)
    if rec["artifact_type"] not in ARTIFACT_TYPES:
        _f(out, "GOV_ARTIFACT_TYPE", rid)
    if not (isinstance(rec["artifact_id"], str) and _ARTIFACT_ID.match(rec["artifact_id"])):
        _f(out, "GOV_ARTIFACT_ID", rid)
    if not (isinstance(rec["semver"], str) and _SEMVER.match(rec["semver"])):
        _f(out, "GOV_SEMVER", rid)
    if rec["state"] not in STATES:
        _f(out, "GOV_STATE", rid)
        return out
    if rec["change_class"] not in CHANGE_CLASSES:
        _f(out, "GOV_CHANGE_CLASS", rid)
    if not (isinstance(rec["owner_role"], str) and _ROLE.match(rec["owner_role"])):
        _f(out, "GOV_OWNER_ROLE", rid, "ownership is by role, not by person")
    proposer = rec["proposer_id"]
    if not (isinstance(proposer, str) and _REV.match(proposer)):
        _f(out, "GOV_PROPOSER", rid)
    if not _strs(rec["sources"], 1, 10):
        _f(out, "GOV_SOURCES", rid, "at least one source is required")
    ev = rec["evidence_refs"]
    if not (isinstance(ev, list) and len(ev) <= 30 and all(isinstance(x, str) and _EVIDENCE_REF.match(x) for x in ev)):
        _f(out, "GOV_EVIDENCE_REFS", rid)
    comp = rec["compatibility"]
    if not (isinstance(comp, dict) and set(comp) == {"oracle_versions", "platforms", "breaking"} and isinstance(comp["breaking"], bool)
            and _strs(comp["oracle_versions"], 0, 10, 20) and _strs(comp["platforms"], 0, 10, 20)):
        _f(out, "GOV_COMPATIBILITY", rid, "compatibility must declare oracle_versions, platforms and breaking")
    revalidate = parse_utc(rec["revalidate_by_utc"])
    if revalidate is None:
        _f(out, "GOV_REVALIDATE_TIMESTAMP", rid)
    elif rec["state"] in ("APPROVED", "RELEASED") and now_dt and now_dt > revalidate:
        _f(out, "GOV_REVALIDATION_OVERDUE", rid, "revalidation date has passed")

    # history
    hist = rec["history"]
    steps, ok_hist = [], isinstance(hist, list) and 1 <= len(hist) <= 20
    if ok_hist:
        prev_state, prev_dt = None, None
        for h in hist:
            if not (isinstance(h, dict) and set(h) == {"state", "at_utc", "actor_id"} and h["state"] in STATES and parse_utc(h["at_utc"])
                    and isinstance(h["actor_id"], str) and _REV.match(h["actor_id"])):
                ok_hist = False
                break
            dt = parse_utc(h["at_utc"])
            if prev_state is None:
                if h["state"] != "PROPOSED" or h["actor_id"] != proposer:
                    ok_hist = False
                    break
            else:
                if h["state"] not in NEXT[prev_state] or dt < prev_dt:
                    _f(out, "GOV_TRANSITION_ILLEGAL", rid, f"{prev_state} -> {h['state']}")
                    ok_hist = False
                    break
            prev_state, prev_dt = h["state"], dt
            steps.append(h)
        if ok_hist and steps[-1]["state"] != rec["state"]:
            _f(out, "GOV_HISTORY_STATE_MISMATCH", rid, "the last history entry is not the current state")
            ok_hist = False
    if not ok_hist and not any(o["code"] == "GOV_TRANSITION_ILLEGAL" for o in out):
        _f(out, "GOV_HISTORY", rid, "history is malformed, does not start at PROPOSED by the proposer, or is out of order")

    # segregation of duties, review record
    def actor(state):
        return next((h["actor_id"] for h in steps if h["state"] == state), None)
    if ok_hist:
        for st in ("REVIEWED", "APPROVED"):
            if actor(st) is not None and actor(st) == proposer:
                _f(out, "GOV_SELF_APPROVAL", rid, f"the proposer performed the {st} step")
    if rec["state"] in POST_APPROVAL:
        rv = rec.get("review")
        good = (isinstance(rv, dict) and set(rv) == {"reviewer_id", "decision", "decision_at_utc", "verification"}
                and rv["decision"] == "APPROVED" and parse_utc(rv["decision_at_utc"]) and isinstance(rv["reviewer_id"], str) and _REV.match(rv["reviewer_id"]))
        if not good:
            _f(out, "GOV_REVIEW_MISSING", rid, "a review record is required from APPROVED onward")
        else:
            if rv["verification"] != VERIFICATION:
                _f(out, "GOV_VERIFICATION_OVERSTATED", rid, "approvals are structural only; no authentication exists")
            if rv["reviewer_id"] == proposer:
                _f(out, "GOV_SELF_APPROVAL", rid, "the reviewer is the proposer")
            if ok_hist and actor("APPROVED") != rv["reviewer_id"]:
                _f(out, "GOV_REVIEWER_NOT_IN_HISTORY", rid)
    elif "review" in rec:
        _f(out, "GOV_REVIEW_PREMATURE", rid, "a review decision cannot exist before APPROVED")
    if rec["state"] in POST_RELEASE:
        if not (isinstance(rec.get("release_gate_ref"), str) and _RELEASE_REF.match(rec["release_gate_ref"])):
            _f(out, "GOV_RELEASE_GATE_REF_MISSING", rid, "release needs a reference to the passed release gate")
        if not ev:
            _f(out, "GOV_EVIDENCE_MISSING_FOR_RELEASE", rid)
    elif "release_gate_ref" in rec:
        _f(out, "GOV_RELEASE_REF_PREMATURE", rid)

    # change classes
    cls = rec["change_class"]
    if cls == "URGENT":
        u = rec.get("urgent")
        if not (isinstance(u, dict) and {"justification", "post_review_due_utc"} <= set(u) and set(u) <= {"justification", "post_review_due_utc", "post_review_completed_utc"}
                and isinstance(u["justification"], str) and 10 <= len(u["justification"]) <= 300 and parse_utc(u["post_review_due_utc"])):
            _f(out, "GOV_URGENT_INCOMPLETE", rid, "urgent changes need a justification and a post-review due date")
        elif now_dt and "post_review_completed_utc" not in u and now_dt > parse_utc(u["post_review_due_utc"]):
            _f(out, "GOV_URGENT_POST_REVIEW_OVERDUE", rid)
    elif "urgent" in rec:
        _f(out, "GOV_URGENT_UNEXPECTED", rid)
    if cls == "EXCEPTION":
        e = rec.get("exception")
        good = (isinstance(e, dict) and set(e) == {"risk_id", "scope", "expires_at_utc", "compensating_controls", "approver_id"}
                and isinstance(e["risk_id"], str) and _RISK.match(e["risk_id"]) and isinstance(e["scope"], str) and 5 <= len(e["scope"]) <= 200
                and parse_utc(e["expires_at_utc"]) and _strs(e["compensating_controls"], 1, 10) and isinstance(e["approver_id"], str) and _REV.match(e["approver_id"]))
        if not good:
            _f(out, "GOV_EXCEPTION_INCOMPLETE", rid, "exceptions need risk id, scope, compensating controls, approver and expiry")
        else:
            if e["approver_id"] == proposer:
                _f(out, "GOV_SELF_APPROVAL", rid, "the exception approver is the proposer")
            exp = parse_utc(e["expires_at_utc"])
            base = parse_utc(rec["review"]["decision_at_utc"]) if isinstance(rec.get("review"), dict) and parse_utc(rec["review"].get("decision_at_utc")) else None
            if base is not None and not (base < exp <= base + timedelta(days=MAX_EXCEPTION_DAYS)):
                _f(out, "GOV_EXCEPTION_DURATION", rid, f"an exception may last at most {MAX_EXCEPTION_DAYS} days from the decision")
            if now_dt and now_dt > exp:
                _f(out, "GOV_EXCEPTION_EXPIRED", rid)
    elif "exception" in rec:
        _f(out, "GOV_EXCEPTION_UNEXPECTED", rid)
    return out


def validate_records_document(doc, now: str = None) -> list:
    if not isinstance(doc, dict) or doc.get("schema_version") != "1.0.0" or not isinstance(doc.get("records"), list) or set(doc) != {"schema_version", "records"}:
        return [{"code": "GOV_DOCUMENT_SCHEMA", "record": "?", "detail": "records document malformed"}]
    out, seen = [], set()
    for rec in doc["records"]:
        out += validate_record(rec, now)
        rid = rec.get("record_id") if isinstance(rec, dict) else None
        if rid in seen:
            _f(out, "GOV_DUPLICATE_ID", rid)
        seen.add(rid)
    return out


def apply_transition(rec: dict, to_state: str, actor_id: str, at_utc: str, review: dict = None, release_gate_ref: str = None) -> tuple:
    """Pure function: (new_record, findings) for a requested transition. Nothing is stored or approved; a review
    record must be supplied by the caller (it is never fabricated here)."""
    new = {k: (list(v) if isinstance(v, list) else dict(v) if isinstance(v, dict) else v) for k, v in rec.items()}
    new["history"] = list(rec["history"]) + [{"state": to_state, "at_utc": at_utc, "actor_id": actor_id}]
    new["state"] = to_state
    if review is not None:
        new["review"] = review
    if release_gate_ref is not None:
        new["release_gate_ref"] = release_gate_ref
    return new, validate_record(new, at_utc)


def validate_risk_register(doc, now: str = None) -> list:
    out, now_dt = [], parse_utc(now or now_utc())
    if not isinstance(doc, dict) or doc.get("schema_version") != "1.0.0" or set(doc) != {"schema_version", "risks"} or not isinstance(doc["risks"], list) or not doc["risks"]:
        return [{"code": "RISK_DOCUMENT_SCHEMA", "record": "?", "detail": "risk register malformed or empty"}]
    seen = set()
    for r in doc["risks"]:
        rid = r.get("risk_id") if isinstance(r, dict) else None
        if not isinstance(r, dict) or (_RISK_REQUIRED - set(r)) or (set(r) - _RISK_REQUIRED - _RISK_OPTIONAL):
            _f(out, "RISK_SCHEMA", rid, "risk keys differ from the schema")
            continue
        if not (isinstance(rid, str) and _RISK.match(rid)) or rid in seen:
            _f(out, "RISK_ID", rid, "risk id malformed or duplicated")
        seen.add(rid)
        for k in ("title", "description", "mitigation", "closure_condition"):
            if not (isinstance(r[k], str) and 5 <= len(r[k]) <= 500):
                _f(out, "RISK_TEXT", rid, f"{k} is required")
        if r["likelihood"] not in LEVELS or r["impact"] not in LEVELS:
            _f(out, "RISK_LEVEL", rid)
        if r["status"] not in RISK_STATUS:
            _f(out, "RISK_STATUS", rid)
        if not (isinstance(r["owner_role"], str) and _ROLE.match(r["owner_role"])):
            _f(out, "RISK_OWNER_ROLE", rid, "ownership is by role, not by person")
        if r["status"] == "ACCEPTED":
            a = r.get("acceptance")
            if not (isinstance(a, dict) and set(a) == {"accepted_by_role", "accepted_at_utc", "expires_at_utc"} and isinstance(a["accepted_by_role"], str)
                    and _ROLE.match(a["accepted_by_role"]) and parse_utc(a["accepted_at_utc"]) and parse_utc(a["expires_at_utc"])):
                _f(out, "RISK_ACCEPTANCE_INCOMPLETE", rid, "an accepted risk needs role, date and expiry")
            elif now_dt and now_dt > parse_utc(a["expires_at_utc"]):
                _f(out, "RISK_ACCEPTANCE_EXPIRED", rid)
        elif "acceptance" in r:
            _f(out, "RISK_ACCEPTANCE_UNEXPECTED", rid)
    return out
