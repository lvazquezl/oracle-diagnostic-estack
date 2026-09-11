---
query_id: Q-RMAN-BACKUP-PIECE-001
version: 1.0.0

domain: rman
purpose: Inventario de piezas físicas de backup (handle, device type, tag, disponibilidad) — evidencia de restore readiness

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_PIECE]
privileges_required: [SELECT on V$BACKUP_PIECE]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-BACKUP-PIECE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-BACKUP-PIECE-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_backup_piece_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_restore_readiness_ready.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT bp.recid, bp.set_stamp, bp.device_type, bp.handle, bp.tag,
         bp.status, bp.completion_time, bp.bytes
  FROM   v$backup_piece bp
  WHERE  bp.status != 'D'
  ORDER  BY bp.completion_time DESC
)
WHERE  ROWNUM <= 500;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT bp.recid, bp.set_stamp, bp.device_type, bp.handle, bp.tag,
       bp.status, bp.completion_time, bp.bytes
FROM   v$backup_piece bp
WHERE  bp.status != 'D'
ORDER  BY bp.completion_time DESC
FETCH  FIRST 500 ROWS ONLY;
```

`STATUS != 'D'` excluye piezas marcadas `DELETED` en el controlfile (nunca implica que el e-stack las borró — sólo refleja el estado ya registrado por RMAN/DBA).

# Notes by version

`STATUS` reporta `A` (Available), `U` (Unavailable), `D` (Deleted), `X` (Expired) — reportado tal cual, nunca reinterpretado. Vista pre-10g, certificada 10g-23ai sin variante adicional.

# Notes by platform

`HANDLE` puede ser un path de filesystem, un nombre de disco ASM (`+DATA/...`) o un handle de media manager (SBT) según `DEVICE_TYPE` — la sanitización se aplica igual en los tres casos.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — el histórico de piezas crece con el tiempo; acotado a `FETCH FIRST 500 ROWS ONLY`.

# License notes

Ninguna.

# Sanitization notes

`HANDLE` → TOKENIZE siempre (`sensitivity: HIGH`) — puede revelar convención interna de filesystem/ASM/SBT o el nombre del pool de media manager. `TAG` → MASK (puede contener nombre de aplicación/ambiente).

# Evolution via `/change query`

N/A — vista estable.
