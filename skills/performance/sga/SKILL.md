---
name: sga
display_name: "SGA"
id: performance/sga
version: 1.0.0
domain: performance
status: active
---

# Purpose

Evaluar tamaño y componentes de la SGA (`SGA_TARGET`/`SGA_MAX_SIZE`, buffer cache, shared pool, large pool, java pool, streams pool) sin recomendar aumentar memoria basándose únicamente en ratios simplistas.

# Scope

**En alcance:** tamaño total y por componente de la SGA, snapshot actual.
**Fuera de alcance:** cambio de parámetros de memoria (siempre recomendación manual), tuning de shared pool específico (`performance/shared-pool`), library cache específico (`performance/library-cache`).

# Supported Oracle versions

10g–23ai. `V$SGA`/`V$SGAINFO`/`V$SGASTAT` estables en todo el rango.

# Supported OS/platforms

Todas — HugePages/NUMA es evidencia OS, correlacionada vía `os-platform-analyst` cuando exista, no leída directamente aquí.

# Supported architectures

Standalone y RAC (cada instancia tiene su propia SGA). NON-CDB y CDB (SGA es de instancia, no de PDB). Primary y Standby (estructural — válido en ambos).

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-SGA-001`

# Optional evidence

- Evidencia de HugePages/RAM del host vía `os-platform-analyst` (routing, no evidencia propia)

# Data collection

Lectura de `V$SGA`, `V$SGAINFO`, `V$SGASTAT`.

# Diagnostic logic / Decision tree

```text
1. Leer sga_total_bytes, sga_max_bytes, sga_free_bytes, y componentes (shared_pool, buffer_cache, large_pool, java_pool).
2. NO aplicar la regla "buffer cache hit ratio < X → increase cache" sin evidencia adicional (# 22. SGA del prompt de Fase 3 lo prohíbe explícitamente).
3. Si sga_free_bytes es consistentemente bajo Y hay evidencia de over-allocation/errores de memoria compartida → HYPOTHESIS de subdimensionamiento, nunca recomendación directa de aumentar sin ese contexto.
4. Correlacionar con RAM del host (si os-platform-analyst lo provee) antes de recomendar cualquier cambio de SGA_MAX_SIZE.
```

# Normal behavior

`sga_free_bytes` con margen razonable, sin errores de asignación de memoria compartida reportados.

# Abnormal patterns

`sga_free_bytes` cercano a cero de forma sostenida; `shared_pool` con alta fragmentación (correlacionar con `performance/shared-pool`).

# Root cause patterns

Ninguno confirmado sin evidencia adicional de RAM del host y patrón de uso a lo largo del tiempo (`performance/trending`).

# Correlation rules

Nunca recomendar aumentar SGA basándose sólo en un ratio — requiere evidencia de contención real (errores, `performance/shared-pool` con reloads altos, `performance/library-cache` con invalidaciones altas).

# False positives

Un `buffer_cache` con hit ratio aparentemente bajo puede ser normal para un workload dominado por full scans legítimos (DSS/reporting) — no es automáticamente un problema.

# Confidence model

`FACT` para tamaños leídos directamente. `HYPOTHESIS` para cualquier sugerencia de redimensionamiento, siempre con evidencia adicional citada.

# Output schema

```yaml
findings:
  - sga_total_bytes: number
    sga_max_bytes: number
    sga_free_bytes: number
    shared_pool_bytes: number
    buffer_cache_bytes: number
    evidence_refs: [EVD-...]
```

# Related skills

`performance/pga`, `performance/memory`, `performance/shared-pool`, `performance/library-cache`.

# Escalation

Recomendación de redimensionar SGA → siempre manual (`current_value`, `evidence`, `workload_context`, `version`, `architecture`, `risk`, `expected_impact`, `rollback`), nunca ejecutado. Evidencia de host RAM insuficiente → `os-platform-analyst`.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

`tests/test_sga_version_awareness.sh`, `tests/test_no_hit_ratio_only_recommendation.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca recomienda memoria por ratio aislado. |
