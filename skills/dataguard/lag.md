---
name: lag
id: dataguard/lag
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Medir lag de transporte y de apply entre primary y standby, y evaluar si está dentro del umbral de RPO definido por política, sin ejecutar ninguna acción correctiva.

# Supported Oracle versions

10g–23ai. `V$DATAGUARD_STATS` disponible desde 10g; columnas adicionales (`APPLY_LAG`, `TRANSPORT_LAG`) estables desde 11g.

# Supported OS/platforms

Todas — el lag se mide desde vistas de diccionario, no depende del OS salvo para correlacionar causa (red/I/O).

# Supported architectures

Standalone y RAC en cualquiera de los sitios. NON-CDB y CDB (lag a nivel CDB completo). ASM y Filesystem. Primary y Physical Standby (es el foco central del skill); Active Data Guard cuando esté licenciado (afecta si hay sesiones de lectura activas en el standby durante la medición).

# Prerequisites

Requiere `core/context-discovery` confirmando `database_role` en ambos sitios (o al menos el sitio consultado).

# Required evidence

- query_id: `Q-DG-STATS-001` (`get_dataguard_status`, incluye `V$DATAGUARD_STATS`)

# Optional evidence

- query_id: `Q-DG-ARCHIVE-GAP-001` (`V$ARCHIVE_GAP`, para distinguir lag por gap vs. lag por apply lento)

# Read-only operations

Lectura de `V$DATAGUARD_STATS`, `V$ARCHIVE_DEST_STATUS`, `V$ARCHIVE_GAP`, `V$MANAGED_STANDBY`.

# Forbidden operations

No ejecuta `ALTER DATABASE REGISTER LOGFILE`, no reinicia MRP/RFS, no cambia protection mode.

# Decision logic

1. Leer `transport_lag` y `apply_lag` de `V$DATAGUARD_STATS` en el standby.
2. Si `apply_lag > RPO_threshold` de política → severidad según cuánto excede (`MEDIUM` si es 1-3x el umbral, `HIGH` si es mayor).
3. Si hay entradas en `V$ARCHIVE_GAP`, distinguir: el lag es por un gap de archivelog (requiere resolución de transporte) vs. apply lento con transporte al día (requiere revisión de recursos en el standby).
4. Correlacionar con protection mode: en `Maximum Availability`/`Maximum Protection` con SYNC, cualquier lag sostenido es más crítico que en `Maximum Performance` con ASYNC.

# Confidence model

`FACT` para el lag leído directamente. `PROBABLE_CAUSE` cuando el lag se correlaciona con degradación de red (`oracle-network-analyst`) o I/O en el standby (`os-platform-analyst`/`oracle-asm-storage-analyst`) en la misma ventana.

# Output schema

```yaml
findings:
  - metric: transport_lag|apply_lag
    value_seconds: number
    threshold_seconds: number
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/archive-gap`, `dataguard/mrp`, `dataguard/rfs`, `dataguard/protection-mode`, `dataguard/readiness`.

# Escalation

Severidad `HIGH` con riesgo de incumplimiento de RPO escala a `incident-root-cause-analyst`; causa identificada y accionable escala a `change-advisor`.

# Data sensitivity

Baja: métricas de lag no incluyen datos de negocio. Nombres de destino se enmascaran según política.

# Context budget

Bajo: `V$DATAGUARD_STATS` es una vista compacta.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_primary_standby_detection.sh`, `tests/test_no_switchover_failover.sh`.

# Documentation requirements

Alimenta `findings.md` con lag actual vs. umbral y, si aplica, declara explícitamente si el ambiente no está listo para switchover por lag excesivo.

# Evolution via `/change`

Umbral de RPO vía `/change policy`; nuevas queries vía `/change query`.
