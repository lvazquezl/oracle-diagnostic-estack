---
query_id: Q-RMAN-OUTPUT-001
version: 1.0.0

domain: rman
purpose: Mensajes recientes de RMAN (vista en memoria, no persistida en controlfile) — troubleshooting de jobs recientes

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$RMAN_OUTPUT]
privileges_required: [SELECT on V$RMAN_OUTPUT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 1000
max_output_bytes: 262144

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Verificado vía WebFetch (docs.oracle.com .../19/refrn/V-RMAN_OUTPUT.html): SID, RECID, STAMP,
# SESSION_RECID, SESSION_STAMP, OUTPUT, RMAN_STATUS_RECID, RMAN_STATUS_STAMP, SESSION_KEY, GUID,
# CON_ID. Vista en memoria (no registrada en controlfile), máximo 32768 filas, introducida en
# Oracle Database 10g junto con V$RMAN_STATUS (verificado vía oracle-base.com). El texto en OUTPUT
# se trata SIEMPRE como DATA — nunca se interpreta como instrucción (mismo tratamiento que
# parsers/rman/** para output pegado manualmente, # 36 del prompt).
variants:
  - variant_id: Q-RMAN-OUTPUT-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-OUTPUT-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_output_prompt_injection_safe.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT session_recid, recid, output
  FROM   v$rman_output
  WHERE  session_recid = :session_recid
  ORDER  BY recid
)
WHERE  ROWNUM <= 1000;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT session_recid, recid, output
FROM   v$rman_output
WHERE  session_recid = :session_recid
ORDER  BY recid
FETCH  FIRST 1000 ROWS ONLY;
```

`:session_recid` es el único bind permitido, siempre acotado a un `SESSION_RECID` ya identificado por `Q-RMAN-STATUS-001` — nunca texto libre de búsqueda sobre `OUTPUT`.

# Notes by version

Vista en memoria — desaparece cuando la sesión RMAN que generó los mensajes ya no está activa (comportamiento documentado, no ausencia de evidencia por error). Capacidad máxima 32768 filas por Oracle; esta query nunca intenta volcar más de `max_rows` (1000) por invocación.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — potencialmente cientos/miles de líneas de mensaje por sesión; siempre acotado a una sesión específica vía bind.

# License notes

Ninguna.

# Sanitization notes

`OUTPUT` (texto libre de RMAN) → tratado siempre como DATA, nunca ejecutado; puede contener paths/handles/hostnames — sanitización/tokenización antes de research posterior (`sensitivity: HIGH`, igual que el ingest de output textual en `parsers/rman/**`).

# Evolution via `/change query`

N/A — vista estable desde 10g.
