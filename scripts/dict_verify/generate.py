"""CHG-ESTACK-ORA19C-LAB-006 — generate the certified dictionary-verification queries from the dictionary.

compatibility/oracle-dictionary/views.yaml is the single source. Each generated query (Q-DICT-VERIFY-00N) embeds a
fixed, space-separated list of `VIEW.COLUMN` tokens (`VIEW.*` = the view itself) that the dictionary declares as
present at the lab's version, and returns ONLY the discrepancies against DBA_TAB_COLUMNS plus one CHECKED row:
the database does the comparison, so the answer stays far below the lab row/byte ceilings.

Deterministic, stdlib only, no Oracle access. `--check` exits 1 when the committed query files differ from what
the dictionary produces (drift guard: tests/test_dict_verify_queries_match_dictionary.sh).
Usage: python3 -m scripts.dict_verify.generate [--check | --write] [--version 19.0]
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VIEWS_YAML = os.path.join(ROOT, "compatibility", "oracle-dictionary", "views.yaml")
OUT_DIR = os.path.join(ROOT, "queries", "oracle", "dictionary")
MAX_SQL_CHARS = 4000            # mcp_gateway_lab/sqlsource.py — never raised for this collector
LIST_BUDGET = 2900              # chars of the embedded literal per query: SQL skeleton (~900) + growth margin
OWNERS = ("SYS", "AUDSYS", "PERFSTAT")  # STATS$* are Statspack (PERFSTAT); unified audit may live in AUDSYS
_FORBIDDEN = re.compile(          # mirror of mcp_gateway/catalog.py _FORBIDDEN_SQL (asserted equal by the test)
    r'(?i)\b(insert|update|delete|merge|drop|create|alter|truncate|grant|revoke|execute|exec|call|begin|declare|commit|'
    r'rollback|lock|flashback|purge|rename|comment|audit|noaudit|shutdown|startup|into)\b|dbms_|utl_|sys\.|;\s*\S')
_VIEW = re.compile(r"^  ([A-Z][A-Z0-9_$#]*):[ \t]*$", re.M)
_VIEW_MIN = re.compile(r"^    min_version:[ \t]*(\S+)", re.M)
_COL = re.compile(r"^      ([a-z][a-z0-9_#$]*):[ \t]*\{[^}\n]*?min_version:[ \t]*([^,}\s]+)", re.M)


def _ver(text):
    text = text.strip().strip('"').strip("'")
    if text == "all":
        return (0,)
    return tuple(int(p) for p in text.split("."))


def load_tokens(version="19.0"):
    """Sorted `VIEW.COLUMN` / `VIEW.*` tokens declared present at `version` (major.minor family)."""
    target = _ver(version)
    text = open(VIEWS_YAML, encoding="utf-8").read()
    starts = [(m.group(1), m.start()) for m in _VIEW.finditer(text)]
    tokens, skipped = [], []
    for i, (view, pos) in enumerate(starts):
        block = text[pos: starts[i + 1][1] if i + 1 < len(starts) else len(text)]
        vm = _VIEW_MIN.search(block)
        if vm and _ver(vm.group(1))[:2] > target[:2]:
            continue
        if _FORBIDDEN.search(" " + view + " "):
            skipped.append(view)
            continue
        assert "V$" not in view or view.startswith(("V$", "GV$")), view   # REPLACE('V$','V_$') maps only V$/GV$
        tokens.append(view + ".*")
        for col, cmin in _COL.findall(block):
            if _ver(cmin)[:2] > target[:2]:
                continue
            tok = view + "." + col.upper()
            if _FORBIDDEN.search(" " + tok + " "):
                skipped.append(tok)
                continue
            tokens.append(tok)
    return sorted(set(tokens)), sorted(set(skipped))


def chunk(tokens):
    """Balanced contiguous parts: as few as the budget allows, each about the same size (stable, sorted order)."""
    total = len(" ".join(tokens))
    n = -(-total // LIST_BUDGET)
    target = -(-total // n)
    parts, cur = [], []
    for t in tokens:
        if cur and len(parts) < n - 1 and len(" ".join(cur + [t])) > target:
            parts.append(cur)
            cur = []
        cur.append(t)
    parts.append(cur)
    assert all(len(" ".join(p)) <= LIST_BUDGET for p in parts)
    return parts


SQL = """WITH s AS (SELECT '{literal}' AS l FROM dual),
e AS (SELECT REGEXP_SUBSTR(l, '[^ ]+', 1, LEVEL) AS p FROM s CONNECT BY LEVEL <= REGEXP_COUNT(l, '[^ ]+')),
x AS (SELECT SUBSTR(p, 1, INSTR(p, '.') - 1) AS view_name, SUBSTR(p, INSTR(p, '.') + 1) AS column_name,
             REPLACE(SUBSTR(p, 1, INSTR(p, '.') - 1), 'V$', 'V_$') AS object_name FROM e)
SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM dba_tab_columns d WHERE d.owner IN ({owners}) AND d.table_name = x.object_name)
            THEN 'VIEW_NOT_FOUND' ELSE 'COLUMN_NOT_FOUND' END AS finding,
       x.view_name, x.column_name, CAST(1 AS NUMBER(10)) AS tokens
FROM   x
WHERE  NOT EXISTS (SELECT 1 FROM dba_tab_columns d WHERE d.owner IN ({owners}) AND d.table_name = x.object_name
                   AND (x.column_name = '*' OR d.column_name = x.column_name))
UNION ALL
SELECT 'CHECKED', '*', '*', CAST(COUNT(*) AS NUMBER(10)) FROM x;"""


def render_sql(part):
    sql = SQL.format(literal=" ".join(part), owners=", ".join("'%s'" % o for o in OWNERS))
    stmt = sql.rstrip().rstrip(";")
    assert len(stmt) <= MAX_SQL_CHARS, len(stmt)
    assert not _FORBIDDEN.search(stmt), "generated SQL would be refused by the read-only guard"
    return sql


QUERY_ID = "Q-DICT-VERIFY-{:03d}"
COLLECTORS_JSON = os.path.join(ROOT, "mcp_gateway", "catalog", "collectors.json")
MAX_ROWS = 120
TESTS = ("tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, "
         "tests/test_p15_oracle_lab_adapter.sh")


def _split(tok):
    view, col = tok.split(".", 1)
    return view, col


def render_md(part, idx, n):
    qid = QUERY_ID.format(idx)
    views = sorted({_split(t)[0] for t in part})
    first, last = part[0], part[-1]
    sql = render_sql(part)
    return f"""---
query_id: {qid}
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte {idx}/{n}: {first} … {last}) — la base compara y devuelve sólo discrepancias"

supported_oracle_versions: [19c]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_COLUMNS]
privileges_required: [SELECT on DBA_TAB_COLUMNS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: {MAX_ROWS}
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# GENERADO por scripts/dict_verify/generate.py desde compatibility/oracle-dictionary/views.yaml — NO editar a mano.
# CHG-ESTACK-ORA19C-LAB-006. La lista embebida es la del diccionario para 19c; otra versión requiere su propia
# variante generada (CHG-REQ-LAB-MULTIVERSION).
variants:
  - variant_id: {qid}-V1
    label: oracle_19c
    oracle_versions: {{min: "19.0", max: "19.0"}}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [{TESTS}]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
{sql}
```

Parte {idx} de {n}: {len(part)} tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre {len(views)} vistas. Devuelve una fila
por token **no encontrado** (`VIEW_NOT_FOUND` si la vista no existe para los owners `{"`, `".join(OWNERS)}`; si no,
`COLUMN_NOT_FOUND`) y siempre una fila `CHECKED` con el total de tokens verificados. Un diccionario correcto responde
sólo la fila `CHECKED`.

- `V$X`/`GV$X` se buscan por su objeto real `V_$X`/`GV_$X` (las `V$` son sinónimos públicos).
- La comparación ocurre en la base: la respuesta nunca contiene el catálogo, sólo discrepancias.

# Notes by version

Generada para 19c (`min_version` ≤ 19 en el diccionario). `REGEXP_SUBSTR`/`REGEXP_COUNT` existen desde 11g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`. El lab la ejecuta desde `CDB$ROOT`, donde viven los objetos de `SYS`.

# Cost classification rationale

`MEDIUM`: {len(part)} búsquedas por nombre en el catálogo (`owner`, `table_name`), sin datos de aplicación.

# License notes

Ninguna.

# Sanitization notes

`finding`, `view_name` y `column_name` son **enums** cuyos valores permitidos son exactamente los de esta parte del
diccionario: KEEP sin riesgo, y cualquier otro valor se descarta. `tokens` es un entero.

# Limitations

Sólo verifica que lo declarado exista (no detecta columnas reales ausentes de listas exhaustivas). No incluye
tokens que el guard de solo lectura rechazaría por contener palabras reservadas (hoy: `V$LOCK`).

# Evolution via `/change query`

Se regenera con `python3 -m scripts.dict_verify.generate --write` al cambiar el diccionario.
"""


def collector_spec(part, idx, n):
    views = sorted({_split(t)[0] for t in part})
    cols = sorted({_split(t)[1] for t in part})
    return {
        "collector_id": QUERY_ID.format(idx),
        "kind": "sql_query",
        "domain": "oracle",
        "title": f"Dictionary verification part {idx}/{n}: declared views/columns missing from the real catalog (compared in the database)",
        "row_limit": MAX_ROWS,
        "params": {},
        "output_fields": {
            "finding": {"type": "enum", "values": ["CHECKED", "COLUMN_NOT_FOUND", "VIEW_NOT_FOUND"], "policy": "KEEP"},
            "view_name": {"type": "enum", "values": ["*"] + views, "policy": "KEEP"},
            "column_name": {"type": "enum", "values": cols if "*" in cols else ["*"] + cols, "policy": "KEEP"},
            "tokens": {"type": "integer", "min": 0, "max": 100000, "policy": "KEEP"},
        },
        "adapters": {"fixture": "VERIFIED_FIXTURE", "oracle_sql": "DISABLED"},
    }


def _render_collector(spec):
    j = lambda v: __import__("json").dumps(v, ensure_ascii=False)
    fields = ",\n".join(f'        {j(k)}: {{"type": {j(v["type"])}, ' + (f'"values": {j(v["values"])}, ' if "values" in v else f'"min": {v["min"]}, "max": {v["max"]}, ')
                        + f'"policy": {j(v["policy"])}}}' for k, v in spec["output_fields"].items())
    return ("    {\n"
            f'      "collector_id": {j(spec["collector_id"])},\n      "kind": "sql_query",\n      "domain": "oracle",\n'
            f'      "title": {j(spec["title"])},\n      "row_limit": {spec["row_limit"]},\n      "params": {{}},\n'
            f'      "output_fields": {{\n{fields}\n      }},\n'
            f'      "adapters": {j(spec["adapters"])}\n    }}').replace('{"fixture": "VERIFIED_FIXTURE", "oracle_sql": "DISABLED"}',
                                                             '{"fixture": "VERIFIED_FIXTURE", "oracle_sql": "DISABLED"}')


def generate(version="19.0"):
    tokens, skipped = load_tokens(version)
    parts = chunk(tokens)
    n = len(parts)
    files = {os.path.join(OUT_DIR, QUERY_ID.format(i) + ".md"): render_md(p, i, n) for i, p in enumerate(parts, 1)}
    specs = [collector_spec(p, i, n) for i, p in enumerate(parts, 1)]
    return files, specs, skipped


def _collectors_text_with(specs):
    import json
    text = open(COLLECTORS_JSON, encoding="utf-8").read()
    doc = json.loads(text)
    ids = {s["collector_id"] for s in specs}
    kept = [c for c in doc["collectors"] if not c["collector_id"].startswith("Q-DICT-VERIFY-")]
    if len(kept) != len(doc["collectors"]):          # regenerate: strip the previous generated block (always at the end)
        head = text[: text.index('    {\n      "collector_id": "Q-DICT-VERIFY-')].rstrip().rstrip(",")
    else:
        head = text[: text.rindex("\n  ]")].rstrip()
    out = head + ",\n" + ",\n".join(_render_collector(s) for s in specs) + "\n  ]\n}\n"
    assert json.loads(out)["collectors"][-len(specs):] == specs and ids
    return out


def check(version="19.0"):
    import json
    files, specs, _ = generate(version)
    problems = []
    existing = sorted(f for f in os.listdir(OUT_DIR)) if os.path.isdir(OUT_DIR) else []
    for path, content in files.items():
        if not os.path.exists(path) or open(path, encoding="utf-8").read() != content:
            problems.append("stale or missing: " + os.path.relpath(path, ROOT))
    for f in existing:
        if os.path.join(OUT_DIR, f) not in files:
            problems.append("orphan generated query: queries/oracle/dictionary/" + f)
    doc = json.load(open(COLLECTORS_JSON, encoding="utf-8"))
    got = [c for c in doc["collectors"] if c["collector_id"].startswith("Q-DICT-VERIFY-")]
    if got != specs:
        problems.append("mcp_gateway/catalog/collectors.json: Q-DICT-VERIFY-* entries differ from the dictionary")
    return problems


def write(version="19.0"):
    files, specs, skipped = generate(version)
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        if os.path.join(OUT_DIR, f) not in files:
            os.remove(os.path.join(OUT_DIR, f))
    for path, content in files.items():
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(content)
    text = _collectors_text_with(specs)
    with open(COLLECTORS_JSON, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    return files, specs, skipped


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["--write"]:
        files, specs, skipped = write()
        print(f"{len(files)} queries written; skipped (guard words): {skipped}")
    elif args[:1] == ["--check"]:
        probs = check()
        for pr in probs:
            print("[FAIL] " + pr)
        sys.exit(1 if probs else 0)
    else:
        toks, skipped = load_tokens()
        parts = chunk(toks)
        print(len(toks), "tokens,", len(parts), "queries, skipped:", skipped)
        for p in parts:
            print(len(render_sql(p)), len(p), p[0], "..", p[-1])
