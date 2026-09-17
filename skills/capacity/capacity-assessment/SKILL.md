---
name: capacity-assessment
id: capacity/capacity-assessment
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Orquesta `/assessment capacity` (y sus variantes `--period quarterly`/`--period semiannual`) —
evaluación integral más profunda que el healthcheck, cubriendo las 5 tecnologías y produciendo el
reporte completo (técnico + ejecutivo) con manifiesto de evidencia.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

Target Profile publicado.

# Required evidence

- Resultado completo de `capacity/capacity-healthcheck` para todos los recursos en scope.

# Optional evidence

- Assessment previo (para `capacity/executive-summary#change-detection`), cuando exista.

# Read-only operations

Orquestación local.

# Forbidden operations

Ninguna adicional a las heredadas.

# Decision logic

1. Salida mínima obligatoria (`# 1317`-`# 1345` del prompt de Fase 10): executive summary, scope,
   data sources, data quality, CPU capacity, memory capacity, storage capacity, horizontal
   capacity, vertical capacity, 1m/3m/6m forecast, threshold dates, top risks, recommendations,
   evidence manifest.
2. A diferencia de `/healthcheck capacity`, un assessment activa **todos** los recursos/skills
   aplicables según la topología detectada, no sólo bajo demanda — mismo criterio que
   `workflows/assessment.md` general.
3. Modo `--period quarterly`/`--period semiannual` (`# 1926`-`# 1936` del prompt) determina la
   ventana de comparación para `capacity/executive-summary#change-detection` — nunca cambia la
   metodología de cálculo en sí, sólo la cadencia/ventana de reporting.
4. Reconciliación de fuentes múltiples (ver `capacity/data-source-inventory`) cuando la misma
   métrica exista en más de una fuente — `preferred source`/`secondary source`/`reconciliation
   rule` declarados; conflicto fuera de tolerancia → `SOURCE_CONFLICT` explícito, nunca
   promediado a ciegas (`# 1167`-`# 1206` del prompt).

# Normal state

Reporte completo generado con todos los recursos en scope cubiertos (`SUPPORTED`/
`PARTIALLY_SUPPORTED`/`NOT_APPLICABLE`/`NOT_AVAILABLE` explícitos, nunca omitidos en silencio).

# Abnormal patterns

Cualquier `SOURCE_CONFLICT` no resuelto; cualquier recurso `CRITICAL` en `capacity/risk-classification`.

# False positives

Ninguno propio.

# Correlation rules

Orquesta `capacity/capacity-healthcheck` para todos los recursos + `capacity/executive-summary` +
reconciliación multi-fuente.

# Confidence model

Hereda de cada sub-componente — nunca colapsado en un único número.

# Severity

Heredada de `capacity/risk-classification` por recurso, consolidada en "Top Risks"
(`capacity/executive-summary`).

# Output schema

Ver `output-schema.yaml` del agente — `capacity_result` completo con `source_conflicts` poblado
cuando aplique.

# Related skills

Todos los skills `capacity/*`; especialmente `capacity/data-source-inventory`,
`capacity/executive-summary`.

# Escalation

Riesgos `HIGH`/`CRITICAL` consolidados escalan según `collaboration.yaml` del agente.

# Manual remediation guidance

Consolida `capacity/manual-capacity-plan` de todos los recursos — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles — hereda sanitización transversal.

# Tests

`tests/test_capacity_source_priority.sh`, `tests/test_capacity_source_conflict.sh`,
`tests/test_capacity_no_blind_average.sh`, `tests/test_capacity_source_reconciliation.sh`.

# Documentation requirements

Produce el reporte técnico completo (ver `docs/CAPACITY_REPORTING_MODEL.md`) y alimenta
`capacity-summary.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
