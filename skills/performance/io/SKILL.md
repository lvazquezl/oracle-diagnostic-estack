---
name: io
display_name: "I/O"
id: performance/io
version: 1.0.0
domain: performance
status: active
---

# Purpose

Correlacionar waits de I/O dominantes con latencia por datafile — sin afirmar un problema de storage sin evidencia OS/storage adicional.

# Scope

**En alcance:** waits de I/O agregados (`db file sequential/scattered read`, `direct path read/write`, `log file parallel write`, `log file sync`) y latencia por datafile.
**Fuera de alcance:** diagnóstico de storage/ASM profundo (delegado a `oracle-asm-storage-analyst`/`os-platform-analyst`).

# Supported Oracle versions

10g–23ai. `V$SYSTEM_EVENT`/`V$FILESTAT`/`V$DATAFILE` estables en todo el rango.

# Supported OS/platforms

Todas — latencia física depende del driver de I/O del SO subyacente, correlacionada vía `os-platform-analyst` cuando se requiera evidencia adicional.

# Supported architectures

Standalone y RAC (por instancia). ASM y Filesystem (interpretación distinta — I/O sobre ASM puede requerir correlación con `oracle-asm-storage-analyst`). Primary.

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-IO-001` (waits agregados)

# Optional evidence

- `Q-PERF-IO-FILESTAT-001` (desglose por datafile)
- `Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-STATSPACK-001` (ventana histórica en vez de snapshot actual)

# Data collection

Lectura de `V$SYSTEM_EVENT`, `V$FILESTAT`, `V$DATAFILE`.

# Diagnostic logic / Decision tree

```text
1. Leer waits de I/O agregados (Q-PERF-IO-001).
2. Si el wait dominante es User I/O → desglosar por archivo (Q-PERF-IO-FILESTAT-001).
3. Sin evidencia OS/storage adicional, un valor de latencia alto es OBSERVATION, no confirmación de problema de storage (# 27. I/O del prompt de Fase 3).
4. log file sync alto + log file parallel write normal → HYPOTHESIS de comportamiento de commit de aplicación (ver performance/commit-redo).
5. log file sync alto + log file parallel write alto → HYPOTHESIS de latencia de storage de redo, requiere evidencia OS/storage para PROBABLE_CAUSE.
```

# Normal behavior

Latencia de lectura/escritura dentro de rangos esperados para el tipo de storage (ver `# Notes by platform` en las queries) sin waits de I/O dominando el DB Time de forma desproporcionada.

# Abnormal patterns

`avg_read_latency_ms`/`avg_write_latency_ms` sostenidamente altos en múltiples datafiles simultáneamente (indicio de storage compartido bajo presión, no un archivo específico).

# Root cause patterns

`PROBABLE_CAUSE` de problema de storage requiere evidencia externa (OS/storage) confirmando — nunca se asigna sólo con la latencia reportada por Oracle.

# Correlation rules

Cruzar siempre `log file sync` con `log file parallel write` (ver `performance/commit-redo`). Cruzar I/O de datos con `performance/sql-io` para identificar el `sql_id` responsable si aplica.

# False positives

Latencia alta en un único datafile pequeño y poco usado no es representativa del storage general — evaluar en el contexto del volumen de I/O (`phyrds`/`phywrts`) de ese archivo específico.

# Confidence model

`FACT` para tiempos/latencias leídos directamente. `OBSERVATION` para latencia alta sin evidencia externa. `PROBABLE_CAUSE` sólo con evidencia OS/storage corroborando (`# 72` del prompt de Fase 3 — regla equivalente aplicada a storage).

# Output schema

```yaml
findings:
  - wait_event: string
    total_wait_time_sec: number
    file_name: string|null
    avg_read_latency_ms: number|null
    avg_write_latency_ms: number|null
    confidence: FACT|OBSERVATION|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/wait-events`, `performance/commit-redo`, `performance/sql-io`, `performance/temp`.

# Escalation

Latencia sostenida sin evidencia OS suficiente → `os-platform-analyst`. I/O dominado por ASM con indicio de contención → `oracle-asm-storage-analyst`.

# Examples

Ver `tests/fixtures/19c-high-io.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (`file_name` puede revelar ruta/hostname de storage — enmascarado por defecto). Presupuesto medio.

# Tests

`tests/test_io_wait_analysis.sh`, `tests/test_no_storage_root_cause_without_external_evidence.sh`, `tests/test_log_file_sync_vs_parallel_write_correlation.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca confirma problema de storage sin evidencia OS/storage externa. |
