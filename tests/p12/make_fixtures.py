"""
tests/p12/make_fixtures.py — regenerates the SYNTHETIC Phase 12 fixtures under tests/fixtures/p12/.
Committed for reproducibility: the JSON fixtures are the artifacts the tests use; this script documents
how they were built. Every value is synthetic (no real host, credential, hash or business data).
"""
import copy
import json
import os

D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "fixtures", "p12")
os.makedirs(os.path.join(D, "incidents"), exist_ok=True)


def w(name, obj):
    with open(os.path.join(D, name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")


def rule(rid, domain, stmt, chain, sigs, sup, con, action):
    return {"rule_id": rid, "domain": domain, "statement": stmt, "causal_chain": chain,
            "symptom_match": {"signature_any": sigs},
            "supporting_conditions": [dict(domain=d, attribute=a, op=o, value=v, description=ds) for (d, a, o, v, ds) in sup],
            "contradicting_conditions": [dict(domain=d, attribute=a, op=o, value=v, critical=True, description=ds) for (d, a, o, v, ds) in con],
            "temporal_proof_condition": None, "min_independent_sources": 2, "manual_actions": [action]}


rules = {"rules_version": "p12-synthetic-1.0.0", "rules": [
    rule("RULE-P12-DG-TRANSPORT-001", "dataguard", "Redo transport degradation to the standby caused a growing apply/transport lag",
         ["redo transport to the standby slows or fails", "standby falls behind the primary", "lag exceeds the accepted threshold"], ["ORA-16810"],
         [("dataguard", "transport_lag_seconds", ">=", 900, "transport lag above the accepted threshold"),
          ("network", "redo_transport_errors_observed", "==", True, "redo transport errors observed on the network path")],
         [("dataguard", "transport_lag_seconds", "<", 30, "lag well below the threshold contradicts degradation")],
         {"action_summary": "Review the redo transport configuration with the network team and adjust it after approval",
          "precheck": "Confirm current transport status and lag on each affected standby",
          "risk": "A transport change can interrupt redo shipping for the affected standby",
          "postcheck": "Confirm transport is healthy and lag returns below the accepted threshold", "requires_change": True}),
    rule("RULE-P12-ASM-DISKGROUP-001", "asm", "Disk group free space exhaustion prevented file allocation",
         ["disk group free space reaches the floor", "allocation requests fail", "dependent databases report space errors"], ["ORA-15041"],
         [("asm", "diskgroup_free_percent", "<=", 5, "disk group free space at or below the floor"),
          ("os", "asm_path_errors_observed", "==", True, "path errors observed for the disk group members")],
         [("asm", "diskgroup_free_percent", ">", 30, "ample free space contradicts exhaustion")],
         {"action_summary": "Add capacity to the affected disk group after storage team review",
          "precheck": "Confirm free space, redundancy and rebalance state for the disk group",
          "risk": "Capacity operations trigger rebalance activity that affects I/O",
          "postcheck": "Confirm free space and that rebalance completed without errors", "requires_change": True}),
    rule("RULE-P12-PDB-VIOLATION-001", "multitenant", "Open plug-in violations left the PDB in restricted mode",
         ["plug-in violations remain unresolved", "PDB opens in restricted mode", "application sessions are refused"], ["ORA-65040"],
         [("multitenant", "pdb_open_mode_restricted", "==", True, "PDB opened in restricted mode"),
          ("multitenant", "plugin_violations_open", "==", True, "open plug-in violations recorded")],
         [("multitenant", "pdb_open_mode_restricted", "==", False, "PDB not restricted contradicts the cause")],
         {"action_summary": "Resolve the open plug-in violations for the affected PDB after review",
          "precheck": "List the recorded violations and their impact for the PDB",
          "risk": "Resolving a violation can change PDB configuration and require a reopen",
          "postcheck": "Confirm the PDB opens read write without restricted mode", "requires_change": True}),
    rule("RULE-P12-RMAN-FRA-001", "rman", "Fast recovery area exhaustion blocked archived log deletion and backups",
         ["FRA usage reaches the limit", "archived logs cannot be deleted", "backups fail with space errors"], ["RMAN-03009"],
         [("rman", "fra_used_percent", ">=", 98, "FRA usage at or above the limit"),
          ("rman", "archivelog_deletion_blocked", "==", True, "archived log deletion blocked by retention")],
         [("rman", "fra_used_percent", "<", 50, "low FRA usage contradicts exhaustion")],
         {"action_summary": "Review the FRA size and retention policy with the backup owner and adjust it after approval",
          "precheck": "Confirm FRA usage, retention policy and backup status",
          "risk": "Retention changes affect recoverability and must be reviewed",
          "postcheck": "Confirm FRA usage decreases and the next backup completes", "requires_change": True}),
    rule("RULE-P12-SEC-LOCK-001", "security", "A locked service account caused authentication failures",
         ["failed login attempts lock the service account", "the application cannot authenticate", "service disruption"], ["ORA-28000"],
         [("security", "service_account_locked", "==", True, "service account recorded as locked"),
          ("security", "failed_login_burst_observed", "==", True, "burst of failed logins observed")],
         [("security", "service_account_locked", "==", False, "account not locked contradicts the cause")],
         {"action_summary": "Unlock the affected service account after confirming the origin of the failed logins with the security team",
          "precheck": "Confirm account status and the source of the failed login attempts",
          "risk": "Unlocking without finding the source can repeat the lock or hide an attack",
          "postcheck": "Confirm the application authenticates and no new lock occurs", "requires_change": True}),
]}
w("rules_cross_domain.json", rules)


def inc(n, sig, a1, a2):
    dom1, at1, v1 = a1
    dom2, at2, v2 = a2
    return {"incident": {"id": f"INC-20260320-{n:03d}", "target_id": "T-SYNTHETIC-DB", "symptom_description": "synthetic cross-domain incident",
                         "declared_evidence_refs": ["EVD-1", "EVD-2", "EVD-3"]},
            "evidence": [
                {"evidence_id": "EVD-1", "domain": "oracle", "source_id": "alert-log-parser", "timestamp": "2026-03-20T10:00:30+00:00",
                 "event_type": "ALERT_TRIGGERED", "signature": sig, "summary": "synthetic alert", "attributes": {}},
                {"evidence_id": "EVD-2", "domain": dom1, "source_id": f"{dom1}-collector-a", "timestamp": "2026-03-20T10:00:00+00:00",
                 "event_type": "SYMPTOM_OBSERVED", "summary": "synthetic observation", "attributes": {at1: v1}},
                {"evidence_id": "EVD-3", "domain": dom2, "source_id": f"{dom2}-collector-b", "timestamp": "2026-03-20T10:00:10+00:00",
                 "event_type": "SYMPTOM_OBSERVED", "summary": "synthetic observation", "attributes": {at2: v2}}]}


w("incidents/dataguard_confirmed.json", inc(1, "ORA-16810", ("dataguard", "transport_lag_seconds", 1800), ("network", "redo_transport_errors_observed", True)))
w("incidents/asm_confirmed.json", inc(2, "ORA-15041", ("asm", "diskgroup_free_percent", 3), ("os", "asm_path_errors_observed", True)))
w("incidents/multitenant_confirmed.json", inc(3, "ORA-65040", ("multitenant", "pdb_open_mode_restricted", True), ("multitenant", "plugin_violations_open", True)))
w("incidents/rman_confirmed.json", inc(4, "RMAN-03009", ("rman", "fra_used_percent", 99), ("rman", "archivelog_deletion_blocked", True)))
w("incidents/security_confirmed.json", inc(5, "ORA-28000", ("security", "service_account_locked", True), ("security", "failed_login_burst_observed", True)))
w("incidents/network_listener_confirmed.json", {
    "incident": {"id": "INC-20260320-007", "target_id": "T-SYNTHETIC-DB", "symptom_description": "synthetic listener hang",
                 "declared_evidence_refs": ["EVD-1", "EVD-2", "EVD-3"]},
    "evidence": [
        {"evidence_id": "EVD-1", "domain": "oracle", "source_id": "client-error-parser", "timestamp": "2026-03-20T10:00:30+00:00",
         "event_type": "ALERT_TRIGGERED", "signature": "ORA-12537", "summary": "synthetic connect failure", "attributes": {}},
        {"evidence_id": "EVD-2", "domain": "network", "source_id": "listener-probe", "timestamp": "2026-03-20T10:00:00+00:00",
         "event_type": "SYMPTOM_OBSERVED", "summary": "synthetic probe", "attributes": {"listener_process_responsive": False}},
        {"evidence_id": "EVD-3", "domain": "os", "source_id": "os-thread-audit", "timestamp": "2026-03-20T10:00:10+00:00",
         "event_type": "SYMPTOM_OBSERVED", "summary": "synthetic thread audit", "attributes": {"listener_thread_count_anomalous": True}}]})
w("incidents/capacity_forecast_only.json", {
    "incident": {"id": "INC-20260320-006", "target_id": "T-SYNTHETIC-DB", "symptom_description": "synthetic forecast: tablespace projected to fill",
                 "declared_evidence_refs": ["EVD-1"]},
    "evidence": [{"evidence_id": "EVD-1", "domain": "capacity", "source_id": "capacity-forecast", "timestamp": "2026-03-20T10:00:00+00:00",
                  "event_type": "CAPACITY_EVENT", "summary": "projected to reach the limit in the future", "attributes": {}}]})

ctx = {"schema_version": "1.0.0",
       "target": {"oracle_version": "19c", "release_update": "RU 19.22", "platform": "Oracle Linux 8",
                  "architecture": {"cdb": True, "rac": False, "dataguard": False, "asm": False}},
       "gates": {g: {"status": "PASS", "basis": "declared by the reviewer in the synthetic test context"}
                 for g in ("capability", "license", "privilege", "change_window")}}
w("change_context_all_pass.json", ctx)
c2 = copy.deepcopy(ctx)
c2["target"]["oracle_version"] = "12.2"
c2["target"]["release_update"] = "RU 12.2.0.1"
c2["gates"]["license"] = {"status": "UNKNOWN", "basis": "entitlement not confirmed"}
w("change_context_12_2_license_unknown.json", c2)
c3 = copy.deepcopy(ctx)
c3["gates"]["privilege"] = {"status": "FAIL", "basis": "reviewer lacks the required privilege"}
w("change_context_privilege_fail.json", c3)

ORDER = ["DETECT_GAP", "CHANGE_REQUEST", "GAP_ANALYSIS", "IMPACT_ANALYSIS", "PROPOSAL", "IMPLEMENT", "TEST",
         "SECURITY_VALIDATION", "REGRESSION_VALIDATION", "DOCUMENT"]


def stages(upto):
    return {s: {"status": "PASS", "evidence_note": "synthetic test evidence"} for s in ORDER[:upto]}


comp_ok = {c: "PASS" for c in ("version_coverage", "query_contract", "dictionary_columns", "architecture", "cost_and_license", "test_coverage")}
req = {"schema_version": "1.0.0", "change_request_id": "CHG-ESTACK-001", "title": "Extend the knowledge skill with a new retrieval filter",
       "gap_description": "Retrieval lacks a filter for architecture flags", "artifact_types": ["skill", "schema"],
       "proposer_id": "REV-PROPOSER01", "stages": stages(10), "compatibility": comp_ok}
w("estack_request_pending_review.json", req)
r2 = copy.deepcopy(req)
r2["stages"] = stages(7)
r2["stages"]["SECURITY_VALIDATION"] = {"status": "FAIL", "evidence_note": "synthetic finding"}
r2["compatibility"]["query_contract"] = "UNKNOWN"
w("estack_request_security_failed.json", r2)
r3 = copy.deepcopy(req)
r3["compatibility"]["dictionary_columns"] = "UNKNOWN"
w("estack_request_compat_unknown.json", r3)

w("assessment_basic.json", {
    "schema_version": "1.0.0", "assessment_id": "DOC-ASM-20260320", "title": "Synthetic healthcheck assessment", "target": {"oracle_version": "12.2"},
    "findings": [{"finding_id": "FND-ASM-001", "domain": "os", "title": "Process limit close to the configured maximum", "severity": "HIGH", "evidence_ids": ["EVD-1", "EVD-2"]},
                 {"finding_id": "FND-ASM-002", "domain": "rman", "title": "Archived log backup lag observed", "severity": "MEDIUM", "evidence_ids": ["EVD-3"], "status": "NOT_VERIFIED"}],
    "coverage": [{"area": "OS limits", "status": "SUPPORTED", "note": "collector available"},
                 {"area": "Data Guard", "status": "UNKNOWN", "note": "no evidence supplied"},
                 {"area": "Multitenant", "status": "UNSUPPORTED", "note": "non-CDB target"}],
    "license_notes": [{"feature": "Diagnostics features", "status": "UNKNOWN"}], "exceptions": ["Standby not assessed"], "pending": ["Confirm entitlement"]})
w("review_input_basic.json", {
    "schema_version": "1.0.0",
    "reported_actions": [{"text": "The administrator reports raising the process limit", "reported_by": "REV-TESTREV02", "reported_at_utc": "2026-03-11T18:00:00Z"}],
    "follow_ups": ["Add a monitor for process utilization"], "lessons": ["Review limits after capacity growth"]})
w("candidate_input_basic.json", {"schema_version": "1.0.0", "article_type": "KNOWN_ISSUE", "owner": "REV-OWNER0001", "proposer_ids": ["REV-PROPOSER01"]})
print("fixtures written:", sorted(os.listdir(D)))
