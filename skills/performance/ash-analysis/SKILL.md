---
name: ash-analysis
display_name: "ASH Analysis"
id: performance/ash-analysis
version: 1.0.0
domain: performance
status: active
---

# Purpose

Diagnosticar contención puntual mediante muestreo de sesiones activas (Active Session History), trabajando preferentemente con agregados por ventana/wait class/evento/SQL_ID en vez de muestras masivas individuales.

# Scope

**En alcance:** agregación de `V$ACTIVE_SESSION_HISTORY`/`DBA_HIST_ACTIVE_SESS_HISTORY` sobre una ventana acotada, por `wait_class`/`event`/`sql_id`/`session count`/instancia/relación de bloqueo.
**Fuera de alcance:** envío de muestras crudas fila por fila; ventanas históricas amplias sin acotar.

# Supported Oracle versions

10g–23ai. `V$ACTIVE_SESSION_HISTORY`/`DBA_HIST_ACTIVE_SESS_HISTORY` disponibles desde 10g con Diagnostics Pack.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB (`CON_ID` cuando existe). ASM y Filesystem. Primary (foco principal).

# Licensing

Requiere Diagnostics Pack — detrás del Licensing Gate, sin excepción. Sin confirmación, `capability_status: LICENSE_RESTRICTED`; no existe fallback de igual granularidad (ASH no tiene equivalente en Statspack) — el agente cae a `performance/wait-events` (agregado, menor granularidad) o `performance/statspack-analysis`.

# Prerequisites

Target Profile publicado, `constraints.time_window` explícito y **acotado** (nunca "todo lo disponible"), `constraints.license_confirmed.diagnostics_pack: true`.

# Required evidence

- `Q-PERF-WAIT-ASH-001`

# Optional evidence

- `Q-PERF-BLOCKING-001` (relación de bloqueo cruzada con sesiones activas en la ventana)

# Data collection

Lectura de `V$ACTIVE_SESSION_HISTORY` (ventana reciente en memoria) o `DBA_HIST_ACTIVE_SESS_HISTORY` (ventana fuera de retención en memoria, requiere snapshot AWR) — nunca tablas de aplicación.

# Diagnostic logic / Decision tree

```text
1. Agregar muestras por (time_bucket, wait_class, event, sql_id, instance).
2. Identificar el wait_class/event dominante por conteo de muestras en la ventana.
3. Cruzar con blocking_session (si Q-PERF-BLOCKING-001 disponible) para contención puntual.
4. Si el wait dominante coincide temporalmente con el síntoma reportado por el DBA → HYPOTHESIS.
```

# Normal behavior

Sesiones activas distribuidas sin concentración extrema en un único `wait_class`/`sql_id` durante la ventana reportada como problemática.

# Abnormal patterns

Pico abrupto de sesiones activas concentradas en un `wait_class`/`event` específico coincidente con la ventana del síntoma reportado; alta proporción de sesiones en `blocking_session IS NOT NULL`.

# Root cause patterns

Contención puntual confirmada por concentración temporal + correlación con `performance/blocking`/`performance/top-sql` — nunca `CONFIRMED_ROOT_CAUSE` sin validación cruzada de `incident-root-cause-analyst`.

# Correlation rules

Cruzar siempre con `sql_id` (→ `performance/top-sql`) y `blocking_session` (→ `performance/blocking`) antes de reportar contención puntual.

# False positives

Un pico de muestras ASH en una ventana muy corta (segundos) puede reflejar variabilidad normal de muestreo, no necesariamente un evento significativo — se requiere persistencia mínima (varias muestras consecutivas) antes de escalar severidad.

# Confidence model

`FACT` para el conteo de muestras agregado. `HYPOTHESIS`/`PROBABLE_CAUSE` sólo con correlación temporal + cruce con `sql_id`/`blocking_session`. Nunca `CONFIRMED_ROOT_CAUSE`.

# Output schema

```yaml
findings:
  - time_bucket: string
    wait_class: string
    event: string
    session_count: number
    sql_id: string|null
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/wait-events`, `performance/top-sql`, `performance/blocking`, `performance/concurrency`.

# Escalation

Contención sostenida y multi-síntoma → `incident-root-cause-analyst`. Wait dominante `Cluster` → `oracle-rac-analyst`.

# Examples

Ver `tests/fixtures/19c-blocking.yaml` (sesiones ASH concentradas en `enq: TX - row lock contention`).

# Data sensitivity / Context budget

Sensibilidad MEDIA (`sql_id`, `session_id`/`session_serial#`; nunca SQL text/bind values). Presupuesto alto — mitigado por agregación local obligatoria (nunca muestras crudas) y ventana estrictamente acotada.

# Tests

`tests/test_ash_license_gate.sh`, `tests/test_no_write_operations.sh`, `tests/test_query_cost_high.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — agregación ASH por wait_class/event/sql_id/instancia, nunca muestras crudas. |
