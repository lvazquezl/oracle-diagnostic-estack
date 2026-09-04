---
name: shared-pool
display_name: "Shared Pool"
id: performance/shared-pool
version: 1.0.0
domain: performance
status: active
---

# Purpose

Evaluar memoria libre del shared pool y dictionary cache (row cache) hit ratio, correlacionado con reloads/invalidaciones de library cache y parsing — sin usar ratios aislados como causa definitiva.

# Scope

**En alcance:** memoria libre/total del shared pool (`V$SGASTAT`), dictionary cache gets/getmisses (`V$ROWCACHE`).
**Fuera de alcance:** library cache específico (`performance/library-cache`), parsing (`performance/hard-parse`).

# Supported Oracle versions

10g–23ai. `V$SGASTAT`/`V$ROWCACHE` estables en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary y Standby (estructural).

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-SHAREDPOOL-001`

# Optional evidence

- `Q-PERF-LIBCACHE-001`, `Q-PERF-HARDPARSE-001` (correlación)

# Data collection

Lectura de `V$SGASTAT` (pool = 'shared pool') y `V$ROWCACHE`.

# Diagnostic logic / Decision tree

```text
1. Leer shared_pool_free_bytes, shared_pool_total_bytes, rowcache_hit_ratio.
2. free_pct = shared_pool_free_bytes / shared_pool_total_bytes.
3. IF free_pct muy bajo (memoria casi agotada) AND performance/library-cache reporta reloads altos → HYPOTHESIS: shared pool subdimensionado.
4. rowcache_hit_ratio bajo de forma aislada NO es un finding — correlacionar con memoria libre y actividad de DDL/creación de objetos reciente.
```

# Normal behavior

`free_pct` con margen razonable, `rowcache_hit_ratio` alto y estable.

# Abnormal patterns

`free_pct` cercano a cero de forma sostenida coincidente con `reloads` altos en `performance/library-cache`.

# Root cause patterns

Ninguno confirmado sin correlación cruzada con `performance/library-cache` y `performance/hard-parse`.

# Correlation rules

Nunca reportar `free_pct` bajo como finding aislado — requiere corroboración de `reloads`/`invalidations` altos en `performance/library-cache`.

# False positives

Un `free_pct` bajo inmediatamente después del arranque de la instancia (shared pool llenándose con el workload inicial) no es un problema — se requiere persistencia en estado estable.

# Confidence model

`FACT` para memoria/ratios leídos directamente. `HYPOTHESIS` sólo con corroboración de `performance/library-cache`.

# Output schema

```yaml
findings:
  - shared_pool_free_bytes: number
    shared_pool_total_bytes: number
    free_pct: number
    rowcache_hit_ratio: number
    evidence_refs: [EVD-...]
```

# Related skills

`performance/library-cache`, `performance/hard-parse`, `performance/sga`.

# Escalation

Recomendación de `SHARED_POOL_SIZE` → siempre manual con evidencia completa, nunca ejecutado.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

Sin test dedicado adicional — cubierto por `tests/test_query_cost_low.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca reporta memoria libre baja sin corroboración de library cache. |
