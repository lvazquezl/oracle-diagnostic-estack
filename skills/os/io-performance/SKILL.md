---
name: io-performance
id: os/io-performance
version: 1.0.0
domain: os
status: active
---

# Purpose

Recolecta evidencia de latencia/IOPS/throughput/queue depth/utilización a nivel dispositivo —
nunca concluye storage root cause con `util%` aislado.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`iostat`/`vmstat` awareness vía collector): `SUPPORTED`. Solaris (`iostat -xn`):
`SUPPORTED`. Windows (contadores de rendimiento de disco): `PARTIALLY_SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/block-devices` ya ejecutado.

# Required evidence

- evidencia de `os/block-devices` + métricas de I/O del collector correspondiente

# Optional evidence

Ninguna.

# Read-only operations

Lectura de contadores de I/O vía collector semántico.

# Forbidden operations

Ninguna capacidad de cambio.

# Decision logic

1. Reportar `latency`, `iops`, `throughput`, `queue_depth`, `utilization` por dispositivo
   relevante.
2. **`util%` alto aislado NO es suficiente para concluir cuello de botella de storage** (`# 34`
   del prompt: "No concluir storage root cause con util% aislado") — un dispositivo puede
   reportar `util%` alto con latencia baja (I/O secuencial eficiente). La conclusión requiere
   `latency`/`queue_depth` elevados correlacionados.
3. Correlacionar con `oracle-performance-analyst` (wait events de I/O) antes de atribuir
   degradación a storage — nunca una conclusión aislada de este skill.

# Normal state

Latencia dentro de rangos esperados para el tipo de dispositivo (SSD vs. HDD, local vs. SAN),
sin cola sostenida.

# Abnormal patterns

Latencia elevada sostenida + cola alta, correlacionado con wait events de I/O Oracle reportados.

# False positives

`util%` alto con latencia baja — I/O eficiente, no un cuello de botella real.

# Correlation rules

Alimenta `os/block-devices`, `os/multipath-awareness`, `oracle-performance-analyst`,
`oracle-asm-storage-analyst`.

# Confidence model

`OBSERVATION` para métricas aisladas. `PROBABLE_CAUSE` sólo con correlación multi-métrica +
wait events Oracle.

# Severity

`HIGH` sólo con evidencia combinada (latencia + cola + wait events); nunca por `util%` aislado.

# Output schema

```yaml
io_performance:
  - device: string   # TOKENIZE
    latency_ms: number|null
    iops: number|null
    throughput_mbps: number|null
    queue_depth: number|null
    utilization_pct: number|null
findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/block-devices`, `os/multipath-awareness`, `os/aio`.

# Escalation

Evidencia combinada de degradación escala a `oracle-performance-analyst`/`oracle-asm-storage-analyst`.

# Manual remediation guidance

`manual_action` sugiere investigación adicional de storage — siempre `NOT_EXECUTED`.

# Security

Nombres de dispositivo → `TOKENIZE`.

# Tests

`tests/test_io_performance_awareness.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
