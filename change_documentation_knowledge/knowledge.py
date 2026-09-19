"""
change_documentation_knowledge.knowledge — KB candidate extraction, quality gate and explainable
duplicate/conflict review (Phase 12).

A KB CANDIDATE is NOT knowledge. Extraction never learns automatically and never promotes a
hypothesis to a fact:
  * only an RCA whose authoritative state is CONFIRMED can produce a candidate that may ever reach
    review; PROBABLE/INCONCLUSIVE/INSUFFICIENT_EVIDENCE yield a REJECTED candidate with an explicit,
    machine-readable reason (the "factual publication block");
  * only CERTIFIED signatures (Phase 11 allowlist) become article symptoms — unrecognized signatures
    are dropped (their tokens are incident-scoped and meaningless outside the incident);
  * the article text is re-anchored on the versioned rules catalog, never on free text from input;
  * scope (Oracle version / RU / platform / architecture) is explicit; unknown scope is UNKNOWN and is
    never treated as "applies everywhere" (no 19c-as-universal);
  * a workaround is never presented as a universal solution: `applies_only_within_scope` is always true.

Duplicate/conflict review uses only safe, normalized keys (family, certified error codes, rule id,
scope) — no embeddings, no external services — and returns an explanation of every compared field.
"""
from __future__ import annotations

import hashlib
import re
from datetime import datetime, timedelta

from .change import DOMAIN_GUIDANCE, parse_change_context
from .common import (
    GENERATOR_VERSION, SCHEMA_VERSION, AdvisoryError, KbState, ReviewStatus, SanitizationStatus,
    content_digest,
)
from .safety import audit_strings, clean_text, has_executable_content, has_instruction_markers, require_id, require_sanitizer
from .schema import req_dict, req_enum, req_list, strict_keys

ARTICLE_TYPES = ("KNOWN_ISSUE", "RUNBOOK", "LESSON", "DIAGNOSTIC_PATTERN")
_CODE = re.compile(r'^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\d{3,6}$')
REVIEW_INTERVAL_DAYS = 365


def _cond_text(cond: dict) -> str:
    return f"{cond['attribute']} {cond['op']} {cond['value']}"


def parse_candidate_input(raw) -> dict:
    """Optional human-provided metadata. Strict; never carries article text (text is catalog-anchored)."""
    require_sanitizer()
    if raw is None:
        return {"article_type": "KNOWN_ISSUE", "owner": "TO_BE_DEFINED", "proposer_ids": [], "supersedes": None}
    r = req_dict(raw, "candidate_input")
    strict_keys(r, {"schema_version"}, {"article_type", "owner", "proposer_ids", "supersedes"}, "candidate_input")
    if r["schema_version"] != SCHEMA_VERSION:
        raise AdvisoryError("E_UNSUPPORTED_SCHEMA_VERSION", "candidate_input.schema_version")
    owner = r.get("owner", "TO_BE_DEFINED")
    if owner != "TO_BE_DEFINED":
        owner = require_id(owner, ("REV",), "candidate_input.owner")
    sup = r.get("supersedes")
    if sup is not None:
        sup = require_id(sup, ("KB",), "candidate_input.supersedes")
    return {"article_type": req_enum(r.get("article_type", "KNOWN_ISSUE"), ARTICLE_TYPES, "candidate_input.article_type"),
            "owner": owner,
            "proposer_ids": [require_id(x, ("REV",), "candidate_input.proposer_ids") for x in req_list(r.get("proposer_ids", []), "candidate_input.proposer_ids", 20)],
            "supersedes": sup}


def dedup_key(article: dict) -> dict:
    """Normalized, safe comparison key. Every component is a certified code, a controlled enum or
    an id from the versioned catalog — never free text."""
    return {"family": article["scope"]["domain"], "rule_id": article["provenance"]["rule_id"],
            "error_codes": sorted(article["error_codes"]),
            "oracle_versions": sorted(article["scope"]["oracle_versions"]),
            "release_update": article["scope"]["release_update"], "platform": article["scope"]["platform"],
            "architecture": {k: article["scope"]["architecture"][k] for k in sorted(article["scope"]["architecture"])},
            "license_dependent": article["prerequisites_and_license"]["license_dependent"]}


def key_id(key: dict) -> str:
    material = repr(sorted((k, repr(v)) for k, v in key.items())).encode("utf-8")
    return "KB-" + hashlib.sha256(material).hexdigest()[:16]


def _scope_key(key: dict) -> tuple:
    return (tuple(key["oracle_versions"]), key["release_update"], key["platform"], repr(sorted(key["architecture"].items())),
            key["license_dependent"])


def _recommendation_digest(article: dict) -> str:
    body = {"cause": article["hypothesis"]["statement"], "recs": article["manual_recommendations"]}
    return hashlib.sha256(repr(body).encode("utf-8")).hexdigest()[:16]


def build_kb_candidate(view: dict, rules_catalog: dict, context_raw, candidate_raw, generated_at: str) -> dict:
    require_sanitizer()
    ctx = parse_change_context(context_raw)
    meta = parse_candidate_input(candidate_raw)
    rc = view["root_cause"]
    catalog = {r["rule_id"]: r for r in rules_catalog.get("rules", [])}
    hyps = {h["hypothesis_id"]: h for h in view["hypotheses"]}
    reasons = []
    if rc["completeness"] != "CONFIRMED":
        reasons.append("RCA_NOT_CONFIRMED")
    subject = None
    if rc["confirmed_hypothesis_ids"]:
        subject = hyps[rc["confirmed_hypothesis_ids"][0]]
    else:  # non-confirmed: keep the leading hypothesis only to make the rejected candidate explainable
        ranked = sorted(view["hypotheses"], key=lambda h: (h["status"] != "SUPPORTED", h["hypothesis_id"]))
        subject = ranked[0] if ranked else None
    if subject is None:
        raise AdvisoryError("E_QUALITY_GATE", "kb.hypothesis")   # no hypothesis at all: nothing to curate
    rule = catalog[subject["rule_id"]]
    guidance = DOMAIN_GUIDANCE[subject["domain"]]
    evidence = sorted(subject["supporting_evidence_ids"])
    if not evidence:
        reasons.append("NO_SUPPORTING_EVIDENCE")
    if view["evidence_manifest"]["completeness"] != "COMPLETE":
        reasons.append("EVIDENCE_MANIFEST_INCOMPLETE")
    if subject["unresolved_critical_contradiction"]:
        reasons.append("UNRESOLVED_CRITICAL_CONTRADICTION")

    certified_codes = sorted({f["canonical_signature"] for f in view["findings"]
                              if f["signature_status"] == "CERTIFIED" and _CODE.match(f["canonical_signature"] or "")
                              and f["domain"] in (subject["domain"], "oracle")}
                             | {c for c in rule["symptom_match"].get("signature_any", []) if _CODE.match(c)
                                and any(f["canonical_signature"] == c for f in view["findings"])})
    dropped = sum(1 for f in view["findings"] if f["signature_status"] != "CERTIFIED" and f["signature_token"])
    recs = [r for r in view["recommendations"] if subject["hypothesis_id"] in r["hypothesis_refs"] or not r["hypothesis_refs"]]
    versions = [ctx["target"]["oracle_version"]] if ctx["target"]["oracle_version"] else ["UNKNOWN"]
    arch = {k: ("UNKNOWN" if v is None else v) for k, v in ctx["target"]["architecture"].items()}
    article = {
        "article_type": meta["article_type"],
        "title": clean_text(f"{subject['domain']}: {subject['statement']}", 160),
        "scope": {"domain": subject["domain"], "oracle_versions": versions,
                  "release_update": ctx["target"]["release_update"] or "UNKNOWN",
                  "platform": ctx["target"]["platform"] or "UNKNOWN", "architecture": arch,
                  "applies_only_within_scope": True,
                  "scope_note": "Scope is explicit; UNKNOWN means not established and is never read as 'applies everywhere'."},
        "error_codes": certified_codes,
        "symptoms_observable": sorted({f"{f['domain']}/{f['event_type']}" + (f" ({f['canonical_signature']})" if f["canonical_signature"] else "")
                                       for f in view["findings"] if f["domain"] in (subject["domain"], "oracle")}),
        "unrecognized_signatures_dropped": dropped,
        "minimal_reproducible_evidence": {
            "evidence_refs": evidence,
            "required_conditions": [_cond_text(c) for c in rule["supporting_conditions"]],
            "contradicting_conditions": [_cond_text(c) for c in rule["contradicting_conditions"]]},
        "hypothesis": {"hypothesis_id": subject["hypothesis_id"], "statement": subject["statement"],
                       "status": subject["status"], "confidence": subject["confidence"],
                       "epistemic": "inferred",
                       "publishable_as_fact": rc["completeness"] == "CONFIRMED" and subject["status"] == "CONFIRMED"},
        "readonly_diagnostics": [r["precheck"] for r in recs if r["precheck"]],
        "interpretation_and_limits": [
            "Interpretation holds only when the required conditions are observed in the CURRENT environment.",
            "This article does not replace current evidence: confirm against the environment before forming an RCA or recommendation.",
            "A correlation in time is not proof of cause; only the linked, confirmed hypothesis is asserted."],
        "manual_recommendations": [{"rec_id": r["rec_id"], "action": r["action_summary"], "risk": r["risk"], "postcheck": r["postcheck"],
                                    "execution_status": "NOT_EXECUTED", "epistemic": "proposed",
                                    "universal_solution": False} for r in recs],
        "prerequisites_and_license": {"license_dependent": guidance["license_dependent"],
                                      "note": guidance.get("license_note", "No licensing dependency identified for this domain; not verified for the target.")},
        "provenance": {"incident_id": view["incident_id"], "rca_id": rc["rca_id"], "rule_id": subject["rule_id"],
                       "hypothesis_ids": [subject["hypothesis_id"]], "evidence_ids": evidence,
                       "finding_ids": [f["finding_id"] for f in view["findings"] if set(f["evidence_ids"]) & set(evidence)],
                       "recommendation_ids": [r["rec_id"] for r in recs], "rca_state_at_extraction": rc["completeness"]},
        "validated_at_utc": generated_at,
        "review_due_utc": (datetime.fromisoformat(generated_at.replace("Z", "+00:00")) + timedelta(days=REVIEW_INTERVAL_DAYS)
                           ).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "owner": meta["owner"], "supersedes": meta["supersedes"], "superseded_by": None,
    }
    if not article["manual_recommendations"]:
        reasons.append("NO_RECOMMENDATION_TO_CURATE")
    for text in (article["title"], *article["readonly_diagnostics"], *(m["action"] for m in article["manual_recommendations"])):
        if has_executable_content(text):
            raise AdvisoryError("E_UNSAFE_CONTENT", "kb.article")
    flagged = has_instruction_markers(" ".join([article["title"]] + article["readonly_diagnostics"]))
    if flagged:
        reasons.append("INSTRUCTION_LIKE_TEXT")

    key = dedup_key(article)
    if "RCA_NOT_CONFIRMED" in reasons:
        state, review = KbState.REJECTED, ReviewStatus.REJECTED
    elif reasons:
        state, review = KbState.DRAFT, ReviewStatus.REVIEW_REQUIRED
    else:
        state, review = KbState.CANDIDATE, ReviewStatus.REVIEW_REQUIRED
    cand = {
        "schema_version": SCHEMA_VERSION, "artifact_type": "kb_candidate",
        "kb_candidate_id": f"KBC-{view['incident_id']}-001", "kb_id": key_id(key), "version": "1",
        "generated_at_utc": generated_at, "generator_version": GENERATOR_VERSION,
        "sanitization_status": SanitizationStatus.SANITIZED, "review_status": review, "lifecycle_state": state,
        "source_refs": {"incident_id": view["incident_id"], "rca_id": rc["rca_id"],
                        "hypothesis_ids": [subject["hypothesis_id"]], "evidence_ids": evidence,
                        "recommendation_ids": [r["rec_id"] for r in recs]},
        "quality_gate": {"status": "PASS" if not reasons else "FAIL", "blocking_reasons": sorted(set(reasons))},
        "proposer_ids": meta["proposer_ids"], "dedup_key": key, "article": article,
        "limitations": view["limitations"] + [
            "A candidate is not knowledge: it requires human review and an externally provided authorization record before publication.",
            "The engine cannot verify the identity of a reviewer."],
    }
    audit_strings(cand)
    cand["content_digest"] = content_digest(cand)
    return cand


# --- quality gate (re-evaluated at every promotion-relevant transition) --------------------------

def quality_gate(cand: dict) -> dict:
    """Deterministic gate on a stored/loaded candidate. Returns {status, blocking_reasons}."""
    reasons = set()
    a = cand["article"]
    if cand["source_refs"]["incident_id"] is None or not a["provenance"]["evidence_ids"]:
        reasons.add("NO_SUPPORTING_EVIDENCE")
    if a["provenance"]["rca_state_at_extraction"] != "CONFIRMED" or not a["hypothesis"]["publishable_as_fact"]:
        reasons.add("RCA_NOT_CONFIRMED")
    if not a["manual_recommendations"]:
        reasons.add("NO_RECOMMENDATION_TO_CURATE")
    if any(m["universal_solution"] for m in a["manual_recommendations"]) or not a["scope"]["applies_only_within_scope"]:
        reasons.add("WORKAROUND_PRESENTED_AS_UNIVERSAL")
    if any(m["execution_status"] != "NOT_EXECUTED" for m in a["manual_recommendations"]):
        reasons.add("EXECUTION_STATUS_NOT_NOT_EXECUTED")
    return {"status": "PASS" if not reasons else "FAIL", "blocking_reasons": sorted(reasons)}


# --- duplicate / conflict review -----------------------------------------------------------------

def review_duplicates(cand: dict, existing: list) -> dict:
    """existing: list of {kb_id, version, state, dedup_key, article_digest, recommendation_digest, cause}.
    Returns an explainable decision:
      NEW | DUPLICATE | SCOPE_DIFFERENCE | CONFLICT | SUPERSESSION_PROPOSED
    DUPLICATE  = same key AND same scope AND same cause/recommendations -> not added (evidence may be cited by a human).
    SCOPE_DIFFERENCE = same family/rule/codes but different version/RU/platform/architecture/license -> NEVER merged.
    CONFLICT   = same key and scope but different cause/recommendation, no declared supersession -> blocks promotion.
    """
    key = cand["dedup_key"]
    art = cand["article"]
    mine = _recommendation_digest(art)
    explanation, matched = [], []
    result = "NEW"
    for e in sorted(existing, key=lambda x: (x["kb_id"], int(x["version"]))):
        if e["state"] in (KbState.RETIRED, KbState.REJECTED):
            continue
        ek = e["dedup_key"]
        same_family = (ek["family"], ek["rule_id"], ek["error_codes"]) == (key["family"], key["rule_id"], key["error_codes"])
        if not same_family:
            continue
        same_scope = _scope_key(ek) == _scope_key(key)
        cmp_row = {"kb_id": e["kb_id"], "version": e["version"], "state": e["state"],
                   "same_family_rule_codes": True, "same_scope": same_scope,
                   "same_cause_and_recommendation": e["recommendation_digest"] == mine}
        explanation.append(cmp_row)
        matched.append(e["kb_id"])
        if not same_scope:
            if result == "NEW":
                result = "SCOPE_DIFFERENCE"
            continue
        if e["recommendation_digest"] == mine:
            result = "DUPLICATE"
        elif art["supersedes"] == e["kb_id"]:
            if result not in ("DUPLICATE", "CONFLICT"):
                result = "SUPERSESSION_PROPOSED"
        else:
            if result != "DUPLICATE":
                result = "CONFLICT"
    return {"result": result, "matched_kb_ids": sorted(set(matched)), "compared": explanation,
            "blocks_promotion": result == "CONFLICT",
            "action": {"NEW": "may be added as DRAFT/CANDIDATE", "DUPLICATE": "not added; a human may cite the new evidence in a reviewed new version",
                       "SCOPE_DIFFERENCE": "added as a separate entry; never merged automatically",
                       "CONFLICT": "added only as DRAFT; promotion blocked until a human resolves the conflict",
                       "SUPERSESSION_PROPOSED": "added as a new version proposal; the previous version stays current until the new one is published with authorization"}[result]}


def recommendation_digest(article: dict) -> str:
    return _recommendation_digest(article)
