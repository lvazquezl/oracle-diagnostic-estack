---
name: change-correlation
id: incident/change-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con cambios conocidos (patching, deployment, parameter change, OS
change, network change, storage change, VM resize, capacity change — `# 527`-`# 542` del prompt
de Fase 11) — nunca asume causalidad sólo por proximidad temporal.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/timeline` ejecutado; `known_changes` del intake disponible.

# Required evidence

- `known_changes` del bloque `incident:` y/o eventos `CONFIG_CHANGE`/`CAPACITY_EVENT` del timeline.

# Optional evidence

- `incident.change_correlation.before_minutes`/`after_minutes` del Target Profile.

# Read-only operations

Cálculo local (ventana de correlación temporal).

# Forbidden operations

Nunca declara `CHANGE_CAUSED` sin evidencia causal directa — proximidad temporal sola produce
como máximo `CHANGE_CORRELATED` (`# 1624`-`# 1638` del prompt).

## Change correlation window

Ventana configurable (`docs/TARGET_PROFILE.md#schema`, bloque `incident.change_correlation`):

```yaml
incident:
  change_correlation:
    before_minutes:
    after_minutes:
```

Nunca hardcodeada — sin declaración explícita, el skill reporta `NO_CORRELATION` por defecto
(no asume una ventana universal).

# Decision logic

1. Para cada cambio conocido, verificar si cae dentro de la ventana de correlación configurada
   respecto al inicio del incidente.
2. Un cambio dentro de la ventana → `CHANGE_CORRELATED`. Nunca se promueve a `CHANGE_CAUSED` sin
   evidencia causal directa adicional (mecanismo + evidencia de soporte, ver
   `incident/root-cause#correlation-is-not-causation`).
3. `CHANGE_CAUSED` sólo cuando `incident/hypothesis-testing` confirma la hipótesis correspondiente
   con el rigor completo del Root Cause Model.

# Normal state

Cambios conocidos clasificados como `CHANGE_CORRELATED`/`NO_CORRELATION`, con `CHANGE_CAUSED`
reservado para casos con evidencia causal confirmada.

# Abnormal patterns

Múltiples cambios en la ventana de correlación — todos reportados, nunca se elige arbitrariamente
uno como "el más probable" sin evidencia diferencial.

# False positives

Declarar que un cambio "causó" el incidente únicamente porque ocurrió minutos antes es exactamente
el falso positivo que este skill (y `test_change_correlation_not_causation.sh`) previenen.

# Correlation rules

Consume `incident/timeline`, `incident/intake`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`.

# Confidence model

`FACT` para la correlación temporal en sí (cae o no dentro de la ventana); la causalidad es
responsabilidad exclusiva de `incident/root-cause`.

# Severity

N/A directa.

# Output schema

```yaml
change_correlation:
  - change_summary: string
    change_timestamp: string
    window_minutes_before: int
    window_minutes_after: int
    status: CHANGE_CORRELATED|CHANGE_CAUSED|NO_CORRELATION
    evidence_ids: [EVD-...]
```

# Related skills

`incident/timeline`, `incident/hypothesis-generation`, `incident/root-cause`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_change_correlation.sh`, `tests/test_change_correlation_not_causation.sh`.

# Documentation requirements

Alimenta `incident-timeline.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
