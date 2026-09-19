---
name: os-correlation
id: incident/os-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `os-platform-analyst` (Fase 8) — memory pressure,
filesystem/inode exhaustion, process/PID limits, cgroup pressure, time-sync degradation, kernel
messages — por referencia (`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

N/A directo — dominio OS.

# Supported OS/platforms

Hereda el alcance soportado de `os-platform-analyst` (Linux, RHEL, SUSE, Solaris, AIX, Windows
Server, HP-UX).

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` incluye `os-platform-analyst` en el scope.

# Required evidence

- `evidence_refs` de `os-platform-analyst`: memory/swap pressure, filesystem/inode usage, ulimit/
  process-count pressure, cgroup PID pressure, NTP/chrony drift, kernel log entries.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a ejecutar comandos OS directamente. Nunca recomienda ni ejecuta cambios de
configuración OS.

# Decision logic

1. Alinear presión de recursos OS contra el timeline del incidente.
2. Time-sync degradation (NTP/chrony drift) se correlaciona explícitamente con
   `TIMELINE_CONFIDENCE_DEGRADED` (ver `incident/timeline`) — nunca silenciosamente ignorado ni
   "corregido".
3. Presión de memoria/filesystem/inodes en el host coincidente con el inicio del incidente es
   evidencia de soporte fuerte, sujeta igual a confirmación de mecanismo hacia el proceso Oracle
   específico afectado.

# Normal state

Evidencia OS correlacionada temporalmente, con degradación de confianza del timeline marcada
explícitamente cuando aplica.

# Abnormal patterns

Memoria/filesystem en agotamiento sostenido antes del primer síntoma reportado — contributing
factor candidato.

# False positives

Atribuir el incidente a "uso de memoria alto en el host" sin verificar que ese consumo afectó
específicamente al proceso/instancia Oracle en cuestión es el falso positivo que este skill evita.

# Correlation rules

Consume evidencia de `os-platform-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/timeline` (clock skew), `incident/playbooks` (memory pressure
playbook).

# Confidence model

`FACT` para métricas observadas directamente.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/timeline`, `incident/hypothesis-generation`, `incident/playbooks`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `os-platform-analyst` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_os_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
