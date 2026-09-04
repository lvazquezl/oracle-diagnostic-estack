---
name: db-cpu
display_name: "DB CPU"
id: performance/db-cpu
version: 1.0.0
domain: performance
status: active
---

# Purpose

Correlacionar DB CPU con Host CPU (cuando disponible), top SQL por CPU, executions, paralelismo y evidencia de run queue/OS — nunca concluir automáticamente "high DB CPU = CPU problem" sin esa correlación.

# Scope

**En alcance:** DB CPU de la instancia y su correlación con top SQL CPU, executions y (cuando `os-platform-analyst` provee evidencia) Host CPU.
**Fuera de alcance:** tuning de SQL individual, análisis OS profundo (delegado a `os-platform-analyst`).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas — Host CPU es evidencia opcional provista por `os-platform-analyst`, no recolectada directamente por este skill.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. Primary.

# Licensing

`Q-PERF-DBTIME-001` (AWR, DB CPU histórico) requiere Diagnostics Pack; `Q-PERF-DBTIME-CURRENT-001` (ruta estándar) no.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-DBTIME-001`/`Q-PERF-DBTIME-CURRENT-001` (DB CPU)
- `Q-PERF-TOPSQL-001`/`Q-PERF-TOPSQL-CURRENT-001` (top SQL por CPU)

# Optional evidence

- `Q-PERF-PARALLEL-001` (paralelismo activo, contribuye a CPU)
- Evidencia de Host CPU/run queue vía `os-platform-analyst` (routing, no evidencia propia de este skill)

# Data collection

Reutiliza la evidencia de `performance/db-time` y `performance/top-sql`; no introduce queries propias adicionales.

# Diagnostic logic / Decision tree

```text
1. Leer db_cpu_sec de la ventana/snapshot.
2. Leer top SQL ordenado por cpu_sec — identificar concentración.
3. IF top SQL concentra >50% del db_cpu_sec en pocos sql_id AND executions altas
        → HYPOTHESIS: CPU-bound concentrado, candidato performance/hard-parse si parse count también es alto
4. IF Host CPU evidence disponible (os-platform-analyst) AND host_cpu_pct alto Y coincide con db_cpu alto
        → correlación cruzada, sigue siendo HYPOTHESIS sin evidencia OS más profunda
5. Nunca declarar "problema de CPU" sin al menos top SQL correlacionado.
```

# Normal behavior

DB CPU proporcional a la actividad de sesiones concurrentes, sin concentración extrema en un único `sql_id`.

# Abnormal patterns

DB CPU alto con `parse count (hard)` desproporcionado (→ `performance/hard-parse`); DB CPU alto con paralelismo activo desproporcionado (→ `performance/parallelism`).

# Root cause patterns

Ninguno confirmado por este skill solo — requiere correlación con `performance/top-sql` como mínimo, y evidencia OS/run queue de `os-platform-analyst` para `PROBABLE_CAUSE` con mayor certeza.

# Correlation rules

Nunca reportar `db_cpu_sec` alto sin el top SQL de la misma ventana. Nunca concluir "CPU-bound" sin descartar paralelismo como explicación (un DOP alto legítimamente consume mucho CPU sin ser un problema).

# False positives

Un `db_cpu_sec` alto durante una ventana de carga batch programada (ej. ETL nocturno) no es una anomalía si coincide con el patrón esperado — se requiere contexto de baseline (`performance/trending`) para escalar severidad.

# Confidence model

`FACT` para `db_cpu_sec` leído directamente. `HYPOTHESIS` con top SQL correlacionado. `PROBABLE_CAUSE` sólo con evidencia OS adicional confirmando ausencia de contención externa.

# Output schema

```yaml
findings:
  - db_cpu_sec: number
    top_sql_cpu_concentration_pct: number
    host_cpu_pct: number|null
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/db-time`, `performance/top-sql`, `performance/hard-parse`, `performance/parallelism`.

# Escalation

Requiere evidencia OS/run queue → `os-platform-analyst`. Multi-síntoma → `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-high-cpu.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA-MEDIA (`sql_id`). Presupuesto bajo-medio.

# Tests

`tests/test_awr_db_cpu.sh`, `tests/test_standard_path_db_cpu.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca concluye CPU-bound sin correlación con top SQL/paralelismo/evidencia OS. |
