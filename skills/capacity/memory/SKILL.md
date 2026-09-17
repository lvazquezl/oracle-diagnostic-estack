---
name: memory
id: capacity/memory
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza capacidad de memoria — física/asignada, usada, disponible, working-set equivalente cuando
aplique, awareness de presión de swap/pagefile, contexto SGA/PGA de Oracle, asignación de memoria
de VM. Reutiliza por referencia la evidencia de `os-platform-analyst` (`os/memory`, `os/swap`,
Fase 9) y de `oracle-performance-analyst` (SGA/PGA) — nunca duplica collectors. **Nunca trata el
page cache de Linux como consumo irreclamable.**

# Supported Oracle versions

N/A directo para el contexto OS; SGA/PGA hereda el alcance de `oracle-performance-analyst`.

# Supported OS/platforms

Linux/Windows Server (vía `os-platform-analyst`): `SUPPORTED`/`PARTIALLY_SUPPORTED` según Fase 9.
VMware (asignación de memoria de VM): `PARTIALLY_SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`capacity/normalization` ejecutado; evidencia de memoria de `os-platform-analyst` disponible por
referencia.

# Required evidence

- `evidence_refs` de `os/memory` (Fase 9) por nodo.

# Optional evidence

- `evidence_refs` de `os/swap` (presión de swap), SGA/PGA de `oracle-performance-analyst`,
  asignación de memoria VMware cuando disponible.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca agrega memoria a un host/VM, nunca cambia configuración de SGA/PGA.

# Decision logic

1. Reportar `physical/allocated memory`, `used memory`, `available memory`, `working-set
   equivalent` cuando aplique, awareness de presión de `swap`/`pagefile`, contexto `SGA`/`PGA` de
   Oracle, y `VM memory allocation` cuando la fuente lo provea (`# 428`-`# 443` del prompt).
2. **El page cache de Linux nunca se trata como memoria consumida/irreclamable** — se reporta
   como parte de `available memory` (reclamable bajo presión), consistente con `os/memory`
   (Fase 9), nunca inflando `used memory` artificialmente.
3. Distinguir `allocated capacity growth` (crecimiento de la asignación configurada) de `working
   usage trend` (tendencia de uso real) y de `Oracle configured memory growth` (SGA/PGA
   configurados) — nunca extrapolar memoria de cache sin sentido (ver
   `capacity/threshold-crossing#memory-forecast-semantics`).

# Normal state

`used memory` (excluyendo cache reclamable) con margen suficiente sobre `allocated`; swap/pagefile
sin presión sostenida.

# Abnormal patterns

`used memory` sostenidamente alto con `swap`/`pagefile` en uso creciente — correlacionado con
`os/memory-pressure` (Fase 9), nunca declarado incidente sólo por `swap used > 0`.

# False positives

Alto uso de page cache reportado como "memoria agotada" es el falso positivo que este skill evita
explícitamente — nunca se repite.

# Correlation rules

Alimenta `capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing`,
`capacity/risk-classification`.

# Confidence model

`FACT` para valores leídos/agregados de evidencia ya certificada.

# Severity

`HIGH` si `used memory` (excluyendo cache) sostenidamente > 90% de `allocated` con presión de
swap/pagefile creciente; `MEDIUM`/`LOW` con más margen.

# Output schema

```yaml
memory_capacity:
  physical_allocated: number|null
  used: number|null
  available: number|null
  working_set_equivalent: number|null
  swap_pagefile_pressure: string|null
  sga_pga_context: {sga_bytes: number|null, pga_bytes: number|null}|null
  vm_allocation: number|null
  unit: bytes|GiB
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing`, `capacity/os`,
`capacity/oracle`.

# Escalation

Presión sostenida de swap/pagefile con `used memory` alto escala a
`capacity/risk-classification`/`capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` sugiere considerar vertical (más memoria) u horizontal — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_memory_current.sh`, `tests/test_capacity_memory_trend.sh`,
`tests/test_capacity_memory_forecast.sh`, `tests/test_linux_cache_not_treated_as_unavailable.sh`.

# Documentation requirements

Alimenta `capacity-memory.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
