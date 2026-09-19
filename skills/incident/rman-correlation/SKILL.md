---
name: rman-correlation
id: incident/rman-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-backup-recovery-analyst` (Fase 6/7) — channel
exhaustion, SBT media manager failures, FRA pressure, backup job failures, snapshot controlfile
issues — por referencia (`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-backup-recovery-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` incluye `oracle-backup-recovery-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-backup-recovery-analyst`: RMAN job status/errors, channel
  allocation failures, FRA usage, SBT connectivity status.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca ejecuta RMAN directamente — ni siquiera comandos de sólo lectura interactivos. Nunca
recomienda ni ejecuta un backup/restore/recover.

# Decision logic

1. Alinear fallos de backup/RMAN contra el timeline del incidente.
2. Un fallo de canal RMAN coincidente con presión de FRA es evidencia de soporte para una cadena
   causal (FRA pressure → backup failure → space not reclaimed → further FRA pressure), cada
   eslabón con su propia evidencia.
3. Un fallo de backup en sí mismo generalmente NO es la causa de una interrupción de servicio de
   aplicación — se reporta como hallazgo relacionado/contributing factor salvo evidencia directa
   de que consumió recursos compartidos críticos (ej. FRA lleno bloqueando archivelog).

# Normal state

Evidencia de backup/RMAN correlacionada temporalmente.

# Abnormal patterns

FRA en agotamiento sostenido con archivelog destination bloqueado — contributing factor fuerte
para incidentes de "database hang"/"archiver stuck".

# False positives

Atribuir un incidente de servicio de aplicación a "el backup falló anoche" sin evidencia de que
ese fallo específico consumió un recurso compartido crítico es el falso positivo que este skill
evita.

# Correlation rules

Consume evidencia de `oracle-backup-recovery-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/playbooks` (RMAN/FRA playbooks).

# Confidence model

`FACT` para eventos observados directamente.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/asm-storage-correlation`, `incident/hypothesis-generation`, `incident/playbooks`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-backup-recovery-analyst` — siempre
`NOT_EXECUTED`. Nunca ejecuta RMAN bajo ninguna circunstancia (`NO RMAN EXECUTION`, non-negotiable
del prompt).

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_rman_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
