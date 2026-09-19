---
name: asm-storage-correlation
id: incident/asm-storage-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-asm-storage-analyst` (Fase 6) — diskgroup
space pressure, rebalance activity, disk failures, ASM instance health, I/O latency — por
referencia (`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-asm-storage-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Requiere ASM (gate heredado del agente).

# Prerequisites

`incident/scope-identification` incluye `oracle-asm-storage-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-asm-storage-analyst`: diskgroup free space, rebalance status, disk
  health, I/O latency percentiles.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a consultar V$ASM_* directamente. Nunca recomienda ni ejecuta resize/rebalance —
sólo diagnostica.

# Decision logic

1. Alinear presión de espacio/latencia I/O contra el timeline del incidente.
2. Una alerta de diskgroup por debajo del umbral crítico coincidente con el inicio del incidente
   es evidencia de soporte fuerte, sujeta igual a confirmación de mecanismo.
3. Un rebalance en curso durante el incidente se correlaciona como `change_correlation` (ver
   `incident/change-correlation`), nunca asumido causal automáticamente.

# Normal state

Evidencia de storage correlacionada temporalmente.

# Abnormal patterns

Latencia I/O elevada sostenida coincidente con el inicio de los síntomas — contributing factor
candidato.

# False positives

Atribuir el incidente a "espacio bajo en diskgroup" sólo por proximidad temporal sin verificar
que ese diskgroup específico soporta el objeto afectado, es el falso positivo que este skill
evita.

# Correlation rules

Consume evidencia de `oracle-asm-storage-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/playbooks` (FRA/storage playbooks).

# Confidence model

`FACT` para métricas observadas directamente.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/change-correlation`, `incident/hypothesis-generation`, `incident/playbooks`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-asm-storage-analyst` — siempre
`NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_asm_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
