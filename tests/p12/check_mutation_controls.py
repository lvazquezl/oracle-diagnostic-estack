"""Phase 12 — mutation-testing control (same idea as tests/test_rca_mutation_testing_control.sh): each
defense is deliberately disabled at runtime and the functional check that is supposed to protect it MUST
then fail. A check that still passes under its mutation would prove the check is decorative."""
from tests.p12.harness import run_all, test
from tests.p12 import check_change, check_contract, check_knowledge, check_security, harness

harness._TESTS.clear()   # importing the check modules registered THEIR tests; only the mutation controls run here


def must_fail_under(mutator, check_fn, label):
    """mutator(patches) -> list of (obj, attr, replacement); applied, check run, then restored."""
    patches = mutator()
    saved = [(o, a, getattr(o, a)) for o, a, _ in patches]
    try:
        for o, a, r in patches:
            setattr(o, a, r)
        try:
            check_fn()
        except (AssertionError, Exception):
            return                                  # the protecting check noticed the mutation: good
        raise AssertionError(f"MUTATION SURVIVED: {label} — the check '{check_fn.__name__}' still passed with the defense disabled")
    finally:
        for o, a, v in saved:
            setattr(o, a, v)


@test
def disabling_the_digest_binding_of_authorizations_is_detected():
    from change_documentation_knowledge import kb_store

    def mut():
        def permissive(record, *, artifact_id, artifact_digest, version, proposer_ids=(), require_decision="APPROVED"):
            return {"authorization_id": record["authorization_id"], "reviewer_id": record["reviewer_id"], "decision": "APPROVED",
                    "decision_at_utc": record["decision_at_utc"], "artifact_digest": artifact_digest, "version": version,
                    "review_notes_sanitized": "", "verification": "MUTATED"}
        return [(kb_store, "verify_authorization", permissive)]
    must_fail_under(mut, check_knowledge.authorization_is_bound_to_digest_version_artifact_and_is_single_use, "digest binding")


@test
def disabling_the_executable_content_guard_is_detected():
    from change_documentation_knowledge import schema

    must_fail_under(lambda: [(schema, "has_executable_content", lambda v: False)],
                    check_contract.uncatalogued_recommendation_text_is_sanitized_flagged_and_command_text_rejected, "executable content guard")


@test
def treating_unknown_gates_as_non_blocking_is_detected():
    from change_documentation_knowledge import change
    from change_documentation_knowledge.common import GateStatus

    must_fail_under(lambda: [(GateStatus, "NON_BLOCKING", frozenset({"PASS", "NOT_APPLICABLE", "UNKNOWN"}))],
                    check_change.gates_default_to_unknown_and_block_readiness_unknown_is_not_not_applicable, "UNKNOWN != NOT_APPLICABLE")


@test
def accepting_any_signature_as_certified_is_detected():
    from change_documentation_knowledge import schema
    from rca_engine.common import SignatureStatus

    must_fail_under(lambda: [(schema, "classify_signature", lambda raw, inc, cert: (SignatureStatus.CERTIFIED, raw, None))],
                    check_contract.forged_certified_signature_is_rejected_and_never_echoed, "signature allowlist re-verification")


@test
def returning_retired_entries_from_retrieval_is_detected():
    from change_documentation_knowledge import retrieval

    must_fail_under(lambda: [(retrieval, "_NEVER_RETURNED", frozenset())],
                    check_knowledge.retrieval_returns_only_current_guidance_and_excludes_retired_deprecated_and_draft, "RETIRED excluded")


@test
def allowing_illegal_lifecycle_transitions_is_detected():
    from change_documentation_knowledge import common, kb_store
    from change_documentation_knowledge.common import KB_TRANSITIONS, KbState

    mutated = dict(KB_TRANSITIONS)
    mutated[KbState.CANDIDATE] = frozenset(KbState.ALL)
    must_fail_under(lambda: [(kb_store, "KB_TRANSITIONS", mutated)],
                    check_knowledge.illegal_transitions_are_rejected_and_state_is_unchanged, "transition table")


@test
def skipping_the_sanitizer_on_review_notes_is_detected():
    from change_documentation_knowledge import authorization

    must_fail_under(lambda: [(authorization, "clean_text", lambda v, n=0, f=None: v)],
                    check_security.secrets_in_authorization_notes_are_sanitized_and_never_reach_the_kb, "review notes sanitization")


@test
def dropping_the_self_approval_check_is_detected():
    from change_documentation_knowledge import authorization

    original = authorization.verify_authorization

    def mut():
        def no_self_check(record, *, artifact_id, artifact_digest, version, proposer_ids=(), require_decision="APPROVED"):
            return original(record, artifact_id=artifact_id, artifact_digest=artifact_digest, version=version, proposer_ids=(),
                            require_decision=require_decision)
        from change_documentation_knowledge import change, kb_store
        return [(kb_store, "verify_authorization", no_self_check), (change, "verify_authorization", no_self_check)]
    must_fail_under(mut, check_knowledge.proposer_cannot_approve_its_own_candidate, "self-approval")


if __name__ == "__main__":
    raise SystemExit(run_all())
