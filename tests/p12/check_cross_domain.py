"""Phase 12 — cross-domain coverage: RAC, ASM, Data Guard, Multitenant, RMAN, Network, OS, Security, Capacity.
Every incident is run through the REAL rca_engine (default catalog for OS/Network/RAC/Capacity; a synthetic
custom catalog, loaded through rca_engine's own --rules mechanism, for ASM/Data Guard/Multitenant/RMAN/Security)."""
import json
import os
import re

from tests.p12.harness import (
    T, catalog, fx, p12fx, read_json, run_all, test, view_of,
)
from change_documentation_knowledge.change import build_change_advisory, render_change_advisory_md
from change_documentation_knowledge.documents import build_executive_summary, build_rca_report, render_document_md
from change_documentation_knowledge.knowledge import build_kb_candidate

RULES = p12fx("rules_cross_domain.json")
CTX = read_json(p12fx("change_context_all_pass.json"))

# (label, fixture path, rules path or None, expected domain)
CASES = [
    ("os", fx("positive_confirmed.json"), None, "os"),
    ("network", p12fx("incidents/network_listener_confirmed.json"), None, "network"),
    ("rac", fx("cross_domain_rac_os_network.json"), None, "rac"),
    ("asm", p12fx("incidents/asm_confirmed.json"), RULES, "asm"),
    ("dataguard", p12fx("incidents/dataguard_confirmed.json"), RULES, "dataguard"),
    ("multitenant", p12fx("incidents/multitenant_confirmed.json"), RULES, "multitenant"),
    ("rman", p12fx("incidents/rman_confirmed.json"), RULES, "rman"),
    ("security", p12fx("incidents/security_confirmed.json"), RULES, "security"),
]


@test
def every_domain_flows_through_advisory_documents_and_kb_candidate_with_its_own_guidance():
    seen = set()
    for label, path, rules, domain in CASES:
        view = view_of(path, rules)
        state = view["root_cause"]["completeness"]
        assert state == "CONFIRMED", f"{label}: expected the real rca_engine to confirm, got {state}"
        adv = build_change_advisory(view, CTX, T)
        assert adv["changes"], label
        c = adv["changes"][0]
        assert c["context"]["domain"] == domain and c["affected_components"] and c["blast_radius"]["statement"], label
        assert c["execution_status"] == "NOT_EXECUTED_BY_ESTACK"
        cand = build_kb_candidate(view, catalog(rules), CTX, None, T)
        assert cand["article"]["scope"]["domain"] == domain and cand["lifecycle_state"] == "CANDIDATE", label
        ex = build_executive_summary(view, adv, T)
        assert ex["root_cause_state"] == "CONFIRMED"
        seen.add(domain)
    assert seen >= {"os", "network", "rac", "asm", "dataguard", "multitenant", "rman", "security"}


@test
def capacity_forecast_only_is_never_reported_as_a_past_cause():
    view = view_of(p12fx("incidents/capacity_forecast_only.json"))
    assert view["root_cause"]["completeness"] in ("INSUFFICIENT_EVIDENCE", "INCONCLUSIVE")
    adv = build_change_advisory(view, CTX, T)
    cand = build_kb_candidate(view, catalog(), CTX, None, T) if view["hypotheses"] else None
    assert adv["changes"] == [] and "RCA_NOT_CONFIRMED_NO_CAUSE_ASSERTED" in adv["warnings"]
    text = json.dumps(build_executive_summary(view, adv, T))
    assert "no cause is asserted" in text and "Confirmed cause:" not in text
    if cand is not None:
        assert cand["lifecycle_state"] == "REJECTED"


@test
def capacity_domain_guidance_exists_and_is_not_universal():
    from change_documentation_knowledge.change import DOMAIN_GUIDANCE
    from rca_engine.common import ALLOWED_DOMAINS
    assert set(DOMAIN_GUIDANCE) == set(ALLOWED_DOMAINS), "every Phase 11 domain (incl. capacity, performance) needs Phase 12 guidance"
    for d, g in DOMAIN_GUIDANCE.items():
        assert g["components"] and g["rollback"] and g["blast"] and g["breadth"] in ("MEDIUM", "HIGH"), d


@test
def dataguard_and_performance_never_assume_licensing_and_no_pack_is_declared_entitled():
    from change_documentation_knowledge.change import DOMAIN_GUIDANCE
    for d in ("dataguard", "performance"):
        assert DOMAIN_GUIDANCE[d]["license_dependent"] is True and "never assumed" in DOMAIN_GUIDANCE[d]["license_note"]
    view = view_of(p12fx("incidents/dataguard_confirmed.json"), RULES)
    md = render_change_advisory_md(build_change_advisory(view, None, T))
    assert re.search(r"license_gate \| UNKNOWN", md.replace("\\", "")) or "license\\_gate | UNKNOWN" in md or "license_gate | UNKNOWN" in md
    joined = json.dumps(build_change_advisory(view, None, T)).lower()
    for phrase in ("licensed for awr", "licensed for ash", "licensed for addm", "adg is licensed", "active data guard is licensed", "entitled to"):
        assert phrase not in joined, phrase


@test
def no_document_or_article_claims_19c_as_universal_coverage():
    for label, path, rules, _domain in CASES:
        view = view_of(path, rules)
        parts = [json.dumps(build_change_advisory(view, None, T)), json.dumps(build_kb_candidate(view, catalog(rules), None, None, T)),
                 render_document_md(build_rca_report(view, None, T))]
        for p in parts:
            p = re.sub(r"[0-9a-f]{64}", "", p)                      # digests may contain the letters '19c'
            p = re.sub(r'"scope_note": "[^"]*"', "", p)             # the note that DENIES universality is allowed
            assert not re.search(r"19c", p) and "all versions" not in p.lower() and "applies everywhere" not in p.lower(), label
    ctx12 = read_json(p12fx("change_context_12_2_license_unknown.json"))
    cand = build_kb_candidate(view_of(fx("positive_confirmed.json")), catalog(), ctx12, None, T)
    assert cand["article"]["scope"]["oracle_versions"] == ["12.2"]


@test
def rac_architecture_flags_are_carried_as_declared_and_unknown_when_missing():
    ctx = json.loads(json.dumps(CTX))
    ctx["target"]["architecture"] = {"cdb": True, "rac": True, "dataguard": None, "asm": True}
    c = build_change_advisory(view_of(fx("cross_domain_rac_os_network.json")), ctx, T)["changes"][0]
    assert c["topology"] == {"cdb": True, "rac": True, "dataguard": "UNKNOWN", "asm": True}
    assert next(r for r in c["risk_factors"] if r["dimension"] == "topology_breadth")["level"] == "HIGH"


@test
def unknown_is_never_reported_as_not_applicable_or_supported_anywhere_in_the_advisory():
    adv = build_change_advisory(view_of(p12fx("incidents/asm_confirmed.json"), RULES), None, T)
    c = adv["changes"][0]
    for g in ("capability_gate", "license_gate", "privilege_gate", "change_window_gate"):
        assert c[g]["status"] == "UNKNOWN"
    assert c["service_dependencies"] == "UNKNOWN" and c["blast_radius"]["status"] == "UNKNOWN_UNTIL_SCOPE_DEFINED"
    assert c["reversibility"] == "PARTIAL_OR_IRREVERSIBLE_UNKNOWN", "ASM operations must not be presented as freely reversible"


if __name__ == "__main__":
    raise SystemExit(run_all())
