"""CHG-ESTACK-COLLECTOR-FACTORY-B1 — generate gateway collectors from certified queries, lot by lot.

Sources (both governed by /change):
  config/collector-factory/columns.json   knowledge base: one field definition per output field name
  config/collector-factory/lots/*.json    lots: which certified queries become collectors, their fields and aliases

Outputs (never edited by hand; `--check` is the drift guard used by tests/test_collector_factory.sh):
  mcp_gateway/catalog/collectors.factory.json       collector specs (merged by mcp_gateway.catalog.load_collectors)
  mcp_gateway/fixtures/<fixture_target>/<id>.json   one SYNTHETIC fixture row per collector

Rules: every collector is a certified R0 READ_ONLY query; fields are a default-deny allowlist; a lot override may only
narrow a knowledge-base definition (same type and policy, enum values a subset, numeric range inside); identifiers
are never KEEP and free text is never declared. Deterministic, stdlib only, no Oracle access.
Usage: python3 -m scripts.collector_factory.generate [--check | --write]
"""
import glob
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLUMNS = os.path.join(ROOT, "config", "collector-factory", "columns.json")
LOTS = os.path.join(ROOT, "config", "collector-factory", "lots")
OUT = os.path.join(ROOT, "mcp_gateway", "catalog", "collectors.factory.json")
FIXTURES = os.path.join(ROOT, "mcp_gateway", "fixtures")
_SPEC_KEYS = ("type", "min", "max", "values", "policy", "alias_prefix")


class FactoryError(RuntimeError):
    pass


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _narrow(name, base, over, cid):
    f = dict(base)
    for k, v in (over or {}).items():
        if k in ("type", "policy") and v != base[k]:
            raise FactoryError(f"{cid}.{name}: an override may not change {k}")
        if k == "values" and base.get("values") and not set(v) <= set(base["values"]):
            raise FactoryError(f"{cid}.{name}: override values must be a subset of the knowledge base")
        if k == "min" and v < base.get("min", v):
            raise FactoryError(f"{cid}.{name}: override min widens the range")
        if k == "max" and v > base.get("max", v):
            raise FactoryError(f"{cid}.{name}: override max widens the range")
        f[k] = v
    if f["type"] == "enum" and not f.get("values"):
        raise FactoryError(f"{cid}.{name}: enum without values")
    if f["type"] == "identifier" and f["policy"] == "KEEP" or f["type"] == "text":
        raise FactoryError(f"{cid}.{name}: identifiers are never KEEP and free text is never declared")
    ex = f.get("example")
    if f["type"] == "enum" and ex not in f["values"] or f["type"] in ("integer", "number") and not (f["min"] <= ex <= f["max"]):
        raise FactoryError(f"{cid}.{name}: fixture example outside the declared domain")
    return f


def generate():
    from mcp_gateway import catalog
    kb = _load(COLUMNS)["fields"]
    specs, fixtures, seen = [], {}, set()
    for lot_path in sorted(glob.glob(os.path.join(LOTS, "*.json"))):
        lot = _load(lot_path)
        for c in lot["collectors"]:
            cid = c["collector_id"]
            if cid in seen:
                raise FactoryError(f"{cid}: listed twice")
            seen.add(cid)
            qfile = catalog._find_query_file(cid)
            if qfile is None:
                raise FactoryError(f"{cid}: not a certified query")
            fm = catalog._parse_front_matter(open(qfile, encoding="utf-8").read())
            if fm.get("status") != "active" or fm.get("risk_class") != "R0" or fm.get("execution_mode") != "READ_ONLY":
                raise FactoryError(f"{cid}: query is not certified R0 read-only")
            if int(c["row_limit"]) > int(fm.get("max_rows", 0)):
                raise FactoryError(f"{cid}: row_limit exceeds the certified max_rows")
            aliases = c.get("aliases", {})
            if not set(aliases.values()) <= set(c["fields"]):
                raise FactoryError(f"{cid}: an alias points outside the field allowlist")
            if set(c.get("overrides", {})) - set(c["fields"]):
                raise FactoryError(f"{cid}: override for an undeclared field")
            fields, row = {}, {}
            for name in c["fields"]:
                if name not in kb:
                    raise FactoryError(f"{cid}.{name}: not in the column knowledge base")
                f = _narrow(name, kb[name], c.get("overrides", {}).get(name), cid)
                fields[name] = {k: f[k] for k in _SPEC_KEYS if k in f}
                row[name] = f["example"]
            spec = {"collector_id": cid, "kind": "sql_query", "domain": c["domain"], "title": c["title"],
                    "row_limit": int(c["row_limit"]), "params": {}, "output_fields": fields,
                    "adapters": {"fixture": "VERIFIED_FIXTURE", "oracle_sql": "DISABLED"},
                    "factory": {"lot": lot["lot_id"], "lab_aliases": aliases, "fixture_target": lot["fixture_target"]}}
            specs.append(spec)
            fixtures[os.path.join(FIXTURES, lot["fixture_target"], cid + ".json")] = {
                "fixture_note": "SYNTHETIC data — not observed from any real system (collector factory lot %s)" % lot["lot_id"],
                "rows": [row]}
    doc = {"schema_version": "1.0.0",
           "description": "GENERATED by python3 -m scripts.collector_factory.generate from config/collector-factory — do not edit. "
                          "Merged into the collector catalog by mcp_gateway.catalog.load_collectors (same default-deny rules).",
           "collectors": specs}
    return doc, fixtures


def _text(obj):
    return json.dumps(obj, indent=2, ensure_ascii=False) + "\n"


def check():
    doc, fixtures = generate()
    problems = []
    if not os.path.exists(OUT) or open(OUT, encoding="utf-8").read() != _text(doc):
        problems.append("stale or missing: mcp_gateway/catalog/collectors.factory.json")
    for path, fx in fixtures.items():
        if not os.path.exists(path) or open(path, encoding="utf-8").read() != _text(fx):
            problems.append("stale or missing: " + os.path.relpath(path, ROOT))
    return problems


def write():
    doc, fixtures = generate()
    for path, obj in [(OUT, doc)] + list(fixtures.items()):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(_text(obj))
    return doc, fixtures


if __name__ == "__main__":
    sys.path.insert(0, ROOT)
    args = sys.argv[1:]
    try:
        if args[:1] == ["--write"]:
            doc, fx = write()
            print(f"{len(doc['collectors'])} collectors and {len(fx)} fixtures written")
        elif args[:1] == ["--check"]:
            probs = check()
            for p in probs:
                print("[FAIL] " + p)
            sys.exit(1 if probs else 0)
        else:
            doc, fx = generate()
            for c in doc["collectors"]:
                print(c["factory"]["lot"], c["collector_id"], len(c["output_fields"]), "fields")
    except FactoryError as e:
        print("[FAIL] collector factory: " + str(e))
        sys.exit(1)
