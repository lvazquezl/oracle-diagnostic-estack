---
name: vertical
id: capacity/vertical
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza y recomienda capacidad **vertical** — incrementar CPU, memoria, storage, asignación de
VM, techo de storage de base de datos — siempre como análisis/recomendación, nunca ejecuta el
cambio. Junto con `capacity/horizontal`, implementa el Horizontal vs. Vertical Decision Model.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`capacity/trend-analysis`, `capacity/forecasting` ejecutados para el recurso en cuestión.

# Required evidence

- `evidence_refs` de arquitectura actual y del forecast del recurso relevante.

# Optional evidence

- licensing awareness cuando disponible.

# Read-only operations

Cálculo/análisis local.

# Forbidden operations

Nunca incrementa CPU/memoria/storage/asignación de VM/techo de base de datos — sólo recomienda
(`# 628`-`# 641` del prompt de Fase 10).

# Horizontal vs. vertical decision model

No se recomienda horizontal/vertical sólo por porcentaje de utilización. Factores considerados:

```text
current topology
resource bottleneck
growth rate
platform limits
licensing impact
HA architecture
RAC architecture
virtualization
operational complexity
cost-awareness
```

Si la evidencia es insuficiente para evaluar estos factores → `INSUFFICIENT_EVIDENCE`, nunca una
recomendación forzada por defecto (`# 644`-`# 667` del prompt).

# Decision logic

1. Definir el análisis vertical para: `increase CPU`, `increase memory`, `increase storage`,
   `increase VM allocation`, `increase database storage ceiling` — siempre como recomendación
   textual, nunca acción.
2. Aplicar el mismo Horizontal vs. Vertical Decision Model que `capacity/horizontal` — ambos
   skills comparten la lista de factores, nunca declaran reglas distintas entre sí.
3. Vertical suele preferirse cuando el cuello de botella es específico de un solo nodo/instancia
   sin arquitectura HA/RAC que distribuya la carga, o cuando el licenciamiento hace horizontal
   más costoso — siempre declarado explícitamente en `rationale`, nunca implícito.

# Normal state

N/A — este skill sólo se activa cuando hay riesgo de capacidad que justifique la pregunta.

# Abnormal patterns

Forecast cruza threshold y el cuello de botella es específico de una sola instancia/nodo sin
distribución posible de carga — sugiere vertical sobre horizontal.

# False positives

Recomendar vertical únicamente porque el porcentaje de utilización es alto, sin considerar el
resto de factores, es el falso positivo que este skill evita explícitamente.

# Correlation rules

Alimenta `capacity/manual-capacity-plan`, `capacity/executive-summary`.

# Confidence model

Hereda `capacity/confidence`; `INSUFFICIENT_EVIDENCE` es un estado explícito de la recomendación.

# Severity

N/A directa.

# Output schema

```yaml
vertical_analysis:
  resource: string
  recommendation: VERTICAL|INSUFFICIENT_EVIDENCE
  rationale: string
  considered_factors: [current_topology, resource_bottleneck, growth_rate, platform_limits, licensing_impact, ha_architecture, rac_architecture, virtualization, operational_complexity, cost_awareness]
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/horizontal`, `capacity/manual-capacity-plan`, `capacity/executive-summary`.

# Escalation

Recomendación `VERTICAL` con forecast `HIGH`/`CRITICAL` escala a `capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` describe la recomendación vertical en detalle — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_vertical_analysis.sh`, `tests/test_capacity_no_scaling_execution.sh`,
`tests/test_capacity_insufficient_architecture_evidence.sh`.

# Documentation requirements

Alimenta `capacity-plan.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
