---
query_id: Q-DISC-IDENTITY-001
version: 3.0.0

domain: oracle
purpose: Identificar versión, edición y rol de la base de datos

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$INSTANCE, V$DATABASE]
privileges_required: [SELECT on V$INSTANCE, SELECT on V$DATABASE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 5
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Oracle Core Compatibility Hardening: esta query pasó de una única sentencia SQL sin variantes
# (bug VARIANT_REQUIRED — usaba VERSION_FULL y CDB sin guardia) a 3 variantes explícitas.
# El Query Resolver (docs/QUERY_VARIANTS.md) selecciona la variante según el Target Profile.
variants:
  - variant_id: Q-DISC-IDENTITY-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    architecture: {multitenant: false}
    container_scope: NON_CDB
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-DISC-IDENTITY-001-V2
    label: multitenant_12c
    oracle_versions: {min: "12.1", max: "12.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_12c, 12.1–12.2)"
  - variant_id: Q-DISC-IDENTITY-001-V3
    label: modern_18plus
    oracle_versions: {min: "18.0", max: latest}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (modern_18plus, 18.0+)"

tests: [tests/test_no_write_operations.sh, tests/test_version_awareness.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_every_logical_query_has_variant.sh, tests/test_no_variant_references_unknown_column.sh, tests/test_identity_10g_does_not_use_version_full.sh, tests/test_identity_11g_does_not_use_cdb.sh, tests/test_identity_12c_supports_cdb.sh, tests/test_identity_18plus_uses_modern_variant.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT i.instance_name,
       i.version,                -- NUNCA version_full aquí: no existe antes de 18c
       d.name          AS db_name,
       d.database_role,
       d.open_mode
FROM   v$instance i, v$database d;
```

NON-CDB por construcción (Multitenant no existe en 10g/11g) — no se lee `d.cdb`.

# Statement / procedure (read-only) — Variant V2 (multitenant_12c, 12.1–12.2)

```sql
SELECT i.instance_name,
       i.version,                -- version_full todavía no disponible en 12c
       d.name          AS db_name,
       d.database_role,
       d.cdb,                    -- válido desde 12.1
       d.open_mode
FROM   v$instance i, v$database d;
```

# Statement / procedure (read-only) — Variant V3 (modern_18plus, 18.0+)

```sql
SELECT i.instance_name,
       i.version_full,           -- válido desde 18c
       d.name          AS db_name,
       d.database_role,
       d.cdb,
       d.open_mode
FROM   v$instance i, v$database d;
```

# Notes by version

- `V$INSTANCE.VERSION_FULL` sólo existe desde 18c → exclusivo de V3. V1/V2 usan `V$INSTANCE.VERSION` (5-part legacy, ej. `12.1.0.2.0`).
- `V$DATABASE.CDB` sólo existe desde 12c → V1 no la lee (NON-CDB por definición en 10g/11g); V2/V3 sí.
- Ver `compatibility/oracle-dictionary/views.yaml#v$instance` / `#v$database` para la fuente de verdad de disponibilidad por columna.

# Notes by platform

Ninguna diferencia en ninguna variante — es SQL puro, no depende del OS.

# Container / role scope notes

`container_scope: NON_CDB` en V1 (Multitenant no existe), `ANY_CONTAINER` en V2/V3. `database_role_scope: ANY` en las 3 — `V$DATABASE`/`V$INSTANCE` son legibles en cualquier rol/open_mode, incluyendo `MOUNTED`.

# Cost classification rationale

`LOW` en las 3 variantes — una sola fila, sin joins costosos, sin escalado con el tamaño del ambiente.

# License notes

Ninguna en ninguna variante.

# Sanitization notes

`db_name` → MASK por defecto (puede revelar nombre de cliente/aplicación); `instance_name` → MASK; `version`/`version_full`/`database_role`/`cdb`/`open_mode` → KEEP (no sensibles).

# Evolution via `/change query`

Nueva versión mayor Oracle (ej. una futura 25) entra vía `/change compatibility`: confirmar si `version_full`/`cdb` siguen siendo válidas (deberían) y si aplica una V4, o si V3 se extiende su `max`. Ver `EVOLUTION.md#13-change-compatibility`.
