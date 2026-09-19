---
name: rac-correlation
id: incident/rac-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-rac-analyst` (Fase 4) — node evictions,
interconnect degradation, SCAN listener health, service relocation, GRD/cache fusion pressure —
por referencia (`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-rac-analyst`.

# Supported OS/platforms

Todas las certificadas para RAC.

# Supported architectures

`rac`, `rac_one_node` únicamente — no aplica a `standalone` (gate heredado del agente).

# Prerequisites

`incident/scope-identification` incluye `oracle-rac-analyst` en el scope (arquitectura RAC
confirmada por discovery).

# Required evidence

- `evidence_refs` de `oracle-rac-analyst`: eviction events, interconnect metrics, SCAN/listener
  health, GRD statistics.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a consultar `crsctl`/vistas GV$ directamente — consume exclusivamente
`evidence_refs`. Nunca recomienda ni ejecuta relocación de servicio/failover.

# Decision logic

1. Alinear eventos de eviction/interconnect degradation contra el timeline del incidente.
2. Un patrón de causal_chain típico de RAC (ej. "network path instability → interconnect packet
   loss → cluster communication degradation → node eviction → service disruption", ejemplo
   textual del prompt `# 1560`-`# 1575`) requiere evidencia en cada eslabón — nunca se asume el
   eslabón intermedio sin evidencia directa.
3. Eviction NO implica automáticamente causa de red — puede deberse a I/O de voting
   disk/CPU starvation/OS scheduling; cada hipótesis alternativa se registra explícitamente.

# Normal state

Evidencia RAC correlacionada, cada eslabón del causal_chain propuesto con su propia evidencia.

# Abnormal patterns

Evicciones recurrentes del mismo nodo — señal fuerte para `incident/recurrence-awareness` y
posible contributing factor no resuelto.

# False positives

Asumir causa de red únicamente porque hubo una eviction, sin verificar métricas de interconnect
específicas, es el falso positivo que este skill evita.

# Correlation rules

Consume evidencia de `oracle-rac-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/playbooks` (RAC eviction playbook).

# Confidence model

`FACT` para eventos observados directamente; cada eslabón del causal_chain requiere su propia
evidencia para alcanzar `CONFIRMED_ROOT_CAUSE`.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/hypothesis-generation`, `incident/root-cause`, `incident/playbooks`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-rac-analyst` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_rac_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
