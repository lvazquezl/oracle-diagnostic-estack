---
name: wait-events
display_name: "Wait Events"
id: performance/wait-events
version: 2.0.0
domain: performance
status: active
---

# Purpose

Identificar los wait events dominantes en una ventana de tiempo y clasificarlos por wait class para orientar el diagnóstico de performance (I/O, concurrencia, red/Cache Fusion, aplicación).

# Scope

**En alcance:** top-N wait events por tiempo total de espera, clasificados por `wait_class`, sobre AWR/ASH (licenciado), Statspack (sin licencia) o snapshot dinámico actual (`Q-PERF-IO-001` para el subconjunto de I/O/commit).
**Fuera de alcance:** interpretación profunda de `gc *` (RAC — `oracle-rac-analyst`), generación de trace files, `ALTER SESSION SET EVENTS`.

# Supported Oracle versions

10g–23ai. Fuente principal: AWR (`DBA_HIST_SYSTEM_EVENT`) desde 10g con Diagnostics Pack; fallback a Statspack (`STATS$SYSTEM_EVENT`) si no está licenciado; ASH (`V$ACTIVE_SESSION_HISTORY`/`DBA_HIST_ACTIVE_SESS_HISTORY`) para granularidad fina; `V$SYSTEM_EVENT` para el subconjunto I/O/commit sin ventana ni licencia.

# Supported OS/platforms

Todas — el análisis es lógico sobre el repositorio de diagnóstico Oracle.

# Supported architectures

Standalone y RAC (`GV$`/`DBA_HIST_*` por instancia; este skill reporta por instancia, la agregación cross-instance la hace `oracle-rac-analyst` vía `rac/gc-waits`). NON-CDB y CDB. ASM y Filesystem (afecta interpretación de waits `db file *`). Primary (foco principal — en standby la actividad de sesiones de usuario es mínima o nula).

# Licensing

`Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-ASH-001` requieren Diagnostics Pack. `Q-PERF-WAIT-STATSPACK-001` y `Q-PERF-IO-001` no requieren licencia — usados automáticamente cuando Diagnostics Pack no está confirmado.

# Prerequisites

Requiere `core/context-discovery` confirmado y, si Diagnostics Pack no está licenciado, declarar explícitamente el fallback a Statspack.

# Required evidence

- `Q-PERF-WAIT-AWR-001` (AWR, licenciado) o `Q-PERF-WAIT-STATSPACK-001` (Statspack, sin licencia) o `Q-PERF-IO-001` (dinámico, subconjunto I/O/commit, sin licencia)

# Optional evidence

- `Q-PERF-WAIT-ASH-001` (granularidad ASH)

# Read-only operations

Lectura de `DBA_HIST_SYSTEM_EVENT`, `V$SYSTEM_EVENT`, `V$ACTIVE_SESSION_HISTORY`, `STATS$SYSTEM_EVENT` (fallback).

# Forbidden operations

No ejecuta `ALTER SESSION SET EVENTS`, no genera trace files, no mata sesiones en espera.

# Decision logic

1. Ordenar wait events por tiempo total de espera en la ventana solicitada, excluyendo `Idle` wait class.
2. Clasificar el top-N por `wait_class` (`User I/O`, `System I/O`, `Concurrency`, `Application`, `Network`, `Cluster`, `Commit`, `Configuration`, `Administrative`, `Scheduler`, `CPU`, `Other`).
3. Si el top wait es `wait_class = Cluster` (`gc *`) → señalar para escalar a `rac/gc-waits` — nunca usarlo como causa si el target no es RAC (ver `# 16. WAIT EVENTS` del prompt de Fase 3).
4. Si el top wait es `User I/O` con `db file sequential/scattered read` dominante → correlacionar con `performance/io` y potencialmente `asm/io`.
5. Si el top wait es `Concurrency` (`latch free`, `buffer busy waits`) → correlacionar con `performance/concurrency`/`performance/locking`.
6. La severidad nunca se basa únicamente en tiempo total de espera — considerar también `average_wait`, `wait_count`, `pct_db_time`, workload y baseline/tendencia (ver `# 17. WAIT ANALYSIS RULE`).

# Confidence model

`FACT` para el tiempo total de espera leído directamente. `PROBABLE_CAUSE` cuando el wait dominante coincide temporalmente con el síntoma reportado por el DBA y con el top SQL asociado (`performance/top-sql`). Nunca asigna `CONFIRMED_ROOT_CAUSE` por sí solo — eso requiere validación cruzada por `incident-root-cause-analyst`.

# Output schema

```yaml
findings:
  - wait_event: string
    wait_class: string
    total_wait_time_sec: number
    avg_wait_ms: number
    wait_count: number
    pct_db_time: number
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/wait-classes`, `performance/top-sql`, `performance/db-time`, `performance/ash-analysis`, `performance/statspack-analysis`, `rac/gc-waits`, `performance/io`.

# Escalation

Si el wait dominante es `Cluster` o `Network`, señala `next_skill_or_agent` hacia `oracle-rac-analyst`/`oracle-network-analyst` respectivamente en el Result Package del agente que lo invoca.

# Data sensitivity

Media: puede incluir SQL_ID y nombres de objetos asociados a esperas de buffer; nunca incluye SQL text completo ni bind values (ver `performance/top-sql` para esa política).

# Context budget

Medio: se acota estrictamente por la ventana de tiempo (`time_window`) del Task Package; nunca se procesa un AWR completo sin ventana.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_version_awareness.sh` (fallback AWR→Statspack), `tests/test_io_wait_analysis.sh`.

# Documentation requirements

Alimenta `findings.md` con el top-N de wait events y su wait class.

# Evolution via `/change`

Cambios al top-N o a los umbrales de severidad vía `/change policy`; nuevas fuentes de evidencia vía `/change query`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 1 (Foundation) | Materializado como ejemplo representativo del dominio `performance`. |
| 2.0.0 | Fase 3 (Oracle Performance) | Reestructurado a `skills/performance/wait-events/SKILL.md` + `manifest.yaml`. Agregada ruta dinámica sin licencia (`Q-PERF-IO-001`), referencia actualizada a rutas relocalizadas `queries/performance/waits/`, `avg_wait_ms`/`wait_count`/`pct_db_time` agregados al output schema (regla de `# 17. WAIT ANALYSIS RULE`). |
