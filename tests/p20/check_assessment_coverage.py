"""CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001 — domain coverage model, evaluator and assessment document (no Oracle)."""
import copy
import io
import json
import os
import contextlib

from tests.p13.harness import ROOT, run_all, test, tmpdir

from mcp_gateway import catalog
from scripts.assessment_coverage import evaluate as cov
from change_documentation_knowledge import documents as docs
from change_documentation_knowledge.common import AdvisoryError
from tests.p12.harness import p12fx

T = "2026-11-16T00:00:00Z"
COLLECTORS = catalog.load_collectors()
MODEL = cov.load_model(collectors=COLLECTORS)
LAB_TOPOLOGY = {"cdb": True, "rac": False, "asm": True, "dataguard": False, "standby": False}


def _refused(fn, exc=cov.CoverageError):
    try:
        fn()
    except exc as e:
        return str(e)
    raise AssertionError("expected a refusal")


def _mini(items, applies_when=None):
    d = {"id": "Z9", "title": "synthetic", "items": items}
    if applies_when:
        d["applies_when"] = applies_when
    m = copy.deepcopy(MODEL)
    m["domains"] = [d]
    return m


def _one(model, collectors, topology=None, license_status=None):
    r = cov.evaluate(model, {"topology": topology or LAB_TOPOLOGY, "license_status": license_status or {},
                             "collectors": collectors}, COLLECTORS)
    return r["domains"][0]


OBT = {"id": "a", "label": "a", "collectors": ["Q-ORA-UNDO-001"]}
POL = {"id": "b", "label": "b", "collectors": [], "excluded_by_policy": {"category": "DATA_CLASSIFICATION", "reason": "r"}}
GAP = {"id": "c", "label": "c", "collectors": [], "gap": "sin collector"}
AWR = {"id": "d", "label": "d", "collectors": ["Q-PERF-AWR-DBTIME-24H-001"]}


# --- the committed model -----------------------------------------------------------------------------------

@test
def every_collector_in_the_model_exists_and_every_collector_but_the_dictionary_probes_has_a_domain():
    used = {c for d in MODEL["domains"] for i in d["items"] for c in i["collectors"]}
    assert used <= set(COLLECTORS)
    unmapped = sorted(c for c in COLLECTORS if c not in used and not c.startswith("Q-DICT-VERIFY-"))
    assert unmapped == [], unmapped


@test
def every_exclusion_names_a_category_whose_policy_file_exists_and_the_document_engine_uses_the_same_vocabulary():
    cats = MODEL["exclusion_categories"]
    for c in cats.values():
        assert os.path.isfile(os.path.join(ROOT, c["policy"])), c
    assert set(docs._EXCLUSION_CATEGORIES) == set(cats)
    assert set(docs._DOMAIN_STATES) == set(MODEL["domain_states"]) == set(cov.DOMAIN_STATES)
    excluded = [i for d in MODEL["domains"] for i in d["items"] if "excluded_by_policy" in i]
    assert excluded and all(i["excluded_by_policy"]["category"] in cats and not i["collectors"] for i in excluded)


@test
def the_policy_exclusions_are_the_ones_the_policies_actually_state():
    text = {i["id"]: i["excluded_by_policy"] for d in MODEL["domains"] for i in d["items"] if "excluded_by_policy" in i}
    assert set(text) == {"B4", "F4", "F5", "N7", "O12", "P4", "Q6", "Z3"}, sorted(text)
    dcp = open(os.path.join(ROOT, "sanitizers", "data-classification-policy.md"), encoding="utf-8").read()
    assert "bind values" in dcp and "password hashes" in dcp and "SQL text" in dcp and "wallets" in dcp
    fo = open(os.path.join(ROOT, "policies", "forbidden-operations.md"), encoding="utf-8").read()
    assert "`RESTORE`" in fo and text["N7"]["category"] == "FORBIDDEN_OPERATION"
    lap = open(os.path.join(ROOT, "policies", "licensing-awareness-policy.md"), encoding="utf-8").read()
    assert "Nunca se afirma" in lap and text["Z3"]["category"] == "LICENSE_ENTITLEMENT_NOT_ASSERTED"


@test
def a_gap_is_never_hidden_as_a_policy_exclusion():
    # what can be obtained (adapters of lot E, PDB-scoped views, uncertified views) stays MISSING, never excluded
    for d in MODEL["domains"]:
        for i in d["items"]:
            if "excluded_by_policy" in i:
                assert "gap" not in i and "lote E" not in i["excluded_by_policy"]["reason"], i["id"]
    gaps = {i["id"] for d in MODEL["domains"] for i in d["items"] if i.get("gap")}
    assert {"D4", "H3", "K3", "NET3", "OS3", "S1"} <= gaps


# --- model validation ------------------------------------------------------------------------------------------

@test
def the_model_loader_refuses_malformed_items():
    for mutate, needle in [
        (lambda m: m["domains"][0]["items"].append({"id": "x1", "label": "x", "collectors": ["Q-ORA-UNDO-001"],
                                                     "excluded_by_policy": {"category": "DATA_CLASSIFICATION", "reason": "r"}}), "policy exclusion"),
        (lambda m: m["domains"][0]["items"].append({"id": "x2", "label": "x", "collectors": []}), "gap"),
        (lambda m: m["domains"][0]["items"].append({"id": "x3", "label": "x", "collectors": [], "gap": "g",
                                                     "applies_when": {"exadata": True}}), "unknown flag"),
        (lambda m: m["domains"][0]["items"].append({"id": "x4", "label": "x", "collectors": [],
                                                     "excluded_by_policy": {"category": "CONVENIENCE", "reason": "r"}}), "policy exclusion"),
        (lambda m: m["domains"][0]["items"].append({"id": "x5", "label": "x", "collectors": ["Q-NOPE-001"]}), "unknown collectors"),
        (lambda m: m["exclusion_categories"]["DATA_CLASSIFICATION"].update(policy="policies/nope.md"), "missing policy"),
        (lambda m: m["domains"][1]["items"].append(dict(m["domains"][0]["items"][0])), "duplicate id"),
    ]:
        m = copy.deepcopy(MODEL)
        mutate(m)
        with tmpdir() as d:
            p = os.path.join(d, "m.json")
            json.dump(m, open(p, "w", encoding="utf-8"))
            assert needle in _refused(lambda: cov.load_model(p, collectors=COLLECTORS)), needle


# --- evaluator rules --------------------------------------------------------------------------------------------

@test
def complete_needs_every_applicable_item_and_within_policy_needs_only_policy_exclusions_left():
    assert _one(_mini([OBT]), {"Q-ORA-UNDO-001": "OBSERVED"})["status"] == "COMPLETE"
    assert _one(_mini([OBT, POL]), {"Q-ORA-UNDO-001": "OBSERVED"})["status"] == "COMPLETE_WITHIN_POLICY"
    assert _one(_mini([OBT, POL, GAP]), {"Q-ORA-UNDO-001": "OBSERVED"})["status"] == "PARTIAL"
    assert _one(_mini([OBT, POL]), {})["status"] == "NOT_ASSESSED"
    assert _one(_mini([POL]), {})["status"] == "NOT_ASSESSED"          # nothing obtained is never "complete"


@test
def topology_decides_applicability_and_an_unknown_flag_is_missing_not_applicable():
    k = dict(GAP, applies_when={"cdb": True})
    assert _one(_mini([OBT, k]), {"Q-ORA-UNDO-001": "OBSERVED"}, topology={**LAB_TOPOLOGY, "cdb": False})["status"] == "COMPLETE"
    assert _one(_mini([OBT, k]), {"Q-ORA-UNDO-001": "OBSERVED"})["status"] == "PARTIAL"
    assert _one(_mini([OBT], {"rac": True}), {"Q-ORA-UNDO-001": "OBSERVED"})["status"] == "NOT_APPLICABLE"
    unknown = _one(_mini([OBT], {"rac": True}), {"Q-ORA-UNDO-001": "OBSERVED"}, topology={"cdb": True})
    assert unknown["status"] == "NOT_ASSESSED" and "desconocida" in unknown["items"][0]["reason"]
    assert _one(_mini([OBT]), {"Q-ORA-UNDO-001": "NOT_APPLICABLE"})["status"] == "NOT_APPLICABLE"


@test
def a_license_gap_is_excluded_only_when_the_human_declared_the_pack_not_licensed():
    d = _one(_mini([OBT, AWR]), {"Q-ORA-UNDO-001": "OBSERVED", "Q-PERF-AWR-DBTIME-24H-001": "LICENSE_RESTRICTED"},
             license_status={"diagnostics_pack": "NOT_LICENSED"})
    assert d["status"] == "COMPLETE_WITHIN_POLICY" and d["items"][1]["category"] == "LICENSE_NOT_ENTITLED"
    for value in ("UNKNOWN", None):
        d = _one(_mini([OBT, AWR]), {"Q-ORA-UNDO-001": "OBSERVED", "Q-PERF-AWR-DBTIME-24H-001": "LICENSE_RESTRICTED"},
                 license_status={} if value is None else {"diagnostics_pack": value})
        assert d["status"] == "PARTIAL" and "LICENSE_CHECK_REQUIRED" in d["items"][1]["reason"]


@test
def a_missing_item_says_why_and_how_and_failures_are_never_coverage():
    for state in ("FAILED", "NOT_RUN", "UNSUPPORTED", "INSUFFICIENT_PRIVILEGES", "ENVIRONMENT_UNKNOWN", "DISABLED"):
        d = _one(_mini([OBT]), {} if state == "NOT_RUN" else {"Q-ORA-UNDO-001": state})
        assert d["status"] == "NOT_ASSESSED" and d["items"][0]["status"] == "MISSING" and d["items"][0]["reason"], state
    d = _one(_mini([dict(OBT, gap="adaptador")]), {"Q-ORA-UNDO-001": "UNSUPPORTED"})
    assert "adaptador" in d["items"][0]["reason"]
    d = _one(_mini([OBT]), {"Q-ORA-UNDO-001": "DEGRADED"})          # truncated evidence is obtained, but flagged
    assert d["status"] == "COMPLETE" and d["items"][0]["degraded"] == ["Q-ORA-UNDO-001"]
    assert "unknown collector states" in _refused(lambda: _one(_mini([OBT]), {"Q-ORA-UNDO-001": "OK"}))


@test
def the_evaluator_never_computes_insufficient_evidence_and_the_full_model_runs_on_a_lab_like_observation():
    every = {c: "OBSERVED" for c in COLLECTORS}
    r = cov.evaluate(MODEL, {"topology": LAB_TOPOLOGY, "license_status": {"diagnostics_pack": "CONFIRMED"}, "collectors": every}, COLLECTORS)
    st = {d["id"]: d["status"] for d in r["domains"]}
    assert "INSUFFICIENT_EVIDENCE" not in st.values()
    assert st["S"] == st["U"] == "NOT_APPLICABLE" and st["R"] == "COMPLETE" and st["Q"] == "COMPLETE_WITHIN_POLICY"
    assert st["N"] == "COMPLETE_WITHIN_POLICY" and st["F"] == "PARTIAL" and st["K"] == "PARTIAL"   # F3 and K3 are real gaps
    assert sum(r["counts"].values()) == len(MODEL["domains"])


@test
def the_cli_prints_markdown_and_json_and_refuses_bad_input():
    with tmpdir() as d:
        p = os.path.join(d, "obs.json")
        json.dump({"topology": LAB_TOPOLOGY, "collectors": {"Q-ORA-UNDO-001": "OBSERVED"}}, open(p, "w", encoding="utf-8"))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            assert cov.main(["--observations", p, "--format", "md"]) == 0
        assert "| K. UNDO | PARTIAL |" in out.getvalue()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            assert cov.main(["--observations", p]) == 0
        assert len(json.loads(out.getvalue())["model_sha256"]) == 64
        json.dump({"collectors": {"Q-ORA-UNDO-001": "YES"}}, open(p, "w", encoding="utf-8"))
        with contextlib.redirect_stderr(io.StringIO()):
            assert cov.main(["--observations", p]) == 2


# --- assessment document -----------------------------------------------------------------------------------------

def _assessment(dc):
    base = json.load(open(p12fx("assessment_basic.json"), encoding="utf-8"))
    base["domain_coverage"] = dc
    return base


CWP = {"domain": "N. RMAN", "status": "COMPLETE_WITHIN_POLICY", "policy_exclusions": [{"item": "N7", "category": "FORBIDDEN_OPERATION"}]}
PART = {"domain": "K. UNDO", "status": "PARTIAL", "missing": ["K3: UNDO de cada PDB"]}


@test
def the_assessment_document_shows_domain_coverage_and_a_review_may_only_lower_it():
    doc = docs.build_assessment_report(_assessment([CWP, PART, {"domain": "E. Performance", "status": "INSUFFICIENT_EVIDENCE",
                                                                "evaluated_status": "COMPLETE", "review_note": "un solo intervalo AWR"}]), T)
    sec = next(s for s in doc["sections"] if s["section_id"] == "domain_coverage")
    assert sec["status"] == "PRESENT" and "COMPLETE_WITHIN_POLICY=1" in sec["items"][0]["text"] and len(sec["rows"]) == 3
    assert "DOMAIN_STATUS_LOWERED_BY_REVIEW" in doc["warnings"]
    md = docs.render_document_md(doc)
    assert "COMPLETE\\_WITHIN\\_POLICY" in md or "COMPLETE_WITHIN_POLICY" in md
    lowered = docs.parse_assessment(_assessment([{"domain": "W", "status": "PARTIAL", "evaluated_status": "COMPLETE",
                                                  "missing": ["W2 truncado a 100 filas"], "review_note": "inventario truncado"}]))
    assert lowered["domain_coverage"][0]["status"] == "PARTIAL"
    none = docs.build_assessment_report(_assessment([]), T)
    assert next(s for s in none["sections"] if s["section_id"] == "domain_coverage")["status"] == "NOT_PROVIDED_BY_SOURCE"


@test
def the_assessment_document_refuses_coverage_that_is_not_earned():
    bad = [
        [dict(CWP, policy_exclusions=[])],                                                   # within policy without an exclusion
        [dict(CWP, policy_exclusions=[{"item": "N7", "category": "CONVENIENCE"}])],          # unknown category
        [dict(PART, missing=[])],                                                            # partial without what is missing
        [{"domain": "X", "status": "NOT_ASSESSED"}],
        [{"domain": "X", "status": "COMPLETE", "missing": ["algo"]}],
        [{"domain": "X", "status": "COMPLETE", "evaluated_status": "PARTIAL", "missing": ["m"], "review_note": "lo revisé"}],   # raising
        [{"domain": "X", "status": "PARTIAL", "evaluated_status": "NOT_ASSESSED", "missing": ["m"], "review_note": "n"}],  # raising only
        [{"domain": "X", "status": "PARTIAL", "evaluated_status": "COMPLETE", "missing": ["m"]}],     # lowering without a note
        [{"domain": "X", "status": "PARTIAL", "evaluated_status": "COMPLETE", "review_note": "n"}],   # lowered to PARTIAL, nothing said missing
        [{"domain": "X", "status": "INSUFFICIENT_EVIDENCE", "missing": ["m"]}],                      # only from a review
        [{"domain": "S", "status": "NOT_ASSESSED", "evaluated_status": "NOT_APPLICABLE", "review_note": "n", "missing": ["m"]}],
        [PART, PART],                                                                                # duplicate domain
    ]
    for dc in bad:
        _refused(lambda: docs.parse_assessment(_assessment(dc)), AdvisoryError)


if __name__ == "__main__":
    raise SystemExit(run_all())
