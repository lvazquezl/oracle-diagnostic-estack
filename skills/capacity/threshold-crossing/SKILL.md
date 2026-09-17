---
name: threshold-crossing
id: capacity/threshold-crossing
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Calcula la fecha estimada en la que un recurso cruzará el threshold configurado (Target Profile),
y — cuando aplique — la fecha de agotamiento (saturation/exhaustion date) para recursos de
crecimiento acumulativo. Aplica semántica distinta por tipo de recurso: CPU es utilización, no
acumulativa; storage sí puede modelarse acumulativamente.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/forecasting` ejecutado para el recurso; threshold configurado en Target Profile
(`capacity.thresholds.<recurso>`) — nunca un umbral universal impuesto (`# 997`-`# 1014` del
prompt de Fase 10, aunque 80/90/95 pueden ofrecerse como ejemplo).

# Required evidence

- forecast ya calculado (`horizon_1m`/`horizon_3m`/`horizon_6m`) con su `confidence`.
- threshold configurado (`warning_percent`/`critical_percent`/`emergency_percent`).

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local.

# Forbidden operations

Ninguna.

# Decision logic

1. Estados de `threshold crossing`: `DATE_ESTIMATED` (fecha calculable dentro del horizonte
   soportado por la evidencia), `NOT_EXPECTED_WITHIN_HORIZON` (el forecast no cruza el threshold
   dentro de 6 meses), `ALREADY_EXCEEDED` (el estado actual ya está sobre el threshold),
   `INSUFFICIENT_EVIDENCE` (confidence del forecast es `INSUFFICIENT`), `NON_MONOTONIC` (la serie
   no tiene una tendencia monotónica clara que permita estimar un cruce único) (`# 1018`-`# 1035`
   del prompt).
2. Para recursos de crecimiento acumulativo (`disk`, `ASM`, `tablespace`, `FRA`), calcular
   adicionalmente `saturation_date` (fecha estimada de agotamiento total) cuando el forecast lo
   soporte — **nunca aplicado automáticamente a CPU** (`# 1038`-`# 1056` del prompt).

## CPU forecast semantics

CPU es utilización, no un recurso consumido acumulativamente. **Nunca** usar "días hasta agotar
CPU". Preferir `threshold crossing probability/date` (probabilidad/fecha de cruzar el umbral de
utilización sostenida) y `sustained utilization risk` (`# 1059`-`# 1074` del prompt).

## Memory forecast semantics

Distinguir `allocated capacity growth`, `working usage trend`, `Oracle configured memory growth`
— nunca extrapolar memoria de cache sin sentido (`# 1078`-`# 1088` del prompt, ver
`capacity/memory` para la disciplina anti-page-cache).

## Storage forecast semantics

Storage sí puede modelarse acumulativamente cuando `used capacity` crece sostenidamente en el
tiempo. Priorizar `growth rate`, `threshold crossing`, `exhaustion date` (`# 1092`-`# 1106` del
prompt).

# Normal state

`status: NOT_EXPECTED_WITHIN_HORIZON` con margen amplio, o `DATE_ESTIMATED` lejano con
`confidence: HIGH`/`MEDIUM`.

# Abnormal patterns

`ALREADY_EXCEEDED`; `DATE_ESTIMATED` dentro de 1-3 meses con `confidence` no `INSUFFICIENT`.

# False positives

Calcular "días hasta agotar CPU" tratando utilización como recurso acumulativo es el falso
positivo que este skill evita explícitamente — CPU nunca recibe `saturation_date`.

# Correlation rules

Consume `capacity/forecasting`. Alimenta `capacity/risk-classification`,
`capacity/manual-capacity-plan`, `capacity/executive-summary`.

# Confidence model

Hereda la `confidence` del forecast subyacente — nunca mejora artificialmente la confianza al
calcular la fecha de cruce.

# Severity

N/A directa — alimenta `capacity/risk-classification`, que sí asigna severidad/riesgo.

# Output schema

```yaml
threshold_crossing:
  resource: string
  threshold_percent: number
  status: DATE_ESTIMATED|NOT_EXPECTED_WITHIN_HORIZON|ALREADY_EXCEEDED|INSUFFICIENT_EVIDENCE|NON_MONOTONIC
  estimated_date: string|null
  saturation_date: string|null   # sólo para recursos acumulativos (disk/ASM/tablespace/FRA), nunca CPU
  confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/forecasting`, `capacity/risk-classification`, `capacity/manual-capacity-plan`.

# Escalation

`ALREADY_EXCEEDED` o `DATE_ESTIMATED` dentro del horizonte de 1 mes escala inmediatamente a
`capacity/risk-classification`/`capacity/manual-capacity-plan`.

# Manual remediation guidance

N/A directa — informa a `capacity/manual-capacity-plan`, nunca ejecuta.

# Security

Sin datos sensibles.

# Tests

`tests/test_threshold_already_exceeded.sh`, `tests/test_threshold_crossing_date.sh`,
`tests/test_threshold_not_expected.sh`, `tests/test_threshold_non_monotonic.sh`,
`tests/test_threshold_insufficient_evidence.sh`, `tests/test_cpu_no_exhaustion_semantics.sh`.

# Documentation requirements

Alimenta `capacity-thresholds.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.
