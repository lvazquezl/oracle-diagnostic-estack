---
name: horizontal
id: capacity/horizontal
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza y recomienda capacidad **horizontal** — agregar nodos, VMs, instancias, dispositivos de
storage, topología scale-out — siempre como análisis/recomendación, **nunca ejecuta scale-out**.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (RAC es el caso natural de "agregar nodos").

# Prerequisites

`capacity/trend-analysis`, `capacity/forecasting` ejecutados para el recurso en cuestión;
topología actual conocida (Target Profile).

# Required evidence

- `evidence_refs` de arquitectura actual (RAC node count, VM count, storage device count) y del
  forecast del recurso relevante.

# Optional evidence

- licensing awareness cuando disponible (ver `capacity/manual-capacity-plan`).

# Read-only operations

Cálculo/análisis local.

# Forbidden operations

Nunca agrega nodos/VMs/instancias/discos, nunca ejecuta scale-out de ningún tipo (`# 610`-`# 625`
del prompt de Fase 10).

# Decision logic

1. Definir el análisis horizontal para: `add nodes` (RAC), `add VMs`, `add instances`, `add
   storage devices`, `scale-out topology` — siempre como recomendación textual, nunca acción.
2. La decisión horizontal vs. vertical (ver `capacity/vertical#horizontal-vs-vertical-decision-
   model`) nunca se basa sólo en porcentaje de utilización — considera topología actual, cuello
   de botella específico, growth rate, límites de plataforma, impacto de licenciamiento,
   arquitectura HA/RAC, virtualización, complejidad operacional, cost-awareness (`# 644`-`# 667`
   del prompt).
3. Si la evidencia es insuficiente para fundamentar horizontal vs. vertical (ej. no se conoce la
   topología HA real, o el growth rate tiene confianza `INSUFFICIENT`) → `INSUFFICIENT_EVIDENCE`,
   nunca una recomendación forzada.

# Normal state

N/A — este skill sólo se activa cuando hay riesgo de capacidad que justifique la pregunta
horizontal/vertical.

# Abnormal patterns

Forecast cruza threshold dentro del horizonte y el cuello de botella específico (ej. CPU de un
solo nodo RAC saturado con headroom de cluster disponible en otros nodos) sugiere horizontal
sobre vertical.

# False positives

Recomendar horizontal únicamente porque la utilización actual es alta, sin considerar el resto de
factores, es el falso positivo que este skill evita explícitamente (`# 646` del prompt: "no
recomendar horizontal/vertical sólo por porcentaje").

# Correlation rules

Alimenta `capacity/manual-capacity-plan`, `capacity/executive-summary`.

# Confidence model

Hereda `capacity/confidence`; `INSUFFICIENT_EVIDENCE` es un estado explícito de la recomendación
misma, no sólo de su confianza.

# Severity

N/A directa — la severidad la determina `capacity/risk-classification` sobre el recurso, este
skill sólo recomienda la forma de escalar.

# Output schema

```yaml
horizontal_analysis:
  resource: string
  recommendation: HORIZONTAL|INSUFFICIENT_EVIDENCE
  rationale: string
  considered_factors: [current_topology, resource_bottleneck, growth_rate, platform_limits, licensing_impact, ha_architecture, rac_architecture, virtualization, operational_complexity, cost_awareness]
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/vertical`, `capacity/manual-capacity-plan`, `capacity/executive-summary`.

# Escalation

Recomendación `HORIZONTAL` con forecast `HIGH`/`CRITICAL` escala a
`capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` describe la recomendación horizontal en detalle — siempre `NOT_EXECUTED`, nunca
ejecuta el scale-out.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_horizontal_analysis.sh`, `tests/test_capacity_no_scaling_execution.sh`,
`tests/test_capacity_insufficient_architecture_evidence.sh`.

# Documentation requirements

Alimenta `capacity-plan.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
