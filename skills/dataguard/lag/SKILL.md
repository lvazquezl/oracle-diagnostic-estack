---
name: lag
id: dataguard/lag
version: 2.0.0
domain: dataguard
status: active
---

# Purpose

Medir `TRANSPORT LAG` y `APPLY LAG` — dos métricas distintas, **nunca sinónimos** (`# 13` del prompt de Fase 5) — y establecer tendencia cuando hay múltiples observaciones, sin nunca concluir causa con un único valor.

# Supported Oracle versions

10g–23ai. `V$DATAGUARD_STATS` disponible desde 10g; columnas `APPLY_LAG`/`TRANSPORT_LAG` estables desde 11g.

# Supported OS/platforms

Todas — el lag se mide desde vistas de diccionario, no depende del OS salvo para correlacionar causa.

# Supported Data Guard architectures

PHYSICAL_STANDBY (foco). Aplica conceptualmente a LOGICAL_STANDBY con distinta semántica de apply.

# Prerequisites

`dataguard/transport` y `dataguard/apply` resueltos.

# Required evidence

- `Q-DG-STATS-001` (`V$DATAGUARD_STATS` — `TRANSPORT_LAG`, `APPLY_LAG`)

# Optional evidence

- `Q-DG-ARCHIVE-GAP-001` (para distinguir lag por gap vs. lag por apply lento).

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-STATS-001`, `Q-DG-ARCHIVE-GAP-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$DATAGUARD_STATS`, `V$ARCHIVE_DEST_STATUS`, `V$ARCHIVE_GAP`, `V$MANAGED_STANDBY`.

# Forbidden operations

No ejecuta `ALTER DATABASE REGISTER LOGFILE`, no reinicia MRP/RFS, no cambia protection mode.

# Decision logic

1. Leer `transport_lag` y `apply_lag` de `V$DATAGUARD_STATS` por separado — nunca reportados como un valor único combinado.
2. **`# 57`**: `transport_lag` alto NO prueba un problema de red — causas posibles: red, destino inalcanzable, pico de generación de redo en el primary, problema LNS/LGWR, backlog de archive, storage remoto, configuración. Correlacionar con `dataguard/transport` antes de clasificar.
3. **`# 56`**: `apply_lag` alto es una OBSERVACIÓN, no una causa raíz — correlacionar siempre con: generación de redo, transport lag, red, standby receive, proceso de apply (`dataguard/apply`), CPU, I/O, storage, threads RAC antes de cualquier clasificación de causa.
4. Si `apply_lag > threshold` de política (`policies/`) → severidad según cuánto excede (`MEDIUM` 1-3x, `HIGH` mayor).
5. Correlacionar con `V$ARCHIVE_GAP`: lag por gap de archivelog (requiere resolución de transporte, ver `dataguard/archive-gaps`) vs. apply lento con transporte al día (requiere revisión de recursos en el standby).
6. Correlacionar con protection mode (`dataguard/protection`): en `MAXIMUM AVAILABILITY`/`MAXIMUM PROTECTION` con SYNC, cualquier lag sostenido es más crítico que en `MAXIMUM PERFORMANCE` con ASYNC.

# Lag trending

Con múltiples observaciones disponibles (`# 14`): `STABLE`, `INCREASING`, `DECREASING`, `INTERMITTENT`, `CATCHING_UP`. Usa alineación temporal de evidencia ya recolectada — nunca forecasting complejo, nunca predicción más allá de la evidencia observada.

# Normal state

`transport_lag`/`apply_lag` dentro del umbral de política, tendencia `STABLE` o `DECREASING`.

# Abnormal patterns

`apply_lag` con tendencia `INCREASING` sostenida; `transport_lag` alto coincidente con destino en `ERROR`.

# False positives

Pico transitorio de lag durante una ventana de carga batch conocida, seguido de `CATCHING_UP` — no es un problema si el sistema se recupera dentro de la ventana esperada.

# Correlation rules

`apply_lag`: correlaciona con `dataguard/apply` (estado MRP), `oracle-performance-analyst` (CPU/I/O/parallel recovery/redo generation — `# 42`), `oracle-asm-storage-analyst`/`os-platform-analyst` (I/O — `# 41`, `# 43`), `oracle-rac-analyst` (threads — `# 16`). `transport_lag`: correlaciona con `dataguard/transport` (estado del destino), `oracle-network-analyst` (sólo con evidencia real, `# 40`, `# 57`).

# Confidence model

`FACT` para el lag leído directamente. `OBSERVATION` es el estado por defecto de todo hallazgo de lag (nunca se reporta como causa raíz por sí solo). `PROBABLE_CAUSE` sólo cuando se correlaciona con 2+ señales (ej. degradación de red confirmada + transport lag simultáneo).

# Severity

`apply_lag`/`transport_lag` > 3x umbral de política → `HIGH`; 1-3x → `MEDIUM`; dentro de umbral → `INFO`.

# Output schema

```yaml
findings:
  - metric: TRANSPORT_LAG|APPLY_LAG
    thread: number|null
    value_seconds: number
    threshold_seconds: number
    trend: STABLE|INCREASING|DECREASING|INTERMITTENT|CATCHING_UP|UNKNOWN
    severity: INFO|LOW|MEDIUM|HIGH
    confidence: FACT|OBSERVATION
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/transport`, `dataguard/apply`, `dataguard/archive-gaps`, `dataguard/protection`, `dataguard/switchover-readiness`.

# Escalation

Severidad `HIGH` con riesgo de incumplimiento de RPO → `incident-root-cause-analyst`; causa identificada y accionable → `change-advisor`.

# Manual remediation guidance

Ninguna acción ejecutable sobre lag directamente — las acciones correctivas pertenecen al dominio correlacionado (transport/apply/network/storage).

# Security

Baja: métricas de lag no incluyen datos de negocio. Nombres de destino se enmascaran según política.

# Tests

`tests/test_dataguard_stats_query.sh`, `tests/test_transport_lag.sh`, `tests/test_transport_lag_not_automatically_network.sh`, `tests/test_apply_lag.sh`, `tests/test_no_write_operations.sh`, `tests/test_primary_standby_detection.sh`, `tests/test_no_switchover_failover.sh`.

# Documentation requirements

Alimenta `lag-analysis.md` con lag actual vs. umbral, tendencia, y correlación aplicada; declara explícitamente si el ambiente no está listo para switchover por lag excesivo.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Foundation | Skill plano `skills/dataguard/lag.md`. |
| 2.0.0 | Fase 5 | Reescrito bajo Deep Skill Contract, agrega lag trending, distinción explícita transport vs. apply lag como reglas nombradas (`# 56`/`# 57`), correlación cross-domain completa. |
