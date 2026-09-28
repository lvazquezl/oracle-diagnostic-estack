"""CHG-ESTACK-VALIDATION-MATRIX-001 — field validation registry and levels (synthetic targets, no Oracle)."""
import copy
import glob
import hashlib
import json
import os
import re

from tests.p13.harness import PRIMARY, ROOT, InProcClient, run_all, test, tmpdir

from mcp_gateway import catalog, field_validation as fv

REG = os.path.join(ROOT, "config", "field-validation-registry.json")
LAB_CTX = "LAB-OL8-19C-CDBROOT-ASM"


def _current_sha(query_id):
    path = catalog._find_query_file(query_id)
    blocks = catalog.sql_blocks(open(path, encoding="utf-8").read())
    return hashlib.sha256("\n".join(blocks).encode("utf-8")).hexdigest()


class T:                                   # a synthetic gateway target
    def __init__(self, **kw):
        self.oracle_version = kw.get("oracle_version", "19c")
        self.release_update = kw.get("release_update")
        self.container = kw.get("container", "CDB_ROOT")
        self.role = kw.get("role", "PRIMARY")
        self.architecture = kw.get("architecture", {"rac": False, "asm": True, "dataguard": False})
        self.os = kw.get("os", {"family": "LINUX", "distribution": "OL", "version": "8.10"})


class C:                                   # a synthetic collector
    def __init__(self, qid, sha, kind="sql_query"):
        self.collector_id = self.query_id = qid
        self.query_sha256, self.kind = sha, kind


def _reg():
    return fv.load(REG)


@test
def registry_loads_and_every_entry_points_to_an_existing_query_with_its_current_sql():
    r = _reg()
    assert r["loaded"] and r["validations"], "registry must load"
    seen = set()
    for v in r["validations"]:
        assert catalog._find_query_file(v["query_id"]), v["query_id"]
        assert v["query_sha256"] == _current_sha(v["query_id"]), f'{v["query_id"]}: SQL changed since field validation — revalidate or retire'
        key = (v["query_id"], v["context_id"])
        assert key not in seen, key
        seen.add(key)


@test
def every_evidence_ref_and_change_id_is_in_the_cited_change_record():
    for v in _reg()["validations"]:
        text = open(os.path.join(ROOT, v["record"]), encoding="utf-8").read()
        for ref in v["evidence_refs"] + v["request_refs"]:
            assert ref in text, (v["query_id"], ref, v["record"])
        assert v["change_id"] in text or v["change_id"].split("-")[-1] in text, (v["query_id"], v["change_id"])
        assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", v["validated_at_utc"])


@test
def exact_context_is_field_validated_and_unknown_dimensions_are_reported_not_assumed():
    r = _reg()
    sha = _current_sha("Q-DISC-IDENTITY-001")
    a = fv.assess(r, C("Q-DISC-IDENTITY-001", sha), T(release_update="19.32"))
    assert a["level"] == "FIELD_VALIDATED" and not a["differences"] and not a["not_compared"], a
    a = fv.assess(r, C("Q-DISC-IDENTITY-001", sha), T(os={}))
    assert a["level"] == "FIELD_VALIDATED" and set(a["not_compared"]) == {"release_update", "os"}, a


@test
def any_differing_dimension_gives_other_context_and_names_the_dimension():
    r = _reg()
    sha = _current_sha("Q-DISC-IDENTITY-001")
    cases = [(T(architecture={"rac": True, "asm": True, "dataguard": False}), "rac"),
             (T(architecture={"rac": False, "asm": False, "dataguard": False}), "asm"),
             (T(architecture={"rac": False, "asm": True, "dataguard": True}), "dataguard"),
             (T(role="STANDBY"), "role"), (T(container="PDB"), "container"), (T(oracle_version="23ai"), "oracle_version"),
             (T(os={"family": "AIX", "distribution": "AIX", "version": "7.3"}), "os"),
             (T(release_update="19.10"), "release_update")]
    for target, dim in cases:
        a = fv.assess(r, C("Q-DISC-IDENTITY-001", sha), target)
        assert a["level"] == "FIELD_VALIDATED_OTHER_CONTEXT" and [d["dimension"] for d in a["differences"]] == [dim], (dim, a)
    a = fv.assess(r, C("Q-DISC-IDENTITY-001", sha), T(release_update="19.40"))
    assert a["level"] == "FIELD_VALIDATED", "a newer RU than the validated one is not a difference"


@test
def changed_sql_unknown_query_and_non_query_collectors_are_documentation_only():
    r = _reg()
    assert fv.assess(r, C("Q-DISC-IDENTITY-001", "0" * 64), T())["reason"] == "SQL_CHANGED_SINCE_FIELD_VALIDATION"
    assert fv.assess(r, C("Q-DISC-IDENTITY-001", "0" * 64), T())["level"] == "DOCUMENTATION_ONLY"
    assert fv.assess(r, C("Q-RAC-GES-GCS-001", _current_sha("Q-RAC-GES-GCS-001")), T())["level"] == "DOCUMENTATION_ONLY"
    assert fv.assess(r, C("os.get_process_limits", None, kind="semantic_os"), T())["reason"] == "NOT_A_CERTIFIED_QUERY"


@test
def an_invalid_or_missing_registry_fails_closed_to_documentation_only():
    sha = _current_sha("Q-DISC-IDENTITY-001")
    with tmpdir() as d:
        doc = json.load(open(REG))
        bad = [("missing", None), ("not json", "{"), ("bad evr", "evr"), ("bad sha", "sha"), ("bad ru", "ru")]
        for name, how in bad:
            p = os.path.join(d, name.replace(" ", "_") + ".json")
            if how == "{":
                open(p, "w").write("{")
            elif how is not None:
                x = copy.deepcopy(doc)
                if how == "evr":
                    x["validations"][0]["evidence_refs"] = ["EVR-not-hex"]
                elif how == "sha":
                    x["validations"][0]["query_sha256"] = "abc"
                else:
                    x["contexts"][LAB_CTX]["release_update"] = "latest"
                json.dump(x, open(p, "w"))
            r = fv.load(p)
            assert not r["loaded"] and fv.assess(r, C("Q-DISC-IDENTITY-001", sha), T())["level"] == "DOCUMENTATION_ONLY", name


@test
def gateway_collect_get_evidence_and_describe_declare_field_validation():
    c = InProcClient()
    c.initialize()
    env, raw = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY})
    fvb = env["field_validation"]
    assert fvb["level"] == "FIELD_VALIDATED_OTHER_CONTEXT", fvb          # fixture-primary-19c is NON_CDB without ASM
    assert {d["dimension"] for d in fvb["differences"]} == {"container", "asm"} and fvb["validated_context"]["release_update"] == "19.32"
    env2, _ = c.call("diagnostics.get_evidence", {"evidence_ref": env["evidence_refs"][0], "target_alias": PRIMARY})
    assert env2["field_validation"] == fvb
    env3, _ = c.call("diagnostics.describe_collector", {"collector_id": "Q-DISC-IDENTITY-001"})
    assert env3["field_validation"]["validated_contexts"][0]["context_id"] == LAB_CTX
    assert env3["field_validation"]["by_target"][PRIMARY] == "FIELD_VALIDATED_OTHER_CONTEXT"
    env4, _ = c.call("diagnostics.describe_collector", {"collector_id": "Q-ORA-PROCESSES-SUMMARY-001"})
    assert env4["field_validation"]["validated_contexts"] == [] and set(env4["field_validation"]["by_target"].values()) == {"DOCUMENTATION_ONLY"}


@test
def analyze_incident_caps_conclusions_at_probable_cause_when_evidence_is_not_field_validated():
    c = InProcClient()
    c.initialize()
    refs = []
    cols = ("Q-ORA-DIAGNOSTICS-ALERTLOG-001", "os.get_process_limits", "os.get_oracle_process_summary", "Q-ORA-RESOURCE-LIMITS-001")
    for col in cols:                       # the p13 end-to-end incident set, plus one lab-validated query
        env, _ = c.call("diagnostics.collect", {"collector_id": col, "target_alias": PRIMARY})
        refs += env["evidence_refs"]
    env, raw = c.call("diagnostics.analyze_incident", {"evidence_refs": refs, "target_alias": PRIMARY})
    assert not raw["isError"], env
    fvb = env["field_validation"]
    assert fvb["confidence_ceiling"] == "PROBABLE_CAUSE" and fvb["all_field_validated"] is False
    assert {x["collector_id"]: x["level"] for x in fvb["per_evidence"]} == {
        "Q-ORA-DIAGNOSTICS-ALERTLOG-001": "DOCUMENTATION_ONLY", "os.get_process_limits": "DOCUMENTATION_ONLY",
        "os.get_oracle_process_summary": "DOCUMENTATION_ONLY", "Q-ORA-RESOURCE-LIMITS-001": "FIELD_VALIDATED_OTHER_CONTEXT"}
    lim = [l for l in env["limitations"] if l.startswith("EVIDENCE_NOT_FIELD_VALIDATED:")]
    assert len(lim) == 4 and all("PROBABLE_CAUSE" in l for l in lim), env["limitations"]


@test
def the_policy_contract_and_orchestrator_state_the_ceiling():
    pol = open(os.path.join(ROOT, "policies", "field-validation-policy.md"), encoding="utf-8").read()
    con = open(os.path.join(ROOT, "docs", "CONTRACTS.md"), encoding="utf-8").read()
    orc = open(os.path.join(ROOT, "agents", "oracle-operations-orchestrator.md"), encoding="utf-8").read()
    for text in (pol, con, orc):
        assert "PROBABLE_CAUSE" in text and "validation_level" in text or "PROBABLE_CAUSE" in text and "FIELD_VALIDATED" in text
    for lvl in fv.LEVELS:
        assert lvl in pol and lvl in con


if __name__ == "__main__":
    raise SystemExit(run_all())
