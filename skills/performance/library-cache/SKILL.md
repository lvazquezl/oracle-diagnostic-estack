---
name: library-cache
display_name: "Library Cache"
id: performance/library-cache
version: 1.0.0
domain: performance
status: active
---

# Purpose

Evaluar reloads, invalidaciones y hit ratios de Library Cache por namespace — sin usar un ratio aislado como causa definitiva.

# Scope

**En alcance:** `V$LIBRARYCACHE` por namespace (`gets`/`gethits`/`pins`/`pinhits`/`reloads`/`invalidations`).
**Fuera de alcance:** shared pool total (`performance/shared-pool`), parsing (`performance/hard-parse`).

# Supported Oracle versions

10g–23ai. `V$LIBRARYCACHE` estable en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary y Standby (estructural).

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-LIBCACHE-001`

# Optional evidence

- `Q-PERF-HARDPARSE-001` (correlación)

# Data collection

Lectura de `V$LIBRARYCACHE`.

# Diagnostic logic / Decision tree

```text
1. Leer gets/gethits/pins/pinhits/reloads/invalidations por namespace.
2. reloads altos en el namespace SQL AREA → correlacionar con performance/hard-parse (memory pressure invalidando cursores).
3. invalidations altas → correlacionar con cambios de objeto (DDL, stats gathering) — no es necesariamente un problema si coincide con mantenimiento programado.
4. Nunca usar gethitratio/pinhitratio aislado como conclusión — correlacionar con reloads/invalidations reales.
```

# Normal behavior

`reloads`/`invalidations` bajos y estables, sin picos coincidentes con actividad de usuario.

# Abnormal patterns

`reloads` crecientes en el namespace `SQL AREA` sin DDL/stats gathering conocido — candidato de shared pool subdimensionado (→ `performance/shared-pool`).

# Root cause patterns

Ninguno confirmado sin correlación con `performance/shared-pool` (memoria libre) y `performance/hard-parse` (parse count).

# Correlation rules

Siempre correlacionar `reloads` con memoria libre de shared pool antes de concluir subdimensionamiento.

# False positives

`invalidations` altas coincidentes con una ventana de mantenimiento (gather stats, DDL programado) no son un problema de performance.

# Confidence model

`FACT` para los contadores leídos directamente. `HYPOTHESIS` para "shared pool subdimensionado" sólo con `performance/shared-pool` corroborando memoria libre baja.

# Output schema

```yaml
findings:
  - namespace: string
    reloads: number
    invalidations: number
    gethitratio: number
    pinhitratio: number
    evidence_refs: [EVD-...]
```

# Related skills

`performance/shared-pool`, `performance/hard-parse`, `performance/sga`.

# Escalation

Subdimensionamiento sospechado → recomendación manual de revisar `SHARED_POOL_SIZE`, nunca ejecutado.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

Sin test dedicado adicional — cubierto por `tests/test_query_cost_low.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca usa un ratio aislado como causa definitiva. |
