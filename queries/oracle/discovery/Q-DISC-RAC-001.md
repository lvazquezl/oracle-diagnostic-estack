---
query_id: Q-DISC-RAC-001
version: 2.0.0

domain: oracle
purpose: Topología RAC — instancias activas y su distribución por nodo

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [rac]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$INSTANCE, V$ACTIVE_INSTANCES]
privileges_required: [SELECT on GV$INSTANCE, SELECT on V$ACTIVE_INSTANCES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 50
max_output_bytes: 16384

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Oracle Core Compatibility Hardening: bug VARIANT_REQUIRED corregido — la sentencia única
# original leía con_id (12c+, concepto multitenant) sin guardia mientras declaraba soporte
# desde 11gR2. Ahora 2 variantes explícitas.
variants:
  - variant_id: Q-DISC-RAC-001-V1
    label: pre_multitenant
    oracle_versions: {min: "11.2", max: "11.2"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (pre_multitenant, 11.2)"
  - variant_id: Q-DISC-RAC-001-V2
    label: multitenant_aware
    oracle_versions: {min: "12.1", max: latest}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V2 (multitenant_aware, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rac_standalone_detection.sh, tests/test_every_logical_query_has_variant.sh, tests/test_no_variant_references_unknown_column.sh, tests/test_rac_11g_does_not_use_con_id.sh, tests/test_rac_12cplus_can_use_con_id.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (pre_multitenant, 11.2)

```sql
SELECT a.inst_number, a.inst_name
FROM   v$active_instances a
ORDER  BY a.inst_number;
```

Sin `con_id` — Multitenant no existe en 11g, la columna no está disponible en `V$ACTIVE_INSTANCES` para esta versión.

# Statement / procedure (read-only) — Variant V2 (multitenant_aware, 12.1+)

```sql
SELECT a.inst_number, a.inst_name, a.con_id
FROM   v$active_instances a
ORDER  BY a.inst_number;
```

`V$ACTIVE_INSTANCES` confirma qué instancias están activas en el cluster en este momento (complementa `GV$INSTANCE`, que sólo ve instancias con las que la sesión actual puede establecer una conexión GV$ paralela).

# Notes by version

- `V$ACTIVE_INSTANCES` estable desde 11gR2 en ambas variantes. No certificado para 10g/11gR1 (RAC pre-11gR2) en este catálogo — `oracle-discovery-analyst` reporta `capability_status: PARTIALLY_SUPPORTED` (no `UNSUPPORTED`, porque la feature Oracle sí existe) para esas versiones.
- `CON_ID` sólo existe desde 12.1 (concepto multitenant) → exclusivo de V2. Ver `compatibility/oracle-dictionary/views.yaml#v$active_instances`.

# Notes by platform

Ninguna diferencia en ninguna variante — es SQL puro sobre `V$`, independiente del OS.

# Container / role scope notes

Topología de cluster es independiente de tenancy en ambas variantes — `NOT_APPLICABLE`. `con_id` en V2 es metadata adicional del cluster, no un filtro por contenedor.

# Cost classification rationale

`LOW` en ambas variantes: acotado al número de instancias del cluster.

# License notes

Ninguna en ninguna variante — la topología RAC en sí no requiere licenciamiento adicional (RAC como producto sí, pero eso es un problema de licenciamiento de plataforma, no de esta query).

# Sanitization notes

`inst_name` → MASK por defecto en ambas variantes.

# Evolution via `/change query`

Si una versión futura introduce un tercer concepto de contenedor (más allá de CDB/PDB), evaluar V3 vía `/change compatibility`.
