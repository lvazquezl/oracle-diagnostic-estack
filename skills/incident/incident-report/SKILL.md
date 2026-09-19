---
name: incident-report
id: incident/incident-report
version: 1.0.0
domain: incident
status: active
---

# Purpose

Genera el reporte de incidente en Markdown (`analysis/ANA-*`/`incident/INC-*`,
`# 1116`-`# 1130` del prompt de Fase 11) — intake, timeline, impacto, blast radius, hipótesis,
root cause (o `UNDETERMINED`), plan de remediación manual, estado de recuperación — nunca incluye
secretos/datos de negocio (`sanitizers/data-classification-policy.md`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

Todos los skills relevantes del incidente ejecutados (al menos intake, timeline, root-cause o
UNDETERMINED explícito, impact, manual-remediation-plan).

# Required evidence

- `incident_result` completo según `output-schema.yaml` del agente.

# Optional evidence

- `post_incident_review`/`lessons_learned` si el incidente ya se cerró.

# Read-only operations

Renderizado de Markdown local — vía `technical-documentation-manager` (Foundation), igual que
todo análisis del e-stack (`CLAUDE.md#documentación`).

# Forbidden operations

Nunca incluye passwords, hashes, wallet secrets, private keys, SQL text sensible completo, datos
de negocio, identificadores crudos de clientes (`# 63` del prompt).

# Decision logic

1. Ensamblar el reporte siguiendo el `incident_result` schema completo — cada sección con su
   trazabilidad de IDs (`INC-`→`EVD-`→`FND-`→`HYP-`→`RCA-`→`REC-`).
2. Si `root_cause.completeness == UNDETERMINED`, el reporte lo declara explícitamente como
   hallazgo legítimo — nunca fuerza una conclusión de causa para "completar" el reporte.
3. Registrar automáticamente en `analysis/ANA-YYYYMMDD-NNN/` con el identificador `INC-YYYYMMDD-NNN`
   correspondiente, consistente con la disciplina "ANALYZE ONCE, DOCUMENT MANY" de `CLAUDE.md`.

# Normal state

Reporte completo generado y registrado, con `UNDETERMINED` como resultado legítimo cuando
corresponde.

# Abnormal patterns

N/A directo.

# False positives

N/A directo.

# Correlation rules

Consume el `incident_result` completo. Es consumido por `incident/rca-report` (versión enfocada
en RCA) y por `change-advisor` (Foundation) para formalizar cambios aprobados.

# Confidence model

Refleja fielmente los `confidence`/`completeness` ya calculados por los skills previos — nunca
los re-calcula ni los suaviza.

# Severity

Refleja la `severity` ya determinada por `incident/severity-awareness`.

# Output schema

Ver `docs/INCIDENT_POSTMORTEM_MODEL.md` y `output-schema.yaml` del agente.

# Related skills

`incident/rca-report`, `incident/root-cause`, `incident/manual-remediation-plan`.

# Escalation

N/A directa.

# Manual remediation guidance

Incluye por referencia el `manual_remediation_plan` completo — siempre `NOT_EXECUTED`.

# Security

Hereda estrictamente `sanitizers/data-classification-policy.md` — KEEP/MASK/HASH/TOKENIZE/DROP
aplicado a cada campo antes de renderizar.

# Tests

`tests/test_incident_report_generation.sh`, `tests/test_incident_evidence_manifest.sh`.

# Documentation requirements

Este skill ES la generación de `incident-report.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
