---
query_id: Q-RMAN-BACKUP-PIECE-001
version: 2.0.0

domain: rman
purpose: Piezas de backup por dispositivo y estado (disponibles, expiradas, no disponibles): cantidad, tamaño y antigüedad — evidencia de restore readiness, nunca el handle

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
max_rows: 20
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-BACKUP-PIECE-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10.2–23.0: agregado por dispositivo y estado)"

tests: [tests/test_no_write_operations.sh, tests/test_backup_piece_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_restore_readiness_ready.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: agregado por dispositivo y estado)

```sql
SELECT device_type, piece_status, COUNT(*) AS pieces, SUM(bytes) AS backup_bytes,
       ROUND((SYSDATE - MAX(completion_time)) * 24, 2) AS hours_since_newest,
       ROUND((SYSDATE - MIN(completion_time)) * 24, 2) AS hours_since_oldest
FROM  (SELECT CASE WHEN device_type IN ('DISK', 'SBT_TAPE') THEN device_type ELSE 'OTHER' END AS device_type,
              DECODE(status, 'A', 'AVAILABLE', 'X', 'EXPIRED', 'U', 'UNAVAILABLE', 'OTHER') AS piece_status,
              bytes, completion_time
       FROM   v$backup_piece
       WHERE  status <> 'D')
GROUP  BY device_type, piece_status
ORDER  BY device_type, piece_status;
```

# Notes by version

Columnas estables desde 10.2. Una sola variante: el agregado no usa `FETCH FIRST`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`; desde `CDB$ROOT` incluye las piezas de todos los contenedores.

# Cost classification rationale

`MEDIUM` — recorre los registros de piezas del controlfile; devuelve a lo más una fila por dispositivo y estado.

# License notes

Ninguna.

# Sanitization notes

`HANDLE` (ruta, ASM o SBT) y `TAG` nunca se seleccionan: antes se tokenizaban, desde 2.0.0 no salen de la base. Solo el tipo de dispositivo (`DISK`, `SBT_TAPE` u `OTHER`), el estado traducido, conteos, bytes y horas. Las piezas borradas (`D`) se excluyen; `EXPIRED` indica piezas registradas que `CROSSCHECK` no encontró.

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: agregado por dispositivo y estado; `HANDLE`, `TAG`, `RECID` y fechas fuera.
