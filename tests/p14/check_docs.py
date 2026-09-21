"""Phase 14 — documentation consistency: what the documents claim about states, counts, flags, limits, subcommands,
risks, blockers and tests must match the real code, registry and parsers."""
import json
import os
import re

from tests.p14.harness import ROOT, run_all, test

DOCS = ("PRODUCTION_READINESS.md", "OPERATIONS_RUNBOOK.md", "SECURITY_AND_PRIVACY.md", "RELEASE_AND_ROLLBACK.md", "GOVERNANCE_AND_EVOLUTION.md",
        "PILOT_ACCEPTANCE_CHECKLIST.md", "PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md")


def doc(name):
    with open(os.path.join(ROOT, "docs", name), encoding="utf-8") as f:
        return f.read()


def all_docs():
    return "\n".join(doc(n) for n in DOCS)


@test
def the_release_gate_documentation_check_passes_on_the_real_documents():
    from release_readiness import gate
    res = gate.check_documentation(ROOT)
    assert res["status"] == "PASS", res.get("data")
    assert set(gate.DOC_REQUIREMENTS) == {"docs/" + n for n in DOCS}, "every Phase 14 document is covered by the gate"


@test
def every_maturity_state_is_documented_with_its_evidence_rule():
    from release_readiness.common import MATURITY_ORDER
    text = doc("PRODUCTION_READINESS.md")
    for state in MATURITY_ORDER:
        assert re.search(rf"^\| `{state}` \|", text, re.M), f"{state} is not defined in PRODUCTION_READINESS.md"
    assert "sin su evidencia" in text or "afirmación verificable" in text
    assert "REG_MATURITY_OVERSTATED" in text and "REG_MATURITY_STALE" in text


@test
def the_component_counts_and_maturity_distribution_in_the_document_equal_the_registry():
    from release_readiness import registry
    reg = registry.load_registry(ROOT)
    text = doc("PRODUCTION_READINESS.md")
    counts = {}
    for c in reg["components"]:
        counts[c["kind"]] = counts.get(c["kind"], 0) + 1
    for kind, n in counts.items():
        assert re.search(rf"^\| {kind} \| {n} \|", text, re.M), f"the document does not state {n} components of kind {kind}"
    summary = registry.verify_registry(ROOT)["maturity_summary"]
    for state, n in summary.items():
        assert re.search(rf"`{state}` {n}\b", text), f"the document does not state {n} components in {state}"
    assert not [c for c in reg["components"] if c["maturity"] in ("PILOT_VALIDATED", "CERTIFIED")]
    assert "ningún componente en `PILOT_VALIDATED`, `CERTIFIED`" in text


@test
def the_gateway_flags_and_limit_ranges_in_the_runbook_equal_the_real_parser_and_bounds():
    from mcp_gateway import cli
    from mcp_gateway.common import LIMIT_BOUNDS
    text = doc("OPERATIONS_RUNBOOK.md")
    flags = {o for a in cli.build_parser()._actions for o in a.option_strings if o.startswith("--")}
    for flag in flags - {"--help", "--targets", "--fixtures-dir", "--audit", "--version", "--print-claude-config"}:
        assert f"`{flag}`" in text, f"{flag} is not documented"
    for flag in ("--version", "--print-claude-config", "--audit"):
        assert flag in text, flag
    table = {name: m for name, m in re.findall(r"^\| `--([a-z-]+)` \| ([^|]+) \|", text, re.M)}
    for name, (lo, hi) in LIMIT_BOUNDS.items():
        rng = table[name.replace("_", "-")]
        fmt = lambda v: str(int(v)) if float(v).is_integer() else str(v)
        assert fmt(lo) in rng and fmt(hi) in rng, (name, rng)


@test
def every_release_readiness_subcommand_is_documented_and_every_documented_one_exists():
    from release_readiness import cli
    sub = next(a for a in cli.build_parser()._actions if a.dest == "command")
    real = set(sub.choices)
    text = all_docs()
    documented = set(re.findall(r"python -m release_readiness ([a-z-]+)", text))
    assert real == {"snapshot", "run", "verify", "gate", "registry-check", "governance-check"}
    assert real <= documented, real - documented
    assert documented <= real, documented - real


@test
def the_risks_named_in_the_documents_are_the_ones_in_the_register_with_the_same_owner_role():
    risks = {r["risk_id"]: r for r in json.load(open(os.path.join(ROOT, "config", "governance", "risk-register.json"), encoding="utf-8"))["risks"]}
    text = doc("SECURITY_AND_PRIVACY.md")
    rows = re.findall(r"^\| (RSK-\d{3}) \| [^|]+ \| ([a-z-]+) \|", text, re.M)
    assert {r for r, _ in rows} == set(risks), "the security document lists exactly the registered risks"
    for rid, role in rows:
        assert risks[rid]["owner_role"] == role, rid
    for rid in set(re.findall(r"RSK-\d{3}", all_docs())):
        assert rid in risks, f"{rid} is cited but not registered"


@test
def every_test_script_named_in_the_documents_exists_and_every_phase_14_wrapper_is_documented():
    text = all_docs()
    for name in set(re.findall(r"\btest_[a-z0-9_]+\.sh\b", text)):
        assert os.path.isfile(os.path.join(ROOT, "tests", name)), f"{name} is referenced but does not exist"
    wrappers = sorted(f for f in os.listdir(os.path.join(ROOT, "tests")) if f.startswith("test_p14_") and f.endswith(".sh"))
    assert len(wrappers) == 10
    phase = doc("PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md")
    for w in wrappers:
        assert w in phase, f"{w} is not documented in the phase document"


@test
def the_documents_never_claim_real_environment_readiness_or_certification_that_the_registry_denies():
    text = doc("PRODUCTION_READINESS.md")
    assert re.search(r"READY_FOR_REAL_ENVIRONMENT_PILOT` \|[^|]+\|\s*\*\*`NO`\*\*", text)
    assert "Producción | — | **Fuera de alcance**" in text
    pilot = doc("PILOT_ACCEPTANCE_CHECKLIST.md")
    assert re.search(r"\*\*no\*\* contiene procedimientos operativos de conexión", pilot) and "Hoy **no puede iniciarse**" in pilot
    for name in DOCS:
        body = doc(name)
        for bad in (r"production[- ]ready\b(?!.*(no|not|nunca|never))", r"certificad[oa] para producción", r"listo para producción"):
            for line in body.splitlines():
                if re.search(bad, line, re.I) and not re.search(r"\b(no|nunca|ninguno|ningún|not|never|sin|fuera)\b", line, re.I):
                    raise AssertionError(f"{name}: an unqualified readiness claim: {line[:100]}")


@test
def the_entry_documents_point_to_the_phase_14_documents_and_the_changelog_records_the_phase():
    for rel in ("SECURITY.md", "ARCHITECTURE.md", "CHANGELOG.md", "README.md"):
        body = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        assert any(n in body for n in ("PRODUCTION_READINESS.md", "PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md", "SECURITY_AND_PRIVACY.md")), rel
    change = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
    assert "PHASE 14" in change and "release_readiness" in change and "READY_FOR_REAL_ENVIRONMENT_PILOT" in change
    assert "0.13.0" in open(os.path.join(ROOT, "docs", "PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md"), encoding="utf-8").read() or "v0.13.0" in doc("PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md")


@test
def the_new_documents_and_records_contain_no_personal_paths_or_secret_shaped_text():
    from change_documentation_knowledge.safety import contains_structured_secret
    from release_readiness.redact import residual_personal_paths
    files = [os.path.join("docs", n) for n in DOCS] + ["config/production-readiness-registry.json", "config/governance/risk-register.json", "config/governance/lifecycle-records.json"]
    for rel in files:
        data = open(os.path.join(ROOT, rel), "rb").read()
        assert residual_personal_paths(data) == 0, rel
        assert b"\r" not in data, f"{rel} must use LF line endings"
        for line in data.decode("utf-8").splitlines():
            assert not contains_structured_secret(re.sub(r"[0-9a-f]{64}", "", line)), (rel, line[:80])


if __name__ == "__main__":
    raise SystemExit(run_all())
