---
name: manual-remediation-plan
id: incident/manual-remediation-plan
version: 1.0.0
domain: incident
status: active
---

# Purpose

Produce un plan de remediación **manual, de ejecución humana**, incluso para acciones urgentes
(`# 1054`-`# 1072` del prompt de Fase 11: restart listener, relocate service, kill session,
failover, extend filesystem) — cada acción siempre `execution_status: NOT_EXECUTED`, nunca
ejecutada por el agente.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/root-cause` (o al menos `incident/hypothesis-testing`) ejecutado — el plan de
remediación se basa en la causa (confirmada o probable) identificada, nunca en una acción
genérica desconectada del análisis.

# Required evidence

- `root_cause`/`hypotheses` con `completeness` y `confidence` explícitos.

# Optional evidence

- Referencias a `change-advisor` (Foundation) si la recomendación implica un cambio formal.

# Read-only operations

Redacción de texto/procedimiento únicamente.

# Forbidden operations

**NUNCA ejecuta ninguna acción**, ni siquiera en escenarios etiquetados "emergencia" — reinicio
de listener/instancia, relocación de servicio, `ALTER SYSTEM KILL SESSION`, kill de proceso OS,
failover/switchover, extensión de filesystem, cambio de parámetro, cambio de storage/red/
seguridad, ejecución de RMAN. Cada acción se presenta exclusivamente como
"MANUAL AUTHORIZED ACTION" para que el DBA la ejecute (`# 1057`-`# 1072` del prompt,
no-negociable — mismo principio que `change-advisor` mantiene en Foundation).

# Decision logic

1. Cada acción recomendada se vincula explícitamente al `root_cause`/`hypothesis` que atiende —
   nunca una acción huérfana sin justificación causal trazable.
2. Cada acción se clasifica según su naturaleza (`MITIGATION|TEMPORARY_FIX|PERMANENT_FIX|
   WORKAROUND`, ver `incident/recovery-status`) para que el DBA entienda si resuelve el síntoma o
   la causa.
3. Acciones que requieren downtime o afectan disponibilidad se marcan explícitamente con su
   impacto esperado, nunca minimizado.
4. Toda acción se presenta con: comando/procedimiento textual, pre-requisitos, riesgo, rollback
   si aplica, y `execution_status: NOT_EXECUTED` — igual que el patrón ya establecido por
   `change-advisor`.

# Normal state

Plan de remediación completo, con trazabilidad a la causa, y ninguna acción ejecutada.

# Abnormal patterns

N/A — este skill nunca observa estado del sistema, sólo produce texto.

# False positives

N/A directo — el riesgo que este skill previene es la ejecución no autorizada, no un falso
positivo de diagnóstico.

# Correlation rules

Consume `incident/root-cause`, `incident/recovery-status`, `incident/contributing-factors`.
Alimenta `incident/incident-report`, `incident/rca-report`, `change-advisor` (Foundation, para
formalización de cambio si el DBA lo decide).

# Confidence model

Hereda el `confidence`/`completeness` del `root_cause`/hipótesis que justifica cada acción — una
acción basada en una causa `PROBABLE` (no `CONFIRMED`) se etiqueta explícitamente como tal.

# Severity

N/A directa — la severidad del incidente ya fue determinada por `incident/severity-awareness`.

# Output schema

```yaml
manual_remediation_plan:
  - action_summary: string
    justification: string
    linked_to: RCA-...|HYP-...
    kind: MITIGATION|TEMPORARY_FIX|PERMANENT_FIX|WORKAROUND
    risk: string
    rollback: string|null
    execution_status: NOT_EXECUTED
```

# Related skills

`incident/root-cause`, `incident/recovery-status`, `incident/incident-report`.

# Escalation

N/A directa.

# Manual remediation guidance

Este skill ES la guía de remediación manual — no delega a otro skill.

# Security

Nunca incluye comandos con credenciales embebidas ni datos de negocio.

# Tests

Cubierto transversalmente por los 13 tests de safety (sección 99 del prompt): `test_no_session_kill.sh`,
`test_no_process_kill.sh`, `test_no_restart_execution.sh`, `test_no_failover_execution.sh`,
`test_no_switchover_execution.sh`, `test_no_parameter_change.sh`, `test_no_storage_change.sh`,
`test_no_network_change.sh`, `test_no_security_change.sh`, `test_no_rman_execution.sh`.

# Documentation requirements

Alimenta `incident-manual-actions.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
