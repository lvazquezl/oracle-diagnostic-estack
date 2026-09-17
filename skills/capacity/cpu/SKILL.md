---
name: cpu
id: capacity/cpu
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza capacidad de CPU — allocated, effective, used, peak, average, p95, y p99 cuando esté
justificado — nunca usa un único pico puntual como baseline de capacidad. Reutiliza por referencia
la evidencia CPU de `os-platform-analyst` (`os/cpu-topology`, Fase 9) y de VMware/SQL Server
cuando esas fuentes estén certificadas, nunca duplica collectors.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux/Windows Server (vía `os-platform-analyst`, Fase 9): `SUPPORTED`. VMware/SQL Server (vía
adapters propios): `PARTIALLY_SUPPORTED` en esta fase.

# Supported architectures

Standalone y RAC (agregado a nivel cluster cuando aplica).

# Prerequisites

`capacity/normalization` ejecutado; evidencia CPU de `os-platform-analyst`/VMware/SQL Server
disponible por referencia.

# Required evidence

- `evidence_refs` de `os/cpu-topology` (Fase 9) por nodo — nunca re-recolectada.

# Optional evidence

- evidencia VMware (`vCPU`/oversubscription) o SQL Server (CPU) cuando esas fuentes estén
  `CONNECTED`/`MANUAL_IMPORT`.

# Read-only operations

Cálculo local sobre evidencia ya recolectada por `os-platform-analyst` u otra fuente certificada.

# Forbidden operations

Nunca cambia CPU affinity, nunca agrega/quita vCPU, nunca modifica asignación de CPU en VMware.

# Decision logic

1. Reportar `allocated CPU` (cores asignados/disponibles), `effective CPU` (cores realmente
   utilizables, considerando oversubscription cuando aplique), `used CPU` (utilización actual),
   `peak CPU`, `average CPU`, `p95 CPU`, y `p99 CPU` cuando el volumen de muestras lo justifique
   (`# 410`-`# 425` del prompt de Fase 10).
2. **Nunca usar un único pico puntual como baseline de capacidad** — el baseline se calcula sobre
   `p95`/`average` de una ventana representativa, nunca sobre el valor máximo observado en un
   único muestreo.
3. CPU es utilización, no un recurso consumido acumulativamente — ver
   `capacity/threshold-crossing#cpu-forecast-semantics` para el modelo de forecast correcto (nunca
   "días hasta agotar CPU").

# Normal state

`used CPU`/`p95 CPU` con margen suficiente sobre `allocated`/`effective CPU`.

# Abnormal patterns

`p95 CPU` sostenidamente cerca de `effective CPU` — riesgo de saturación bajo picos de carga.

# False positives

Un pico puntual aislado de `used CPU` cerca del límite no es, por sí solo, un hallazgo — se
requiere `p95`/sostenimiento para elevarlo a riesgo.

# Correlation rules

Alimenta `capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing`,
`capacity/risk-classification`.

# Confidence model

`FACT` para valores leídos/agregados directamente de evidencia ya certificada.

# Severity

`HIGH` si `p95 CPU` > 90% de `effective CPU` sostenido; `MEDIUM`/`LOW` con más margen.

# Output schema

```yaml
cpu_capacity:
  allocated: number|null
  effective: number|null
  used: number|null
  peak: number|null
  average: number|null
  p95: number|null
  p99: number|null
  unit: cores|percentage
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing`, `capacity/os`,
`capacity/vmware`.

# Escalation

`p95 CPU` sostenido > 90% escala a `capacity/risk-classification`/`capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` sugiere considerar horizontal/vertical (ver `capacity/horizontal`/
`capacity/vertical`) — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles — sólo contadores de CPU.

# Tests

`tests/test_capacity_cpu_current.sh`, `tests/test_capacity_cpu_p95.sh`,
`tests/test_capacity_cpu_trend.sh`, `tests/test_capacity_cpu_threshold_forecast.sh`,
`tests/test_cpu_no_exhaustion_semantics.sh`.

# Documentation requirements

Alimenta `capacity-cpu.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
