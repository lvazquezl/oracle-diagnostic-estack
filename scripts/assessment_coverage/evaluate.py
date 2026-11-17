"""CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001 — domain coverage of an assessment, computed from what was observed.

Source (governed by /change): config/assessment-coverage-model.json — every assessment domain, the items that make it
complete, the certified collectors that cover each item, the topology an item applies to, and the items that are
excluded on purpose by a named policy (never ad hoc).

Input (--observations FILE, JSON):
  {"topology": {"cdb": true, "rac": false, "asm": true, "dataguard": false, "standby": false},
   "license_status": {"diagnostics_pack": "CONFIRMED"},           # same keys and values as the gateway target
   "collectors": {"Q-ORA-UNDO-001": "OBSERVED", "Q-DG-STATS-001": "UNSUPPORTED", ...}}
  A collector state is OBSERVED (the gateway returned sanitized evidence, zero rows included), DEGRADED (evidence
  with gateway limitations, e.g. ROWS_TRUNCATED_TO_LIMIT: it counts as obtained and the item lists it under
  `degraded`, so the specialist review can decide whether to lower the domain), FAILED, or the
  gateway capability_status (UNSUPPORTED, LICENSE_RESTRICTED, INSUFFICIENT_PRIVILEGES, ENVIRONMENT_UNKNOWN,
  DISABLED, NOT_APPLICABLE). A collector that is not listed was NOT_RUN.

Rules (docs/ASSESSMENT_COVERAGE_MODEL.md):
  item    EXCLUDED_BY_POLICY when the model declares it; NOT_APPLICABLE when its topology does not hold or every
          collector is NOT_APPLICABLE; OBTAINED when any collector was OBSERVED; EXCLUDED_BY_POLICY
          (LICENSE_NOT_ENTITLED) when its collectors are license restricted and a required key is NOT_LICENSED;
          otherwise MISSING, with the reason and how to obtain it.
  domain  NOT_APPLICABLE when its topology does not hold or no item applies; COMPLETE when every applicable item
          was obtained; COMPLETE_WITHIN_POLICY when the rest is excluded by policy; PARTIAL when something
          obtainable is missing; NOT_ASSESSED when nothing was obtained. INSUFFICIENT_EVIDENCE is never computed:
          only a specialist review may lower a state to it, with a reason.
Deterministic, stdlib only, no Oracle access.
Usage: python3 -m scripts.assessment_coverage.evaluate --observations FILE [--format json|md]
"""
import argparse
import hashlib
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL = os.path.join(ROOT, "config", "assessment-coverage-model.json")

DOMAIN_STATES = ("COMPLETE", "COMPLETE_WITHIN_POLICY", "PARTIAL", "NOT_ASSESSED", "NOT_APPLICABLE", "INSUFFICIENT_EVIDENCE")
ITEM_STATES = ("OBTAINED", "EXCLUDED_BY_POLICY", "NOT_APPLICABLE", "MISSING")
COLLECTOR_STATES = ("OBSERVED", "DEGRADED", "FAILED", "NOT_RUN", "UNSUPPORTED", "LICENSE_RESTRICTED", "INSUFFICIENT_PRIVILEGES",
                    "ENVIRONMENT_UNKNOWN", "DISABLED", "NOT_APPLICABLE")
NOT_LICENSED = "NOT_LICENSED"
_REASONS = {
    "NOT_RUN": "no se ejecutó",
    "FAILED": "la recolección falló",
    "UNSUPPORTED": "no está habilitado para el target o no tiene variante para la versión",
    "INSUFFICIENT_PRIVILEGES": "falta un privilegio de la cuenta de diagnóstico",
    "ENVIRONMENT_UNKNOWN": "el contexto del target está incompleto",
    "DISABLED": "el adaptador del target está deshabilitado",
    "LICENSE_RESTRICTED": "requiere una licencia que no está confirmada (LICENSE_CHECK_REQUIRED)",
}


class CoverageError(RuntimeError):
    pass


def load_model(path=MODEL, collectors=None) -> dict:
    """Load and validate the model. With `collectors` (the gateway catalog), every referenced collector must exist."""
    with open(path, encoding="utf-8") as f:
        m = json.load(f)
    if m.get("schema_version") != "1.0.0" or tuple(m.get("domain_states", ())) != DOMAIN_STATES:
        raise CoverageError("unsupported model schema or domain states")
    cats, flags = m["exclusion_categories"], set(m["topology_flags"])
    for c in cats.values():
        if not os.path.isfile(os.path.join(ROOT, c["policy"])):
            raise CoverageError(f"exclusion category cites a missing policy: {c['policy']}")
    seen = set()
    for d in m["domains"]:
        for cond in [d.get("applies_when", {})] + [i.get("applies_when", {}) for i in d["items"]]:
            if not set(cond) <= flags or not all(isinstance(v, bool) for v in cond.values()):
                raise CoverageError(f"domain {d['id']}: applies_when uses an unknown flag or a non-boolean value")
        for i in [d] + d["items"]:
            if i["id"] in seen:
                raise CoverageError(f"duplicate id {i['id']}")
            seen.add(i["id"])
        if not d["items"]:
            raise CoverageError(f"domain {d['id']} has no items")
        for i in d["items"]:
            ex = i.get("excluded_by_policy")
            if ex is not None:
                if i["collectors"] or i.get("gap") or ex.get("category") not in cats or not ex.get("reason"):
                    raise CoverageError(f"item {i['id']}: a policy exclusion has no collectors or gap and names a known category and a reason")
            elif not i["collectors"] and not i.get("gap"):
                raise CoverageError(f"item {i['id']}: without collectors it must say why (gap)")
            if collectors is not None:
                unknown = [c for c in i["collectors"] if c not in collectors]
                if unknown:
                    raise CoverageError(f"item {i['id']}: unknown collectors {unknown}")
    return m


def _applies(cond: dict, topology: dict):
    """True / False, or None when a flag the condition needs is unknown (never assumed)."""
    for k, v in (cond or {}).items():
        if k not in topology:
            return None
        if bool(topology[k]) is not v:
            return False
    return True


def _license_keys(collector_id, catalog):
    from mcp_gateway.catalog import license_keys
    lic = catalog[collector_id].license_requirements if catalog and collector_id in catalog else None
    if isinstance(lic, (list, tuple)):
        lic = " ".join(str(x) for x in lic)
    return license_keys(lic or "")


def evaluate_item(item, topology, license_status, states, catalog=None) -> dict:
    out = {"id": item["id"], "label": item["label"]}
    ex = item.get("excluded_by_policy")
    if ex is not None:
        return {**out, "status": "EXCLUDED_BY_POLICY", "category": ex["category"], "reason": ex["reason"]}
    applies = _applies(item.get("applies_when"), topology)
    if applies is False:
        return {**out, "status": "NOT_APPLICABLE", "reason": "no aplica a la topología observada"}
    if applies is None:
        return {**out, "status": "MISSING", "reason": "topología desconocida para decidir si aplica", "collectors": item["collectors"]}
    cs = {c: states.get(c, "NOT_RUN") for c in item["collectors"]}
    observed = sorted(c for c, s in cs.items() if s in ("OBSERVED", "DEGRADED"))
    if observed:
        degraded = sorted(c for c in observed if cs[c] == "DEGRADED")
        return {**out, "status": "OBTAINED", "collectors": observed, **({"degraded": degraded} if degraded else {})}
    if cs and all(s == "NOT_APPLICABLE" for s in cs.values()):
        return {**out, "status": "NOT_APPLICABLE", "reason": "el gateway declara los collectors no aplicables al target"}
    restricted = [c for c, s in cs.items() if s == "LICENSE_RESTRICTED"]
    if restricted and len(restricted) == len(cs) and all(
            any(license_status.get(k) == NOT_LICENSED for k in _license_keys(c, catalog)) for c in restricted):
        return {**out, "status": "EXCLUDED_BY_POLICY", "category": "LICENSE_NOT_ENTITLED",
                "reason": "requiere un pack declarado NOT_LICENSED por el humano"}
    reasons = sorted({f"{c}: {_REASONS.get(s, s)}" for c, s in cs.items() if s != "NOT_APPLICABLE"})
    if item.get("gap"):
        reasons.append(item["gap"])
    return {**out, "status": "MISSING", "reason": "; ".join(reasons), "collectors": sorted(cs)}


def evaluate(model, observations, catalog=None) -> dict:
    topology = observations.get("topology", {})
    license_status = observations.get("license_status", {})
    states = observations.get("collectors", {})
    bad = sorted({s for s in states.values() if s not in COLLECTOR_STATES})
    if bad:
        raise CoverageError(f"unknown collector states: {bad}")
    domains = []
    for d in model["domains"]:
        applies = _applies(d.get("applies_when"), topology)
        if applies is False:
            domains.append({"id": d["id"], "title": d["title"], "status": "NOT_APPLICABLE", "items": []})
            continue
        if applies is None:
            items = [{"id": i["id"], "label": i["label"], "status": "MISSING", "reason": "topología desconocida para decidir si aplica"}
                     for i in d["items"]]
        else:
            items = [evaluate_item(i, topology, license_status, states, catalog) for i in d["items"]]
        live = [i["status"] for i in items if i["status"] != "NOT_APPLICABLE"]
        if not live:
            status = "NOT_APPLICABLE"
        elif "MISSING" in live:
            status = "PARTIAL" if "OBTAINED" in live else "NOT_ASSESSED"
        elif "EXCLUDED_BY_POLICY" in live:
            status = "COMPLETE_WITHIN_POLICY" if "OBTAINED" in live else "NOT_ASSESSED"
        else:
            status = "COMPLETE"
        domains.append({"id": d["id"], "title": d["title"], "status": status, "items": items})
    counts = {s: sum(1 for d in domains if d["status"] == s) for s in DOMAIN_STATES}
    return {"schema_version": "1.0.0", "counts": counts, "domains": domains}


def to_markdown(result) -> str:
    rows = ["| Dominio | Estado | Obtenido | Excluido por política | Qué falta |", "|---|---|---|---|---|"]
    for d in result["domains"]:
        got = ", ".join(i["id"] + (" (con limitaciones)" if i.get("degraded") else "") for i in d["items"]
                        if i["status"] == "OBTAINED") or "—"
        exc = "; ".join(f"{i['id']} ({i['category']})" for i in d["items"] if i["status"] == "EXCLUDED_BY_POLICY") or "—"
        miss = "; ".join(f"{i['id']}: {i['reason']}" for i in d["items"] if i["status"] == "MISSING") or "—"
        rows.append(f"| {d['id']}. {d['title']} | {d['status']} | {got} | {exc} | {miss} |")
    return "\n".join(rows) + "\n"


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="python3 -m scripts.assessment_coverage.evaluate")
    p.add_argument("--observations", required=True)
    p.add_argument("--format", choices=("json", "md"), default="json")
    a = p.parse_args(argv)
    sys.path.insert(0, ROOT)
    from mcp_gateway import catalog as cat
    collectors = cat.load_collectors()
    try:
        model = load_model(collectors=collectors)
        with open(a.observations, encoding="utf-8") as f:
            obs = json.load(f)
        result = evaluate(model, obs, collectors)
        with open(MODEL, "rb") as f:
            result["model_sha256"] = hashlib.sha256(f.read()).hexdigest()
    except (CoverageError, OSError, ValueError, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    sys.stdout.write(to_markdown(result) if a.format == "md" else json.dumps(result, indent=1, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
