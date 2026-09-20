"""Phase 13 — mutation-testing control. Each defense is disabled at runtime (in-process) and the scenario that
protects it MUST then fail; a scenario that still passes under its mutation would be decorative.
(Same idea as tests/test_rca_mutation_testing_control.sh and tests/test_p12_mutation_controls.sh.)"""
import contextlib
import json
import os

from tests.p13 import harness
from tests.p13.harness import MARKER, PRIMARY, InProcClient, make_fixture_dir, make_targets_file, default_targets, run_all, test, tmpdir

harness._TESTS.clear()


@contextlib.contextmanager
def patched(*patches):
    saved = [(o, a, getattr(o, a)) for o, a, _ in patches]
    try:
        for o, a, r in patches:
            setattr(o, a, r)
        yield
    finally:
        for o, a, v in saved:
            setattr(o, a, v)


def must_fail_under(patches, scenario, label):
    """The scenario passes on the real code (checked first) and must FAIL with the defense disabled."""
    scenario()                                                # sanity: the defense is really protecting something
    with patched(*patches):
        try:
            scenario()
        except AssertionError:
            return          # the scenario's own assertion noticed the mutation (a crash elsewhere would NOT count)
    raise AssertionError(f"MUTATION SURVIVED: {label} — '{scenario.__name__}' still passed with the defense disabled")


# ---------------------------------------------------------------- scenarios (run in-process)
def _ready(**kw):
    c = InProcClient(**kw)
    c.initialize()
    return c


def scen_undeclared_fields_dropped():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {(PRIMARY, "Q-ORA-PROCESSES-SUMMARY-001"): [{"process_count": 5, "processes_limit": 10, "hostname": "prodhost01", "note": MARKER}]})
        c = _ready(fixtures=fx)
        env = c.collect("Q-ORA-PROCESSES-SUMMARY-001")
        assert env["evidence"]["rows"] == [{"process_count": 5, "processes_limit": 10}]
        assert "prodhost01" not in json.dumps(env) and MARKER not in json.dumps(env)


def scen_schema_rejects_extra_params():
    c = _ready()
    env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": PRIMARY, "sql": "select 1 from dual"})
    assert res["isError"] and env["error"]["code"] == "E_ARGS_INVALID"


def scen_cross_target_evidence_denied():
    c = _ready()
    ref = c.collect("Q-DISC-IDENTITY-001")["evidence_refs"][0]
    env, res = c.call("diagnostics.get_evidence", {"evidence_ref": ref, "target_alias": "fixture-standby-19c"})
    assert res["isError"] and env["error"]["code"] == "E_EVIDENCE_NOT_FOUND"


def scen_unknown_version_is_environment_unknown():
    c = _ready()
    env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-unknown-version"})
    assert res["isError"] and env["capability_status"] == "ENVIRONMENT_UNKNOWN"


def scen_real_adapter_never_runs():
    with tmpdir() as d:
        real = dict(default_targets()["targets"][0], alias="real-oracle-enabled", adapter="oracle_sql", enabled=True, allowed_collectors=["Q-DISC-IDENTITY-001"])
        fx = make_fixture_dir(d, {("real-oracle-enabled", "Q-DISC-IDENTITY-001"): [{"version": "19.0.0.0.0"}]})
        c = _ready(targets=make_targets_file(d, [real]), fixtures=fx)
        env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "real-oracle-enabled"})
        assert res["isError"] and env["capability_status"] == "DISABLED"


def scen_unknown_signature_is_tokenized():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {(PRIMARY, "Q-ORA-DIAGNOSTICS-ALERTLOG-001"): [{"event_time": "2026-03-11T15:02:31Z", "signature": MARKER + "_SIG"}]})
        c = _ready(fixtures=fx)
        env = c.collect("Q-ORA-DIAGNOSTICS-ALERTLOG-001")
        assert MARKER not in json.dumps(env) and env["evidence"]["rows"][0]["signature"].startswith("SIG-")


def scen_identifiers_are_masked():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {(PRIMARY, "Q-DISC-IDENTITY-001"): [{"instance_name": "PRODINST01", "db_name": "PRODDB", "version": "19.0.0.0.0"}]})
        c = _ready(fixtures=fx)
        env = c.collect("Q-DISC-IDENTITY-001")
        assert "PRODINST01" not in json.dumps(env) and env["evidence"]["rows"][0]["instance_name"] == "inst-A1"


def scen_budget_enforced():
    c = _ready()
    c.collect("Q-ORA-RESOURCE-LIMITS-001", "fixture-tight-budget")
    c.collect("Q-ORA-RESOURCE-LIMITS-001", "fixture-tight-budget")
    env, res = c.call("diagnostics.collect", {"collector_id": "Q-DISC-IDENTITY-001", "target_alias": "fixture-tight-budget"})
    assert res["isError"] and env["error"]["code"] == "E_BUDGET_EXCEEDED"


def scen_oversize_rejected():
    c = _ready()
    out = c.raw(b'{"jsonrpc":"2.0","id":1,"method":"ping","params":{"pad":"' + b"A" * 1_200_000 + b'"}}')
    assert len(out) == 1 and "error" in out[0] and out[0]["error"]["message"] == "message exceeds the size limit"


def scen_preinit_rejected():
    c = InProcClient()
    r = c.request("tools/list")
    assert "error" in r and r["error"]["message"] == "server is not initialized"


def scen_text_fields_never_leave():
    with tmpdir() as d:
        fx = make_fixture_dir(d, {(PRIMARY, "Q-ORA-DIAGNOSTICS-ALERTLOG-001"): [{"event_time": "2026-03-11T15:02:31Z", "signature": "ORA-27300", "message": "fork failed " + MARKER}]})
        c = _ready(fixtures=fx)
        env = c.collect("Q-ORA-DIAGNOSTICS-ALERTLOG-001")
        assert "message" not in env["evidence"]["columns"] and MARKER not in json.dumps(env)


# ---------------------------------------------------------------- mutations
@test
def default_deny_of_undeclared_fields_is_protected():
    import mcp_gateway.evidence as ev
    real = ev.sanitize_rows

    def keep_everything(collector, raw_rows, scope, alias, cap):
        out = real(collector, raw_rows, scope, alias, cap)
        out["rows"] = [dict(r, **{k: v for k, v in raw.items() if k not in r and isinstance(v, (str, int))}) for r, raw in zip(out["rows"], raw_rows)]
        return out
    import mcp_gateway.gateway as gw
    must_fail_under([(gw, "sanitize_rows", keep_everything)], scen_undeclared_fields_dropped, "default deny")


@test
def strict_argument_schemas_are_protected():
    import mcp_gateway.gateway as gw
    must_fail_under([(gw, "validate", lambda value, schema, depth=0: value)], scen_schema_rejects_extra_params, "additionalProperties:false")


@test
def evidence_scope_binding_is_protected():
    from mcp_gateway.evidence import EvidenceStore
    real = EvidenceStore.get

    def ignore_scope(self, ref, session_id, target_alias):
        e = self._items.get(ref)
        if e is None:
            from mcp_gateway.common import GatewayError
            raise GatewayError("E_EVIDENCE_NOT_FOUND")
        return e
    must_fail_under([(EvidenceStore, "get", ignore_scope)], scen_cross_target_evidence_denied, "evidence scope")


@test
def version_and_environment_gating_is_protected():
    import mcp_gateway.gateway as gw
    must_fail_under([(gw, "evaluate_capability", lambda target, col, adapter_status: "SUPPORTED")], scen_unknown_version_is_environment_unknown, "capability gate")


@test
def real_adapters_being_disabled_is_protected():
    from mcp_gateway.adapters import AdapterRegistry
    real_get = AdapterRegistry.get

    def any_adapter_is_fixture(self, name):
        return real_get(self, "fixture")
    must_fail_under([(AdapterRegistry, "get", any_adapter_is_fixture), (AdapterRegistry, "status_of", lambda self, name: "VERIFIED_FIXTURE")],
                    scen_real_adapter_never_runs, "real adapters disabled")


@test
def signature_allowlist_and_tokenization_is_protected():
    import mcp_gateway.evidence as ev
    must_fail_under([(ev, "classify_signature", lambda raw, scope, certified: ("CERTIFIED", raw, None))], scen_unknown_signature_is_tokenized, "signature allowlist")


@test
def identifier_masking_is_protected():
    import mcp_gateway.evidence as ev
    real = ev.SessionScope.alias
    must_fail_under([(ev.SessionScope, "alias", lambda self, target, prefix, value: value)], scen_identifiers_are_masked, "MASK policy")


@test
def per_target_budgets_are_protected():
    import mcp_gateway.gateway as gw
    real = gw.Gateway._authorize

    def no_budget(self, session, target, collector, count_call=True):
        session.target_calls, session.target_rows, session.calls = {}, {}, 0
        return real(self, session, target, collector, count_call)
    must_fail_under([(gw.Gateway, "_authorize", no_budget)], scen_budget_enforced, "budget")


@test
def message_size_limit_is_protected():
    import mcp_gateway.server as srv
    must_fail_under([(srv, "MAX_MESSAGE_BYTES", 10 ** 9)], scen_oversize_rejected, "message size limit")


@test
def lifecycle_ordering_is_protected():
    import mcp_gateway.server as srv
    real_init = srv.McpServer.__init__

    def ready_from_start(self, *a, **k):
        real_init(self, *a, **k)
        self.state = "READY"
        from mcp_gateway.gateway import Session
        self.session = Session()
    must_fail_under([(srv.McpServer, "__init__", ready_from_start)], scen_preinit_rejected, "initialize-first lifecycle")


@test
def free_text_fields_having_no_path_to_the_model_is_protected():
    import mcp_gateway.evidence as ev
    real = ev._sanitize_value

    def text_passthrough(spec, raw, scope, target):
        if spec["type"] == "text" and isinstance(raw, str):
            return True, raw
        return real(spec, raw, scope, target)

    import mcp_gateway.catalog as cat
    real_cols = cat.load_collectors

    def leaky_columns(path=cat.DEFAULT_COLLECTORS_FILE):
        cols = real_cols(path)
        for c in cols.values():
            for f in c.output_fields.values():
                if f["type"] == "text":
                    f["policy"] = "KEEP"
        return cols
    import mcp_gateway.cli as cli
    must_fail_under([(ev, "_sanitize_value", text_passthrough), (cli.catalog, "load_collectors", leaky_columns)], scen_text_fields_never_leave, "text is DROP-only")


if __name__ == "__main__":
    raise SystemExit(run_all())
