---
name: normalization
id: capacity/normalization
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Normaliza evidencia cruda de cualquier fuente al Common Metric Model (`capacity_metric`) antes de
cualquier cálculo — unidades consistentes (nunca mezcla GB decimal con GiB binario sin conversión
explícita), semántica de tiempo consistente (timezone/timestamp/sampling interval), y las
ecuaciones base de capacidad. Es el único lugar del dominio donde `available`/`utilization_percent`
se calculan — ningún otro skill los recalcula de forma distinta.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/data-source-inventory` ejecutado; evidencia cruda disponible desde al menos una fuente
`CONNECTED`/`AVAILABLE_OFFLINE`/`MANUAL_IMPORT`.

# Required evidence

- evidencia cruda de cualquier fuente certificada (Oracle/OS/externa) con su `source_id`.

# Optional evidence

Ninguna adicional.

# Read-only operations

Transformación local (Python/runtime) de evidencia ya recolectada — ninguna lectura adicional.

# Forbidden operations

Ninguna — normalización pura, nunca modifica la fuente ni el recurso.

# Common metric model

```yaml
capacity_metric:
  target_id: string
  technology: string
  resource_type: string
  metric_name: string
  timestamp: string
  total_capacity: number|null
  used_capacity: number|null
  available_capacity: number|null
  utilization_percent: number|null
  unit: string
  source_id: string
  evidence_id: string
  quality: GOOD|ACCEPTABLE|DEGRADED|INSUFFICIENT|INVALID
```

# Decision logic

1. Normalizar unidades antes de calcular — `CPU` en cores/percentage, `Memory` en bytes/GiB,
   `Storage` en bytes/GiB/TiB (`# 358`-`# 377` del prompt) — nunca mezclar GB decimal con GiB
   binario sin una conversión explícita y documentada.
2. `available_capacity = total_capacity - used_capacity`.
3. `utilization_percent = used_capacity / total_capacity * 100`.
4. Si `total_capacity <= 0` → resultado `INVALID_CAPACITY_INPUT`, nunca se divide silenciosamente
   ni se reporta `0%`/`null` sin esa señal explícita (`# 381`-`# 406` del prompt).
5. Normalizar `timezone`/`timestamp`/`sampling interval` de toda serie antes de cualquier
   agregación — nunca mezclar timestamps locales sin offset (`# 743`-`# 753` del prompt).

# Normal state

`capacity_metric` completo, unidades consistentes, `available_capacity`/`utilization_percent`
calculados sin error.

# Abnormal patterns

`INVALID_CAPACITY_INPUT` cuando `total_capacity <= 0`; unidades mezcladas detectadas sin
conversión (bloquea la normalización de ese punto, nunca continúa con un valor incorrecto).

# False positives

Ninguno conocido — la normalización es determinística sobre la evidencia de entrada.

# Correlation rules

Alimenta todos los skills de recurso (`capacity/cpu`, `capacity/memory`, `capacity/storage`,
`capacity/oracle`, `capacity/asm`, `capacity/tablespace`, `capacity/os`, `capacity/windows`,
`capacity/linux`, `capacity/sqlserver`, `capacity/vmware`) y `capacity/data-quality`.

# Confidence model

`FACT` para toda transformación determinística; `INVALID_CAPACITY_INPUT` es un estado explícito,
nunca un `null` silencioso.

# Severity

N/A directa — normalización no genera hallazgos de severidad, sólo datos limpios o
`INVALID_CAPACITY_INPUT` explícito.

# Output schema

Ver "Common metric model" arriba — éste es el esquema de salida.

# Related skills

Todos los skills de recurso; `capacity/data-quality`.

# Escalation

`INVALID_CAPACITY_INPUT` sostenido para un recurso escala como limitación en el reporte, nunca
bloquea el resto del assessment.

# Manual remediation guidance

N/A directa — un `total_capacity` inválido en la fuente es un problema de esa fuente/collector,
reportado, nunca corregido automáticamente.

# Security

Sin datos sensibles — sólo valores numéricos de capacidad.

# Tests

`tests/test_capacity_metric_normalization.sh`, `tests/test_capacity_unit_conversion.sh`,
`tests/test_capacity_gib_vs_gb.sh`, `tests/test_capacity_available_calculation.sh`,
`tests/test_capacity_invalid_total.sh`.

# Documentation requirements

Alimenta `capacity-summary.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
