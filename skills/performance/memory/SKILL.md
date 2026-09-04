---
name: memory
display_name: "Memory"
id: performance/memory
version: 1.0.0
domain: performance
status: active
---

# Purpose

Correlacionar SGA, PGA y (cuando exista) RAM/swap/HugePages/NUMA del host — sin realizar tuning OS profundo, sólo routing a `os-platform-analyst` cuando corresponde.

# Scope

**En alcance:** composición de `performance/sga` + `performance/pga`, correlación con evidencia OS opcional.
**Fuera de alcance:** tuning OS profundo (delegado a `os-platform-analyst`), ajuste de parámetros de memoria (siempre manual).

# Supported Oracle versions

10g–23ai (hereda de `performance/sga`/`performance/pga`).

# Supported OS/platforms

Todas — RAM/swap/HugePages/NUMA es evidencia opcional de `os-platform-analyst`, no recolectada directamente.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary y Standby.

# Licensing

Ninguna.

# Prerequisites

`performance/sga` y `performance/pga` ya ejecutados en la misma sesión.

# Required evidence

Ninguna propia — reutiliza `evidence_refs` de `performance/sga`/`performance/pga`.

# Optional evidence

Evidencia de RAM/swap/HugePages/NUMA vía `os-platform-analyst` (routing).

# Data collection

Ninguna propia.

# Diagnostic logic / Decision tree

```text
1. Componer SGA total + PGA aggregate target = memoria Oracle total estimada.
2. IF evidencia de RAM del host disponible: memoria Oracle total / RAM host → proporción informativa, no un umbral fijo.
3. IF swap activo Y evidencia de memory pressure del host → HYPOTHESIS de contención de memoria a nivel OS, routing a os-platform-analyst.
4. No profundizar en tuning OS — sólo señalar y rutear.
```

# Normal behavior

Memoria Oracle total dentro de un margen razonable de la RAM disponible del host, sin swap activo reportado.

# Abnormal patterns

Evidencia de swap activo coincidiendo con memoria Oracle cercana al límite de RAM del host.

# Root cause patterns

Ninguno confirmado por este skill — requiere `os-platform-analyst` para evidencia OS real.

# Correlation rules

Nunca concluir contención de memoria sin evidencia OS explícita cuando esté disponible; sin ella, declarar `INSUFFICIENT_EVIDENCE` para esa dimensión específica.

# False positives

Memoria Oracle alta respecto a RAM total no es un problema si no hay evidencia de swap/paginación activa.

# Confidence model

`FACT` para SGA/PGA compuestos. `HYPOTHESIS` sólo con evidencia OS correlacionada.

# Output schema

```yaml
findings:
  - oracle_memory_total_bytes: number
    host_ram_bytes: number|null
    swap_active: bool|null
    confidence: FACT|HYPOTHESIS
    evidence_refs: [EVD-...]
```

# Related skills

`performance/sga`, `performance/pga`, `performance/io`.

# Escalation

Evidencia OS requerida → `os-platform-analyst`.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

Cubierto por `tests/test_sga_version_awareness.sh`, `tests/test_pga_version_awareness.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — composición SGA+PGA con routing a os-platform-analyst, sin tuning OS propio. |
