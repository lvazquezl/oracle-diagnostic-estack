---
name: resource-usage
id: multitenant/resource-usage
version: 2.0.0
domain: multitenant
status: active
---

# Purpose

Análisis de consumo de recursos por PDB (CPU, sesiones, parallel servers, SGA/PGA, I/O) con fuentes licensing-safe — nunca depende de AWR/ASH salvo delegación explícita con Licensing Gate propio (`# 30` del prompt de Fase 6).

# Supported Oracle versions

12.2–23ai (`V$RSRCPDBMETRIC` no existe en 12.1 — ver "Version degradation — 12.1" abajo).

# Version degradation — 12.1

`V$RSRCPDBMETRIC` se introduce en Oracle Database 12.2.0.1 (verificado, PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING) — no existe en 12.1. No hay una fuente equivalente certificada de métricas de recursos por PDB para 12.1 (no se inventa una alternativa, `# 11` del prompt de hardening). En un target 12.1, este skill publica:

```yaml
capability_status: PARTIALLY_SUPPORTED
reason: "V$RSRCPDBMETRIC no certificada en 12.1 (introducida en 12.2.0.1) — sin fuente equivalente certificada de PDB-level resource metrics para 12.1"
```

El resto del dominio Multitenant en un target 12.1 no se ve afectado — esta degradación es específica de la sub-capability de resource usage, nunca del dominio completo.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-RESOURCE-USAGE-001` (`V$RSRCPDBMETRIC`)

# Optional evidence

Delegación a `oracle-performance-analyst` (con su propio Licensing Gate) si se requiere detalle AWR/ASH.

# Licensing requirements

Ninguno para `V$RSRCPDBMETRIC` — licensing-safe.

# Query IDs

`Q-CDB-RESOURCE-USAGE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$RSRCPDBMETRIC`.

# Forbidden operations

No modifica límites de recursos.

# Decision logic

1. Reportar `cpu_consumed_time`/`avg_cpu_utilization` contra `cpu_utilization_limit` — señal de presión sólo si se acerca al límite configurado, nunca en abstracto.
2. Reportar `avg_running_sessions`/`avg_waiting_sessions` contra `running_sessions_limit`.
3. Reportar `avg_active_parallel_servers`/`avg_queued_parallel_servers` contra `parallel_servers_limit` — parallel servers en cola sostenidos son señal de contención.
4. Delegar a `oracle-performance-analyst` si se requiere el detalle de qué SQL/sesión específica consume el recurso — este skill sólo da el agregado por PDB.

# Normal state

Consumo por debajo de los límites configurados, sin sesiones/parallel servers en cola sostenidos.

# Abnormal patterns

`avg_cpu_utilization` cerca de `cpu_utilization_limit` sostenido; `avg_queued_parallel_servers > 0` sostenido.

# False positives

Un pico temporal durante una carga batch conocida no es un problema por sí solo.

# Correlation rules

Correlaciona con `multitenant/resource-manager` (¿el límite es el esperado por diseño?) y con `multitenant/pdb-sessions` (¿el consumo de CPU coincide con concentración de sesiones?).

# Confidence model

`FACT` para las métricas leídas directamente. `OBSERVATION` para la interpretación de presión.

# Severity

Consumo sostenido cerca del límite → `MEDIUM`/`HIGH` según margen y duración.

# Output schema

```yaml
resource_usage:
  - pdb_token: string
    cpu_consumed_time: number|null
    avg_cpu_utilization: number|null
    sessions_current: int|null
    parallel_servers_current: int|null
    sga_bytes: int|null
    pga_bytes: int|null
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/resource-manager`, `multitenant/pdb-sessions`.

# Escalation

Saturación sostenida con impacto en producción → `oracle-performance-analyst`, luego `incident-root-cause-analyst` si no se resuelve.

# Manual remediation guidance

Ajuste de límites se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED` — nunca se afirma throttling sin evidencia directa (`# 31`).

# Security

`pdb_token` tokenizado.

# Tests

`tests/test_pdb_resource_usage.sh`, `tests/test_no_resource_plan_change.sh`, `tests/test_no_resource_limit_change.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
v2.0.0 — PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING. `V$RSRCPDBMETRIC` corregida de min_version "12.1" (nunca verificado independientemente) a "12.2" (verificado, introducida en 12.2.0.1) — agregada degradación explícita `PARTIALLY_SUPPORTED` para 12.1 en vez de fingir soporte.
