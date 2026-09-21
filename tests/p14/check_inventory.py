"""Phase 14 — inventory: the machine-readable registry must match the running code, claims need evidence, and
version handling is numeric, fail-closed and never assumes 'latest'."""
import copy
import json
import os

from tests.p14.harness import PRIMARY, ROOT, ProcClient, default_targets, make_targets_file, run_all, test, tmpdir, write_json


def reg():
    from release_readiness import registry
    return registry.load_registry(ROOT)


def codes(findings):
    return sorted({f["code"] for f in findings})


def verify(doc):
    from release_readiness import registry
    return registry.verify_registry(ROOT, registry=doc)["findings"]


def comp(doc, cid):
    return next(c for c in doc["components"] if c["id"] == cid)


@test
def the_registry_is_consistent_with_the_running_code_and_registries():
    from release_readiness import registry
    res = registry.verify_registry(ROOT)
    assert res["findings"] == [], res["findings"][:5]
    assert sum(res["counts"].values()) == len(reg()["components"]) == 75


@test
def registered_tools_equal_the_real_tools_list_over_stdio():
    c = ProcClient()
    try:
        c.initialize()
        listed = sorted(t["name"] for t in c.request("tools/list")["result"]["tools"])
    finally:
        c.close()
    registered = sorted(x["tool_name"] for x in reg()["components"] if x["kind"] == "mcp_tool")
    assert listed == registered and len(listed) == 5


@test
def every_agent_collector_adapter_domain_and_skill_domain_is_registered():
    from release_readiness import registry
    facts = registry.actual_facts(ROOT)
    kinds = {}
    for x in reg()["components"]:
        kinds.setdefault(x["kind"], set()).add(x["id"])
    assert len(kinds["agent"]) == len(facts["agents"]) == 18
    assert len(kinds["collector"]) == len(facts["collectors"]) == 7
    assert len(kinds["adapter"]) == len(facts["adapters"]) == 4
    assert len(kinds["domain"]) == len(facts["matrix"]) == 20
    assert len(kinds["skill_domain"]) == len(facts["skill_domains"]) == 16


@test
def an_overstated_adapter_maturity_is_rejected():
    doc = copy.deepcopy(reg())
    comp(doc, "adapter:oracle_sql")["maturity"] = "TESTED_WITH_SYNTHETIC_FIXTURES"
    comp(doc, "adapter:oracle_sql").pop("reason", None)
    assert "REG_MATURITY_OVERSTATED" in codes(verify(doc))
    doc = copy.deepcopy(reg())
    comp(doc, "adapter:os_readonly")["maturity"] = "CERTIFIED"
    assert {"REG_MATURITY_OVERSTATED", "REG_PILOT_RECORD_INVALID"} <= set(codes(verify(doc)))


@test
def a_stale_understated_adapter_maturity_is_reported_too():
    doc = copy.deepcopy(reg())
    comp(doc, "adapter:fixture")["maturity"] = "CONTRACT_ONLY"
    assert "REG_MATURITY_STALE" in codes(verify(doc))


@test
def anything_that_exists_in_code_but_not_in_the_registry_is_reported():
    doc = copy.deepcopy(reg())
    gone = {"mcp_tool:diagnostics.collect": "REG_TOOL_UNREGISTERED", "collector:Q-DG-STATS-001": "REG_COLLECTOR_UNREGISTERED",
            "agent:capacity-analyst": "REG_AGENT_UNREGISTERED", "domain:rman": "REG_DOMAIN_UNREGISTERED", "adapter:fixture": "REG_ADAPTER_UNREGISTERED",
            "engine:rca_engine": "REG_ENGINE_UNREGISTERED", "skill_domain:oracle": "REG_SKILL_DOMAIN_UNREGISTERED"}
    doc["components"] = [c for c in doc["components"] if c["id"] not in gone]
    assert set(gone.values()) <= set(codes(verify(doc))), codes(verify(doc))


@test
def registry_entries_for_things_that_do_not_exist_are_reported():
    doc = copy.deepcopy(reg())
    for extra in ({"id": "mcp_tool:diagnostics.exec_sql", "kind": "mcp_tool", "domain": "x", "maturity": "CONTRACT_ONLY", "notes": "n", "test_refs": [], "tool_name": "diagnostics.exec_sql"},
                  {"id": "agent:ghost", "kind": "agent", "domain": "x", "maturity": "CONTRACT_ONLY", "notes": "n", "test_refs": [], "agent_id": "ghost"},
                  {"id": "adapter:magic", "kind": "adapter", "domain": "x", "maturity": "CONTRACT_ONLY", "notes": "n", "test_refs": [], "adapter_name": "magic"}):
        doc["components"].append(extra)
    found = set(codes(verify(doc)))
    assert {"REG_TOOL_NOT_IN_CODE", "REG_AGENT_NOT_IN_REGISTRY_MD", "REG_ADAPTER_NOT_IN_CODE"} <= found


@test
def a_maturity_claim_without_its_evidence_is_rejected():
    doc = copy.deepcopy(reg())
    comp(doc, "collector:Q-DISC-IDENTITY-001")["test_refs"] = []
    comp(doc, "mcp_tool:diagnostics.collect")["test_refs"] = ["tests/test_does_not_exist.sh"]
    comp(doc, "adapter:oracle_sql").pop("reason")
    comp(doc, "agent:knowledge-curator")["maturity"] = "SUPERB"
    found = set(codes(verify(doc)))
    assert {"REG_EVIDENCE_MISSING", "REG_TEST_REF_MISSING", "REG_REASON_MISSING", "REG_MATURITY_UNKNOWN"} <= found, found


@test
def a_real_environment_claim_needs_a_valid_pilot_record_and_none_exists_today():
    from release_readiness import registry
    real = reg()
    assert not [c for c in real["components"] if c["maturity"] in ("PILOT_VALIDATED", "CERTIFIED")], "no component may claim a real-environment state today"
    doc = copy.deepcopy(real)
    comp(doc, "agent:oracle-dba-analyst")["maturity"] = "PILOT_VALIDATED"
    assert "REG_PILOT_RECORD_INVALID" in codes(verify(doc))
    with tmpdir() as d:
        ev = os.path.join(d, "ev.txt")
        open(ev, "w").write("synthetic pilot evidence")
        from release_readiness.common import sha256_file
        good = {"record_id": "PIL-LAB-001", "component_id": "adapter:oracle_sql", "environment_class": "NON_PRODUCTION_REPRESENTATIVE", "oracle_versions": ["19c"],
                "platform": "Linux", "readonly_privileges_validated": True, "sanitization_boundary_validated": True,
                "integration_run_id": "RUN-20260101T000000Z-abcdef12", "evidence_files": [{"path": "ev.txt", "sha256": sha256_file(ev)}]}
        assert registry.validate_pilot_record(good, d, "adapter:oracle_sql", need_acceptance=False) == []
        assert registry.validate_pilot_record(good, d, "adapter:oracle_sql", need_acceptance=True) == ["PILOT_ADMINISTRATOR_ACCEPTANCE"]
        good["administrator_acceptance"] = {"reviewer_id": "REV-ADMIN-01", "decision": "ACCEPTED", "decision_at_utc": "2026-01-02T00:00:00Z",
                                            "verification": "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED"}
        assert registry.validate_pilot_record(good, d, "adapter:oracle_sql", need_acceptance=True) == []
        bad_cases = {"PILOT_ENVIRONMENT_CLASS": dict(good, environment_class="PRODUCTION"), "PILOT_READONLY_NOT_VALIDATED": dict(good, readonly_privileges_validated=False),
                     "PILOT_SANITIZATION_NOT_VALIDATED": dict(good, sanitization_boundary_validated="yes"), "PILOT_COMPONENT_MISMATCH": dict(good, component_id="adapter:other"),
                     "PILOT_EVIDENCE_FILE_HASH": dict(good, evidence_files=[{"path": "ev.txt", "sha256": "0" * 64}]),
                     "PILOT_EVIDENCE_FILE_ENTRY": dict(good, evidence_files=[{"path": "../ev.txt", "sha256": "0" * 64}]),
                     "PILOT_ORACLE_VERSIONS": dict(good, oracle_versions=["latest"]), "PILOT_PLATFORM": dict(good, platform="ANY"),
                     "PILOT_INTEGRATION_RUN_ID": dict(good, integration_run_id="run-1")}
        for want, rec in bad_cases.items():
            got = registry.validate_pilot_record(rec, d, "adapter:oracle_sql", need_acceptance=True)
            assert got and (want.replace("COMPONENT_MISMATCH", "RECORD_COMPONENT_MISMATCH") in got or want in got), (want, got)


@test
def the_registry_schema_rejects_missing_extra_and_duplicate_entries():
    doc = copy.deepcopy(reg())
    doc["components"][0]["surprise"] = 1
    doc["components"].append(copy.deepcopy(doc["components"][1]))
    del doc["components"][2]["notes"]
    found = codes(verify(doc))
    assert "REG_SCHEMA" in found and "REG_DUPLICATE_ID" in found
    from release_readiness import registry
    from release_readiness.common import ReadinessError
    with tmpdir() as d:
        p = os.path.join(d, "r.json")
        for raw in ('{"a": 1, "a": 2}', '{"x": NaN}', "[1,2", ""):
            open(p, "w").write(raw)
            try:
                registry.load_json_strict(p)
            except ReadinessError as e:
                assert e.code == "E_INPUT"
                continue
            raise AssertionError(f"accepted hostile JSON: {raw!r}")


@test
def version_resolution_is_numeric_and_never_assumes_latest():
    from mcp_gateway.versions import compare_versions, family_of
    good = {"19.0.0.0.0": "19c", "19c": "19c", "19C": "19c", "11.2.0.4": "11g", "11.2.0.10": "11g", "12.1.0.2": "12c", "12.2.0.1": "12c",
            "18.0.0.0.0": "18c", "21.3": "21c", "23ai": "23ai", "23AI": "23ai", "23.4.0.24.05": "23ai", "10.2.0.5": "10g", "10": "10g"}
    for raw, want in good.items():
        assert family_of(raw) == want, ascii(raw)
    for raw in ("latest", "newest", "current", "", " ", "9.2.0.8", "8i", "99", "19g", "23c", "19.0.0.0.0.0.0.0", "19.0; drop table t", "１９", "19\x00", "v19",
                None, 19, 19.0, True, [], {}, "1" * 100, "-19", "19.-1"):
        assert family_of(raw) is None, ascii(raw)
    assert compare_versions("9.2", "10.1") == -1, "lexicographic order would say 9.2 > 10.1"
    assert compare_versions("11.2.0.10", "11.2.0.4") == 1, "lexicographic order would say 11.2.0.10 < 11.2.0.4"
    assert compare_versions("19", "19.0.0") == 0 and compare_versions("19.1", "19.0") == 1
    assert compare_versions("latest", "19") is None and compare_versions("19", None) is None


@test
def missing_version_metadata_fails_closed_instead_of_meaning_every_version():
    from mcp_gateway import catalog
    spec = {"collector_id": "Q-X-TEST-001", "kind": "sql_query", "domain": "oracle", "title": "t", "row_limit": 5, "params": {},
            "output_fields": {"a": {"type": "integer", "policy": "KEEP"}}, "adapters": {}}
    tgt = catalog.Target({"alias": "tgt-test", "adapter": "fixture", "enabled": True, "oracle_version": "19c", "role": "PRIMARY", "allowed_collectors": ["Q-X-TEST-001"]})
    for meta in ({}, {"supported_oracle_versions": []}, {"supported_oracle_versions": "latest"}, {"supported_oracle_versions": None}):
        c = catalog.Collector(spec, meta)
        assert c.supported_oracle_versions == [], meta
        assert catalog.evaluate_capability(tgt, c, "VERIFIED_FIXTURE") == "UNSUPPORTED", meta
    for bad in (["latest"], ["19g"], ["9i"], ["19c; x"]):
        try:
            catalog.Collector(spec, {"supported_oracle_versions": bad})
        except RuntimeError:
            continue
        raise AssertionError(f"accepted invalid version metadata {bad}")
    os_spec = dict(spec, kind="semantic_os")
    assert catalog.Collector(os_spec, None).supported_oracle_versions == [], "an OS collector must declare oracle_version_scope explicitly"
    assert catalog.Collector(dict(os_spec, oracle_version_scope="ANY"), None).supported_oracle_versions == list(catalog.ORACLE_VERSIONS)
    narrowed = catalog.Collector(dict(spec, supported_oracle_versions=["19c", "21c"]), {"supported_oracle_versions": ["11g", "19c"]})
    assert narrowed.supported_oracle_versions == ["19c"], "a collector may only narrow the certified query, never widen it"


def _target(alias, **kw):
    return dict(default_targets()["targets"][0], alias=alias, **kw)


@test
def the_alert_log_collector_is_not_offered_for_10g_through_the_real_gateway():
    with tmpdir() as d:
        tf = make_targets_file(d, [_target("legacy-10g-target", oracle_version="10g", allowed_collectors=["Q-ORA-DIAGNOSTICS-ALERTLOG-001", "Q-DISC-IDENTITY-001"])])
        c = ProcClient(targets=tf)
        try:
            c.initialize()
            env, res = c.call("diagnostics.collect", {"collector_id": "Q-ORA-DIAGNOSTICS-ALERTLOG-001", "target_alias": "legacy-10g-target"})
            assert res["isError"] and env["error"]["code"] == "E_CAPABILITY" and env["capability_status"] == "UNSUPPORTED"
            caps = c.call("diagnostics.list_capabilities", {})[0]["targets"][0]["capabilities"]
            assert caps["Q-ORA-DIAGNOSTICS-ALERTLOG-001"] == "UNSUPPORTED" and caps["Q-DISC-IDENTITY-001"] in ("SUPPORTED", "DISABLED")
        finally:
            c.close()


@test
def target_versions_accept_full_release_strings_and_refuse_latest_and_unsupported_majors():
    from mcp_gateway import catalog
    cols = catalog.load_collectors()
    with tmpdir() as d:
        for raw, fam in (("19.0.0.0.0", "19c"), ("12.2.0.1", "12c"), ("11.2.0.4", "11g"), ("23ai", "23ai"), ("21", "21c")):
            t = catalog.load_targets(make_targets_file(d, [_target("version-probe", oracle_version=raw)]), cols)["version-probe"]
            assert t.oracle_version == fam, raw
        for raw in ("latest", "9.2.0.8", "19c; x", "", "99"):
            try:
                catalog.load_targets(make_targets_file(d, [_target("version-probe", oracle_version=raw)]), cols)
            except RuntimeError:
                continue
            raise AssertionError(f"accepted target version {raw!r}")


@test
def missing_privileges_are_declared_facts_and_deny_with_a_safe_status():
    with tmpdir() as d:
        tf = make_targets_file(d, [_target("no-privilege-target", missing_privileges=["Q-DISC-IDENTITY-001"])])
        import shutil
        fx = os.path.join(d, "fixtures", "no-privilege-target")
        os.makedirs(fx)
        for cid in ("Q-DISC-IDENTITY-001", "Q-ORA-RESOURCE-LIMITS-001"):
            shutil.copy(os.path.join(ROOT, "mcp_gateway", "fixtures", PRIMARY, cid + ".json"), fx)
        c = ProcClient(targets=tf, fixtures=os.path.join(d, "fixtures"))
        try:
            c.initialize()
            env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "no-privilege-target"})
            assert res["isError"] and env["error"]["code"] == "E_CAPABILITY" and env["capability_status"] == "INSUFFICIENT_PRIVILEGES"
            assert "Traceback" not in json.dumps(env) and env["evidence_refs"] == []
            ok = c.call("diagnostics.collect", {"collector_id": "Q-ORA-RESOURCE-LIMITS-001", "target_alias": "no-privilege-target"})[0]
            assert ok["status"] in ("OK", "DEGRADED"), "only the collector with missing privileges is denied"
        finally:
            c.close()
        from mcp_gateway import catalog
        for bad in ({"missing_privileges": ["Q-NOT-CERTIFIED-001"]}, {"missing_privileges": "all"}):
            try:
                catalog.load_targets(make_targets_file(d, [_target("bad-privileges", **bad)]), catalog.load_collectors())
            except RuntimeError:
                continue
            raise AssertionError("accepted an invalid missing_privileges declaration")


@test
def every_maturity_state_has_a_definition_and_the_order_is_complete():
    from release_readiness.common import MATURITY_DEFINITIONS, MATURITY_ORDER, REAL_ENVIRONMENT_STATES
    assert set(MATURITY_DEFINITIONS) == set(MATURITY_ORDER) and len(MATURITY_ORDER) == 6
    assert MATURITY_ORDER.index("TESTED_WITH_SYNTHETIC_FIXTURES") < MATURITY_ORDER.index("PILOT_VALIDATED") < MATURITY_ORDER.index("CERTIFIED")
    assert set(REAL_ENVIRONMENT_STATES) == {"PILOT_VALIDATED", "CERTIFIED"}
    assert all(len(v) > 40 for v in MATURITY_DEFINITIONS.values())


if __name__ == "__main__":
    raise SystemExit(run_all())
