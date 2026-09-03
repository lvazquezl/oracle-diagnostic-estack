---
query_id: Q-DISC-ASM-001
version: 2.0.0

domain: oracle
purpose: Presencia de ASM (confirmación de storage_mode, no detalle de disk groups)

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$ASM_DISKGROUP_STAT, V$ASM_DISKGROUP]
privileges_required: [SELECT on V$ASM_DISKGROUP_STAT, SELECT on V$ASM_DISKGROUP]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 20
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Oracle Core Compatibility Hardening: bug INCORRECT_COST_CLASS corregido — la v1.0 usaba
# V$ASM_DISKGROUP (puede disparar disk discovery) como cost_class LOW para polling rutinario.
# Ahora el variant por defecto usa V$ASM_DISKGROUP_STAT (no dispara discovery); V$ASM_DISKGROUP
# queda como variant on-demand, cost_class MEDIUM, sólo cuando el DBA/análisis lo requiere
# explícitamente (nunca activado por defecto en /healthcheck).
variants:
  - variant_id: Q-DISC-ASM-001-V1
    label: routine_stat
    oracle_versions: {min: "11.0", max: latest}
    container_scope: NOT_APPLICABLE
    cost_class: LOW
    default: true
    sql_block: "Variant V1 (routine_stat, 11.0+) — DEFAULT"
  - variant_id: Q-DISC-ASM-001-V2
    label: detailed_diskgroup
    oracle_versions: {min: "11.0", max: latest}
    container_scope: NOT_APPLICABLE
    cost_class: MEDIUM
    default: false
    on_demand_only: true
    sql_block: "Variant V2 (detailed_diskgroup, 11.0+) — ON-DEMAND ONLY"

tests: [tests/test_no_write_operations.sh, tests/test_asm_read_only.sh, tests/test_every_logical_query_has_variant.sh, tests/test_asm_monitoring_does_not_use_diskgroup_discovery_view.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (routine_stat, 11.0+) — DEFAULT

```sql
SELECT name, state, type, total_mb
FROM   v$asm_diskgroup_stat;
```

Variante por defecto para discovery/healthcheck rutinario. `V$ASM_DISKGROUP_STAT` es idéntica en columnas a `V$ASM_DISKGROUP` pero **no dispara descubrimiento de discos** — está diseñada exactamente para monitoreo periódico de bajo costo (ver sección 13 del prompt de Oracle Core Compatibility Hardening).

# Statement / procedure (read-only) — Variant V2 (detailed_diskgroup, 11.0+) — ON-DEMAND ONLY

```sql
SELECT name, state, type, total_mb
FROM   v$asm_diskgroup;
```

**No se activa por defecto.** Sólo se selecciona cuando un workflow/skill lo solicita explícitamente con justificación (ej. `V$ASM_DISKGROUP_STAT` reportó datos inconsistentes o stale y se requiere una lectura fresca) — el gate `cost` del workflow debe aprobarlo (`policies/query-cost-policy.md`), igual que cualquier otra query `cost_class: MEDIUM`.

Si la sesión de diagnóstico no tiene acceso a la instancia ASM (arquitectura común: la instancia de base de datos consulta ASM vía una conexión separada), esta query se ejecuta contra la instancia ASM si el collector la certifica con esa ruta; si no hay acceso, `oracle-discovery-analyst` infiere `storage_mode` por el patrón de rutas en `DBA_DATA_FILES` (`Q-DBA-TBS-USAGE-001`) como evidencia secundaria, declarando la confianza como `OBSERVATION` en vez de `FACT`.

# Notes by version

`V$ASM_DISKGROUP_STAT` y `V$ASM_DISKGROUP` ambas desde 11g — no certificadas en este catálogo antes de esa versión (ver `config/capability-matrix.yaml`, fila `asm`). ASM existe en Oracle desde 10g pero queda fuera del catálogo certificado para ese release.

# Notes by platform

Ninguna diferencia en ninguna variante — SQL puro.

# Container / role scope notes

Independiente de tenancy en ambas variantes — `NOT_APPLICABLE`.

# Cost classification rationale

`V1 (V$ASM_DISKGROUP_STAT)`: `LOW` — vista de estadísticas cacheadas, sin disk discovery. `V2 (V$ASM_DISKGROUP)`: `MEDIUM` — puede disparar disk discovery en el kernel ASM, impacto operacional no despreciable incluso siendo read-only (`READ-ONLY DOES NOT MEAN ZERO OPERATIONAL IMPACT`, principio no negociable de este hardening). Ver `policies/query-cost-policy.md`.

# License notes

Ninguna en ninguna variante.

# Sanitization notes

`name` (nombre de disk group) → MASK por defecto si revela topología interna, en ambas variantes.

# Evolution via `/change query`

Si telemetría real (Fase 7+) muestra que `V$ASM_DISKGROUP_STAT` queda stale en algún patrón de uso, reevaluar el default vía `/change query` — nunca revertir a `V$ASM_DISKGROUP` como default sin justificación documentada.
