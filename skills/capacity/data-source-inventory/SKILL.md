---
name: data-source-inventory
id: capacity/data-source-inventory
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Enumera las fuentes de datos de capacidad conocidas — Site24x7, Prophecy, Reporting Services,
polling local, evidencia diagnóstica Oracle, evidencia OS Platform (Fase 9), telemetría VMware,
telemetría SQL Server — con su estado real, nunca asumiendo que todas están conectadas. Primer
paso obligatorio de `/healthcheck capacity`/`/assessment capacity` (`# 58`-`# 59` del prompt de
Fase 10).

# Supported Oracle versions

N/A directo — inventario de fuentes, agnóstico de versión.

# Supported OS/platforms

Todas — el inventario en sí no depende de plataforma.

# Supported architectures

Todas.

# Prerequisites

Target Profile ya publicado (bloque `capacity` cuando exista, incluyendo `source_priority`).

# Required evidence

Ninguna de collector — este skill consulta configuración/contratos de fuente declarados, nunca
credenciales ni datos crudos.

# Optional evidence

- Configuración de conectividad de cada fuente cuando el DBA la haya declarado explícitamente
  (nunca inventada).

# Read-only operations

Lectura de configuración de fuente declarada — nunca autenticación ni escritura hacia la
herramienta de monitoreo.

# Forbidden operations

Nunca configura, reconfigura ni escribe en Site24x7/Prophecy/Reporting Services/ninguna
herramienta de monitoreo — sólo lectura del estado de disponibilidad declarado.

# Source Adapter Contract

Cada fuente se modela con:

```yaml
source:
  source_id: string
  type: Site24x7|Prophecy|ReportingServices|LocalPolling|OracleEvidence|OSEvidence|VMwareTelemetry|SQLServerTelemetry
  scope: string
  technology: string
  metric_mapping: {string: string}
  timestamp_semantics: string
  sampling_interval: string
  timezone: string
  aggregation_level: string
  missing_data_behavior: string
  units: string
  validation_status: DOCUMENTATION_VALIDATED|FIXTURE_VALIDATED|LAB_VALIDATED|RUNTIME_VALIDATED
  read_only: true
```

Ningún adapter permite escribir ni reconfigurar la herramienta de monitoreo (`# 312`-`# 331` del
prompt de Fase 10) — `read_only: true` es un campo fijo, nunca condicional.

# Decision logic

1. Para cada fuente conocida, reportar `status`: `CONNECTED` (conectividad confirmada),
   `AVAILABLE_OFFLINE` (fuente existe pero sin conectividad activa en esta sesión),
   `MANUAL_IMPORT` (el DBA puede aportar datos exportados manualmente), `NOT_CONFIGURED` (fuente
   no declarada para este target), `NOT_CERTIFIED` (sin collector/adapter certificado en esta
   fase — ej. VMware/SQL Server en Fase 10 MVP).
2. Nunca asumir que una fuente está `CONNECTED` sin evidencia explícita de conectividad — el
   estado por defecto ante ausencia de declaración es `NOT_CONFIGURED`.
3. `OracleEvidence`/`OSEvidence` siempre disponibles como `CONNECTED` cuando el discovery/OS
   Platform ya se ejecutaron en la sesión — nunca re-declaradas `NOT_CONFIGURED` si ya hay
   evidencia certificada.

# Normal state

Al menos `OracleEvidence` y/o `OSEvidence` `CONNECTED`; fuentes externas declaradas con su estado
real.

# Abnormal patterns

Todas las fuentes `NOT_CONFIGURED`/`NOT_CERTIFIED` — el assessment continúa con
`PARTIAL_CAPACITY_ASSESSMENT` (`# 1407`-`# 1424` del prompt), nunca se bloquea completo.

# False positives

Ninguno conocido.

# Correlation rules

Alimenta `capacity/normalization`, `capacity/data-quality`, todos los skills de recurso
(`capacity/cpu`, `capacity/memory`, `capacity/storage`, etc.).

# Confidence model

`FACT` para el estado de cada fuente declarada.

# Severity

Informativo — no genera severidad propia; `PARTIAL_CAPACITY_ASSESSMENT` se reporta como
limitación, no como hallazgo de severidad.

# Output schema

```yaml
source_inventory:
  - source_id: string
    type: string
    scope: string
    technology: string
    status: CONNECTED|AVAILABLE_OFFLINE|MANUAL_IMPORT|NOT_CONFIGURED|NOT_CERTIFIED
    validation_status: string
    read_only: true
```

# Related skills

`capacity/data-quality`, `capacity/normalization`, `capacity/capacity-healthcheck`,
`capacity/capacity-assessment`.

# Escalation

Ninguna — es un paso de preparación, no genera hallazgos propios.

# Manual remediation guidance

N/A directa — conectar una fuente nueva es decisión/acción del DBA/equipo de monitoreo, nunca
ejecutada por este skill.

# Security

Ninguna credencial de fuente se almacena ni se envía al modelo — sólo el estado de disponibilidad.

# Tests

`tests/test_capacity_source_priority.sh`, `tests/test_capacity_read_only.sh`.

# Documentation requirements

Alimenta `capacity-summary.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
