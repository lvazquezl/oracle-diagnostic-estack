---
name: memory-pressure
id: os/memory-pressure
version: 1.0.0
domain: os
status: active
---

# Purpose

Consolida `os/memory` + `os/swap` (+ `os/cgroups` cuando aplique) en un único juicio de presión
de memoria del host — evita que cada skill individual emita un hallazgo contradictorio o
redundante.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`vmstat`, PSI cuando disponible vía `/proc/pressure/memory`): `SUPPORTED`. Solaris:
`SUPPORTED` (métricas equivalentes vía `kstat`). Windows: `SUPPORTED` (contadores de rendimiento
equivalentes).

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/memory` y `os/swap` ya ejecutados.

# Required evidence

- evidencia de `os/memory` y `os/swap`

# Optional evidence

- `/proc/pressure/memory` (PSI, Linux moderno) cuando disponible

# Read-only operations

Ninguna adicional — consolida evidencia ya recolectada.

# Forbidden operations

Ninguna capacidad de cambio.

# Decision logic

1. Combinar memoria disponible, actividad de swap/paging sostenida y (si disponible) PSI en un
   único estado `HEALTHY|WARNING|DEGRADED|CRITICAL`.
2. `CRITICAL` requiere evidencia combinada (memoria disponible baja + paging sostenido +
   degradación Oracle reportada) — nunca una sola métrica aislada.
3. cgroups con `memory.max` restrictivo (contenedor/cgroup v2) se correlaciona aquí, nunca
   confundido con presión de memoria a nivel de host completo.

# Normal state

Memoria disponible estable, sin actividad de paging sostenida, sin señales PSI elevadas.

# Abnormal patterns

Combinación de memoria disponible baja + paging sostenido + (si aplica) PSI elevado.

# False positives

Un solo indicador aislado (ej. `cache` alto, `swap_used > 0` estático) nunca produce `WARNING`+
por sí solo.

# Correlation rules

Consolida `os/memory`, `os/swap`, `os/cgroups`. Alimenta `os/platform-healthcheck`.

# Confidence model

`PROBABLE_CAUSE` cuando múltiples señales coinciden temporalmente con degradación Oracle
reportada; `OBSERVATION` en ausencia de esa correlación.

# Severity

`CRITICAL` sólo con evidencia combinada fuerte; de lo contrario `WARNING`/`LOW`.

# Output schema

```yaml
memory_pressure:
  state: HEALTHY|WARNING|DEGRADED|CRITICAL
  contributing_factors: [string]
  confidence: string
  evidence_refs: [EVD-...]
```

# Related skills

`os/memory`, `os/swap`, `os/cgroups`.

# Escalation

`CRITICAL`/`DEGRADED` escala a `oracle-performance-analyst` con evidence_refs.

# Manual remediation guidance

`manual_action` agrega recomendaciones de `os/memory`/`os/hugepages`/`os/cgroups` según el factor
contribuyente — `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_memory_pressure.sh`.

# Documentation requirements

Alimenta `memory-swap.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
