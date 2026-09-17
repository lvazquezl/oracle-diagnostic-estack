---
name: manual-capacity-plan
id: capacity/manual-capacity-plan
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Redacta el Manual Action Contract de capacidad para cada recomendación (vertical u horizontal,
threshold crossing próximo) — texto para ejecución humana, **nunca** un cambio ejecutable.
Calcula `recommended_capacity` explicando el cálculo, nunca dimensionando sólo "hasta quedar por
debajo del threshold".

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/risk-classification`, y `capacity/horizontal`/`capacity/vertical` ejecutados para el
recurso.

# Required evidence

- `risk`, `threshold_crossing`, y la recomendación horizontal/vertical del recurso.

# Optional evidence

- `capacity.target_headroom_percent` del Target Profile, cuando declarado.

# Read-only operations

Redacción local de texto — ninguna acción ejecutable.

# Forbidden operations

Nunca resize VM, nunca agrega CPU/memoria, nunca extiende filesystem/ASM/tablespace, nunca crea
datafile, nunca modifica asignación VMware, nunca cambia parámetros de base de datos/OS resource
controls, nunca modifica herramientas de monitoreo (`# 227`-`# 241` del prompt de Fase 10).

# Manual Action Contract

```yaml
manual_action:
  action_id: string
  target: string
  resource: string
  reason: string
  forecast_horizon: 1|3|6|null
  trigger: string
  recommended_capacity: string|null
  owner_role: string
  prechecks: [string]
  risk: string
  rollback_or_contingency: string
  execution_status: NOT_EXECUTED
```

`execution_status: NOT_EXECUTED` es un campo fijo, nunca condicional (`# 1831`-`# 1849` del
prompt).

# Decision logic

1. Cada recomendación de riesgo `WARNING`/`HIGH`/`CRITICAL` genera un `manual_action` con el
   contrato completo arriba.
2. `recommended_capacity` **nunca** se calcula únicamente como "hasta quedar justo por debajo del
   threshold" — aplica `capacity.target_headroom_percent` (política configurable del Target
   Profile) y **explica el cálculo** explícitamente en `reason` (`# 1853`-`# 1864` del prompt).
3. Licensing/cost awareness (Oracle licensing, VMware licensing, cloud/infra cost) aparece como
   `REQUIRES_REVIEW` cuando no hay datos suficientes — **nunca se calculan costos inventados**
   (`# 1868`-`# 1886` del prompt).
4. `alert/watch integration`: puede sugerir futuros watches (threshold approaching, forecast
   changed materially, data source stale) como texto de recomendación — **nunca crea
   automatización runtime** dentro del e-stack (`# 1890`-`# 1902` del prompt).

# Normal state

Ninguna recomendación generada cuando el riesgo es `HEALTHY`/`WATCH`.

# Abnormal patterns

Riesgo `HIGH`/`CRITICAL` sin `manual_action` correspondiente sería un defecto — nunca debería
ocurrir.

# False positives

Recomendar exactamente "hasta el threshold" sin headroom adicional, ignorando la política
`target_headroom_percent`, es el patrón que este skill evita explícitamente.

# Correlation rules

Consume `capacity/risk-classification`, `capacity/horizontal`, `capacity/vertical`. Alimenta
`capacity/executive-summary`, `change-advisor` (vía `collaboration.yaml` del agente).

# Confidence model

Hereda la `confidence` del riesgo/forecast subyacente — declarada explícitamente en `reason`.

# Severity

Heredada de `capacity/risk-classification`.

# Output schema

Ver "Manual Action Contract" arriba.

# Related skills

`capacity/risk-classification`, `capacity/horizontal`, `capacity/vertical`,
`capacity/executive-summary`.

# Escalation

Toda recomendación con `risk: HIGH`/`CRITICAL` escala a `change-advisor` para propuesta de cambio
formal (`CHG-*`).

# Manual remediation guidance

Este skill ES la guía de remediación manual del dominio — `execution_status: NOT_EXECUTED`
siempre.

# Security

Sin datos sensibles; sin costos inventados.

# Tests

`tests/test_no_vm_resize.sh`, `tests/test_no_storage_extension.sh`, `tests/test_no_asm_add_disk.sh`,
`tests/test_no_tablespace_extend.sh`, `tests/test_no_monitoring_mutation.sh`.

# Documentation requirements

Alimenta `capacity-plan.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
