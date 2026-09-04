---
name: pga
display_name: "PGA"
id: performance/pga
version: 1.0.0
domain: performance
status: active
---

# Purpose

Evaluar uso y over-allocation de PGA agregada (`PGA_AGGREGATE_TARGET`, `PGA_AGGREGATE_LIMIT` cuando aplique, workareas onepass/multipass) de forma version-aware.

# Scope

**En alcance:** uso agregado de PGA de instancia, over-allocation, workarea profile básico.
**Fuera de alcance:** ajuste de `PGA_AGGREGATE_TARGET`/`PGA_AGGREGATE_LIMIT` (siempre recomendación manual).

# Supported Oracle versions

10g–23ai. `V$PGASTAT` estable en todo el rango. `PGA_AGGREGATE_LIMIT` sólo existe desde 12.1 — en 10g/11g este campo se declara `NOT_APPLICABLE` explícitamente, nunca se asume su existencia (ver `compatibility/oracle-dictionary/views.yaml#V$PGASTAT`).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. Primary y Standby (estructural).

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado (para saber si `PGA_AGGREGATE_LIMIT` aplica según versión).

# Required evidence

- `Q-PERF-PGA-001`

# Optional evidence

Ninguna adicional para el uso base.

# Data collection

Lectura de `V$PGASTAT`. `PGA_AGGREGATE_LIMIT` se lee de `V$PARAMETER` sólo si `oracle_version >= 12.1`.

# Diagnostic logic / Decision tree

```text
1. Leer pga_aggregate_target, total_pga_inuse, total_pga_allocated, over_allocation_count, freeable_pga.
2. IF oracle_version >= 12.1: leer pga_aggregate_limit por separado; si oracle_version < 12.1, declarar NOT_APPLICABLE — nunca inventar un valor.
3. over_allocation_count > 0 de forma sostenida → HYPOTHESIS de PGA subdimensionada, correlacionar con workarea onepass/multipass si se solicita ese desglose (V$SQL_WORKAREA_HISTOGRAM, fuera de la query base).
4. Nunca recomendar aumentar PGA_AGGREGATE_TARGET sin evidencia de over-allocation sostenida.
```

# Normal behavior

`over_allocation_count` en cero o esporádico, `total_pga_inuse` con margen razonable respecto al target.

# Abnormal patterns

`over_allocation_count` creciendo de forma sostenida; alta proporción de multipass en workareas (evidencia de PGA insuficiente para operaciones de sort/hash).

# Root cause patterns

Ninguno confirmado sin `performance/trending` (tendencia de over-allocation en el tiempo) y contexto de workload.

# Correlation rules

Cruzar con `performance/temp` — over-allocation de PGA suele correlacionar con mayor uso de TEMP (spill de sort/hash a disco cuando la PGA no alcanza).

# False positives

Un `over_allocation_count` bajo y esporádico durante un pico transitorio de concurrencia no es un problema sostenido — requiere persistencia para escalar severidad.

# Confidence model

`FACT` para valores leídos directamente. `HYPOTHESIS` para "PGA subdimensionada" con `over_allocation_count` sostenido + correlación con `performance/temp`.

# Output schema

```yaml
findings:
  - pga_aggregate_target: number
    total_pga_inuse: number
    over_allocation_count: number
    pga_aggregate_limit: number|null   # null explícito si NOT_APPLICABLE (< 12.1)
    evidence_refs: [EVD-...]
```

# Related skills

`performance/sga`, `performance/memory`, `performance/temp`.

# Escalation

Recomendación de ajustar PGA → siempre manual, nunca ejecutado.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

`tests/test_pga_version_awareness.sh`, `tests/test_pga_limit_not_used_before_supported_version.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — PGA_AGGREGATE_LIMIT tratado como NOT_APPLICABLE explícito antes de 12.1, nunca asumido. |
