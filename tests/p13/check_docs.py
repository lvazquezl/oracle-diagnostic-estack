"""Phase 13 — declarative documentation consistency: what the docs, manifest and example config claim must match the REAL gateway."""
import json
import os

from tests.p13.harness import ROOT, ProcClient, run_all, test


def read(rel):
    with open(os.path.join(ROOT, rel), "rb") as f:
        return f.read().decode("utf-8")


DOC = "docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md"


@test
def documented_tools_match_the_real_tools_list_exactly():
    c = ProcClient()
    c.initialize()
    tools = [t["name"] for t in c.request("tools/list")["result"]["tools"]]
    c.close()
    assert len(tools) == 5
    for rel in (DOC, "mcp/tool-manifest.md", "mcp/README.md"):
        text = read(rel)
        missing = [t for t in tools if t not in text]
        assert not missing, (rel, missing)


@test
def every_shipped_collector_and_adapter_status_is_documented():
    from mcp_gateway import catalog
    text = read(DOC)
    missing = [cid for cid in catalog.load_collectors() if cid not in text]
    assert not missing, missing
    for status in ("VERIFIED_FIXTURE", "CONTRACT_ONLY", "DISABLED", "NOT_INTEGRATION_TESTED"):
        assert status in text, status


@test
def the_example_claude_config_is_valid_json_without_secrets_or_real_paths():
    cfg = json.loads(read("mcp/claude-code.mcp.example.json"))
    srv = cfg["mcpServers"]["oracle-diagnostic-estack"]
    assert srv["command"] == "python" and srv["args"] == ["-m", "mcp_gateway"]
    assert srv["cwd"].startswith("<") and set(srv["env"]) <= {"PYTHONUTF8", "PYTHONDONTWRITEBYTECODE"}
    flat = json.dumps(cfg).lower()
    for banned in ("password", "secret", "token", "wallet", "dsn", "jdbc", "users\\", "/home/"):
        assert banned not in flat, banned


@test
def the_docs_state_the_required_limits_and_never_promise_real_environment_coverage():
    text = read(DOC)
    for needed in ("MCP local", "modelo local", "no autentica", "NOT_EXECUTED_BY_ESTACK", "STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED",
                   "Rollback manual", "NO ejecutado"):
        assert needed in text, needed
    assert "v0.13.0-mcp-diagnostic-gateway" in text


if __name__ == "__main__":
    raise SystemExit(run_all())
