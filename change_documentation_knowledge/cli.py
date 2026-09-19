"""
change_documentation_knowledge.cli — local adapter for the Phase 12 pipeline.

    python -m change_documentation_knowledge.cli <command> [options]

Commands
  advise        RCA result (or synthetic incident fixture run through the REAL rca_engine) -> change
                advisory (JSON + Markdown), or an e-stack governance report with --mode estack
  document      -> one of: rca | executive | change | assessment | post-incident
  kb-candidate  -> KB candidate (JSON). A candidate is NOT knowledge.
  kb-add        store a candidate as an immutable article version in a local KB directory
  kb-transition move one article version through the lifecycle. Approvals / publication / retirement
                require an EXTERNAL authorization record (--authorization FILE) that matches the
                current artifact digest and version. The CLI has no option that approves or
                publishes by itself, and no environment-variable approval.
  kb-search     read-only local search (NO_CERTIFIED_MATCH when nothing certified matches)
  kb-status     read-only lifecycle state listing;  kb-review-due  read-only review-date query

Runtime status: LOCAL_RUNTIME_TESTED (exercised by tests/test_p12_*.sh). The slash commands
(/change, /document, /knowledge) describe orchestration by an agent runtime that does not exist
until the MCP Gateway phase; this CLI is the only executable path today.

Safety: the CLI never runs SQL, shell, RMAN, srvctl/crsctl or any command; never touches git; never
approves anything; writes only inside --output-dir / --kb-root; refuses to overwrite; error messages
are fixed strings that never echo input (exit codes: 2 usage, 3 input/contract, 4 safety, 5 governance,
6 knowledge base, 7 I/O, 70 internal).
"""
from __future__ import annotations

import argparse
import hashlib
import sys

from .authorization import parse_authorization  # noqa: F401  (import check: fail closed early)
from .change import build_change_advisory, build_estack_change, render_change_advisory_md
from .common import ERROR_MESSAGES, GENERATOR_VERSION, SCHEMA_VERSION, AdvisoryError, KbState, resolve_generated_at
from .documents import (
    build_assessment_report, build_change_report, build_executive_summary, build_post_incident_review,
    build_rca_report, render_document_md, validate_advisory,
)
from .kb_store import add_candidate, load_manifest, review_due, status as kb_status_fn, transition
from .knowledge import build_kb_candidate
from .retrieval import DEFAULT_TOP_K, search
from .safety import (
    assert_dev_workdir, atomic_write_text, audit_rendered, audit_strings, confine, dumps_pretty, ensure_output_dir, read_json_file, require_sanitizer,
)
from .schema import adapt_rca_result

_EXIT = {"E_USAGE": 2, "E_INPUT_UNREADABLE": 3, "E_INPUT_TOO_LARGE": 3, "E_INPUT_INVALID": 3,
         "E_UNSUPPORTED_SCHEMA_VERSION": 3, "E_RCA_CONTRACT": 3, "E_REFERENCE": 3,
         "E_SANITIZATION": 4, "E_UNSAFE_CONTENT": 4, "E_PATH_ESCAPE": 4,
         "E_AUTH_MISSING": 5, "E_AUTH_INVALID": 5, "E_AUTH_DIGEST_MISMATCH": 5, "E_AUTH_SELF_APPROVAL": 5,
         "E_TRANSITION_DENIED": 5, "E_QUALITY_GATE": 5, "E_CONFLICT": 5,
         "E_KB_NOT_FOUND": 6, "E_KB_INTEGRITY": 6, "E_IO": 7, "E_OUTPUT_EXISTS": 7, "E_OUTPUT_TOO_LARGE": 7,
         "E_INTERNAL": 70}


class _Parser(argparse.ArgumentParser):
    """argparse echoes offending values in its errors; this replaces that with a fixed message."""

    def error(self, message):  # noqa: D401
        sys.stderr.write(f"E_USAGE: {ERROR_MESSAGES['E_USAGE']}\n")
        raise SystemExit(2)


def _build_parser() -> argparse.ArgumentParser:
    p = _Parser(prog="change_documentation_knowledge.cli", description=__doc__.split("\n\n")[0],
                formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__.split("Commands", 1)[1] if "Commands" in __doc__ else "")
    sub = p.add_subparsers(dest="command", required=True, parser_class=_Parser)

    def common(sp, needs_rca=True, output=True):
        if needs_rca:
            g = sp.add_mutually_exclusive_group()
            g.add_argument("--rca-result", help="JSON RcaResult produced by rca_engine (Phase 11)")
            g.add_argument("--fixture", help="synthetic incident fixture, run through the real rca_engine in-process")
            sp.add_argument("--rules", help="rules catalog JSON (default: bundled rca_engine catalog)")
        sp.add_argument("--generated-at", help="fixed UTC timestamp (clock injection for reproducible output)")
        if output:
            sp.add_argument("--output-dir", required=True, help="directory for derived artifacts (must be new files)")
            sp.add_argument("--dry-run", action="store_true", help="validate and build, print a summary, write nothing")

    a = sub.add_parser("advise", help="change advisory (operational, manual) or e-stack governance report")
    common(a)
    a.add_argument("--mode", choices=("operational", "estack"), default="operational")
    a.add_argument("--context", help="optional change context JSON (target, gates, external declarations)")
    a.add_argument("--estack-request", help="e-stack change request JSON (with --mode estack)")

    d = sub.add_parser("document", help="documentation factory")
    common(d)
    d.add_argument("--kind", required=True, choices=("rca", "executive", "change", "assessment", "post-incident"))
    d.add_argument("--advisory", help="change_advisory.json (needed for --kind change; optional otherwise)")
    d.add_argument("--assessment", help="assessment input JSON (for --kind assessment)")
    d.add_argument("--review-input", help="post-incident review input JSON (for --kind post-incident)")
    d.add_argument("--context", help="optional change context JSON used to build the advisory when --advisory is absent")

    k = sub.add_parser("kb-candidate", help="extract a KB candidate from a real RCA result")
    common(k)
    k.add_argument("--context", help="optional context JSON declaring the target scope")
    k.add_argument("--candidate-input", help="optional candidate metadata JSON")

    ka = sub.add_parser("kb-add", help="store a candidate as an immutable article version")
    ka.add_argument("--kb-root", required=True)
    ka.add_argument("--candidate", required=True)
    ka.add_argument("--generated-at")

    kt = sub.add_parser("kb-transition", help="move an article version through the lifecycle")
    kt.add_argument("--kb-root", required=True)
    kt.add_argument("--kb-id", required=True)
    kt.add_argument("--version", required=True)
    kt.add_argument("--to", required=True, choices=sorted(KbState.ALL))
    kt.add_argument("--authorization", help="EXTERNAL human authorization record (JSON) — required for decision transitions")
    kt.add_argument("--generated-at")

    ks = sub.add_parser("kb-search", help="read-only local knowledge search")
    ks.add_argument("--kb-root", required=True)
    ks.add_argument("--query", default="")
    ks.add_argument("--domain")
    ks.add_argument("--version")
    ks.add_argument("--error-code")
    ks.add_argument("--type", dest="article_type")
    ks.add_argument("--architecture", choices=("cdb", "rac", "dataguard", "asm"))
    ks.add_argument("--exclude-license-dependent", action="store_true")
    ks.add_argument("--validated-after")
    ks.add_argument("--include-state", action="append", choices=sorted(KbState.ALL), help="also list non-current states (labelled)")
    ks.add_argument("--top-k", type=int, default=DEFAULT_TOP_K)

    st = sub.add_parser("kb-status", help="read-only lifecycle listing")
    st.add_argument("--kb-root", required=True)
    rd = sub.add_parser("kb-review-due", help="read-only: entries whose review date has passed")
    rd.add_argument("--kb-root", required=True)
    rd.add_argument("--as-of", required=True)
    return p


# --- helpers -------------------------------------------------------------------------------------

def _load_rules(path):
    from rca_engine.engine import DEFAULT_RULES_PATH
    from rca_engine.rules import RulesError, load_rules
    try:
        return load_rules(path or DEFAULT_RULES_PATH)
    except (RulesError, OSError, ValueError):
        raise AdvisoryError("E_INPUT_INVALID", "rules")


def _rca_view(args, rules):
    if args.rca_result:
        rca = read_json_file(args.rca_result)
    elif args.fixture:
        from rca_engine.engine import run_rca
        fixture = read_json_file(args.fixture)
        try:
            rca, _token_map = run_rca(fixture, args.rules)     # the token map is discarded, never persisted
        except AdvisoryError:
            raise
        except Exception:
            raise AdvisoryError("E_INPUT_INVALID", "fixture")
    else:
        raise AdvisoryError("E_USAGE", "rca-result")
    return adapt_rca_result(rca, rules)


def _optional_json(path):
    return read_json_file(path) if path else None


def _write_set(output_dir: str, files: dict, generated_at: str, artifacts: list, dry_run: bool) -> dict:
    """files: {name: text}. Pre-check every target, then write; then the artifact manifest last."""
    for name, text in files.items():
        audit_rendered(text)
    summary = {"status": "OK", "dry_run": bool(dry_run), "artifacts": sorted(files) + ["artifact_manifest.json"]}
    manifest = {"schema_version": SCHEMA_VERSION, "artifact_type": "artifact_manifest", "generated_at_utc": generated_at,
                "generator_version": GENERATOR_VERSION,
                "artifacts": sorted(({**meta, "file": name, "file_sha256": hashlib.sha256(files[name].encode("utf-8")).hexdigest(),
                                      "bytes": len(files[name].encode("utf-8"))} for name, meta in artifacts), key=lambda x: x["file"])}
    assert_dev_workdir(output_dir)
    files = dict(files)
    files["artifact_manifest.json"] = dumps_pretty(manifest)
    audit_strings(manifest)
    if dry_run:
        return summary
    root = ensure_output_dir(output_dir)
    targets = {name: confine(root, name) for name in files}
    import os
    if any(os.path.lexists(t) for t in targets.values()):
        raise AdvisoryError("E_OUTPUT_EXISTS")
    for name in sorted(files):
        atomic_write_text(targets[name], files[name])
    return summary


def _emit(obj) -> None:
    sys.stdout.write(dumps_pretty(obj))


# --- commands ------------------------------------------------------------------------------------

def _cmd_advise(args):
    at = resolve_generated_at(args.generated_at)
    if args.mode == "estack":
        if not args.estack_request:
            raise AdvisoryError("E_USAGE", "estack-request")
        gov = build_estack_change(read_json_file(args.estack_request), at)
        return _write_set(args.output_dir, {"estack_change_governance.json": dumps_pretty(gov)}, at,
                          [("estack_change_governance.json", {"artifact_type": gov["artifact_type"], "artifact_id": gov["change"]["change_id"],
                                                             "content_digest": gov["content_digest"]})], args.dry_run)
    rules = _load_rules(args.rules)
    view = _rca_view(args, rules)
    adv = build_change_advisory(view, _optional_json(args.context), at)
    audit_strings(adv)
    files = {"change_advisory.json": dumps_pretty(adv), "change_advisory.md": render_change_advisory_md(adv)}
    meta = {"artifact_type": "change_advisory", "artifact_id": adv["advisory_id"], "content_digest": adv["content_digest"]}
    out = _write_set(args.output_dir, files, at, [("change_advisory.json", meta), ("change_advisory.md", meta)], args.dry_run)
    out["readiness"] = adv["readiness"]
    return out


def _cmd_document(args):
    at = resolve_generated_at(args.generated_at)
    kind = args.kind
    if kind == "assessment":
        if not args.assessment:
            raise AdvisoryError("E_USAGE", "assessment")
        doc = build_assessment_report(read_json_file(args.assessment), at)
    elif kind == "change":
        if not args.advisory:
            raise AdvisoryError("E_USAGE", "advisory")
        doc = build_change_report(read_json_file(args.advisory), at)
    else:
        rules = _load_rules(args.rules)
        view = _rca_view(args, rules)
        advisory = None
        if args.advisory:
            advisory = validate_advisory(read_json_file(args.advisory))
        elif kind in ("rca", "executive"):
            advisory = build_change_advisory(view, _optional_json(args.context), at)
        if kind == "rca":
            doc = build_rca_report(view, advisory, at)
        elif kind == "executive":
            doc = build_executive_summary(view, advisory, at)
        else:
            doc = build_post_incident_review(view, _optional_json(args.review_input), at)
    stem = "document_" + kind.replace("-", "_")
    files = {f"{stem}.json": dumps_pretty(doc), f"{stem}.md": render_document_md(doc)}
    meta = {"artifact_type": "document", "artifact_id": doc["document_id"], "content_digest": doc["content_digest"]}
    out = _write_set(args.output_dir, files, at, [(f"{stem}.json", meta), (f"{stem}.md", meta)], args.dry_run)
    out["content_status"] = doc["content_status"]
    return out


def _cmd_kb_candidate(args):
    at = resolve_generated_at(args.generated_at)
    rules = _load_rules(args.rules)
    view = _rca_view(args, rules)
    cand = build_kb_candidate(view, rules, _optional_json(args.context), _optional_json(args.candidate_input), at)
    files = {"kb_candidate.json": dumps_pretty(cand)}
    meta = {"artifact_type": "kb_candidate", "artifact_id": cand["kb_candidate_id"], "content_digest": cand["content_digest"]}
    out = _write_set(args.output_dir, files, at, [("kb_candidate.json", meta)], args.dry_run)
    out["lifecycle_state"] = cand["lifecycle_state"]
    out["quality_gate"] = cand["quality_gate"]["status"]
    out["blocking_reasons"] = cand["quality_gate"]["blocking_reasons"]
    return out


def _cmd_kb_add(args):
    assert_dev_workdir(args.kb_root, is_kb_root=True)
    at = resolve_generated_at(args.generated_at)
    return add_candidate(args.kb_root, read_json_file(args.candidate), at)


def _cmd_kb_transition(args):
    assert_dev_workdir(args.kb_root, is_kb_root=True)
    at = resolve_generated_at(args.generated_at)
    auth = read_json_file(args.authorization) if args.authorization else None
    return transition(args.kb_root, args.kb_id, args.version, args.to, at, auth)


def _cmd_kb_search(args):
    return search(args.kb_root, args.query, domain=args.domain, version=args.version, error_code=args.error_code,
                  article_type=args.article_type, architecture=args.architecture,
                  exclude_license_dependent=args.exclude_license_dependent, validated_after_utc=args.validated_after,
                  states=args.include_state or None, top_k=args.top_k)


def main(argv=None) -> int:
    for stream in (sys.stdout, sys.stderr):      # UTF-8 output everywhere (reproducible, parseable)
        try:
            stream.reconfigure(encoding="utf-8", newline="\n")
        except (AttributeError, ValueError):
            pass
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        require_sanitizer()
        handlers = {"advise": _cmd_advise, "document": _cmd_document, "kb-candidate": _cmd_kb_candidate,
                    "kb-add": _cmd_kb_add, "kb-transition": _cmd_kb_transition, "kb-search": _cmd_kb_search,
                    "kb-status": lambda a: kb_status_fn(a.kb_root),
                    "kb-review-due": lambda a: {"review_due": review_due(a.kb_root, a.as_of)}}
        _emit(handlers[args.command](args))
        return 0
    except AdvisoryError as e:
        sys.stderr.write(e.render() + "\n")
        return _EXIT.get(e.code, 70)
    except SystemExit:
        raise
    except BaseException:  # never print a traceback: it could carry input values
        sys.stderr.write(f"E_INTERNAL: {ERROR_MESSAGES['E_INTERNAL']}\n")
        return 70


if __name__ == "__main__":
    sys.exit(main())
