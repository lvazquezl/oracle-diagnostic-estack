---
name: manual-recovery-plan
id: rman/manual-recovery-plan
version: 1.0.0
domain: rman
status: active
---

# Purpose

Genera runbooks de recovery manuales (scope, scenario, assumptions, required evidence, prechecks, manual commands, expected state transitions, validation, rollback/fallback, postchecks, owner roles) — todo marcado `NOT_EXECUTED` (`# 32`, `# 33` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/recovery-readiness` resuelto (idealmente también `rman/pitr-readiness`/`rman/pdb-pitr-awareness` según el escenario).

# Required evidence

Toda la evidencia ya recolectada por los skills prerequisito — no ejecuta queries propias adicionales.

# Optional evidence

Contexto RAC/Data Guard/Multitenant cuando el escenario lo requiere.

# Licensing requirements

Ninguno.

# Query IDs

Ninguno propio — agrega evidence_refs ya producidos.

# Collector IDs

Ninguno propio.

# Read-only operations

Ninguna — es puramente generación de texto a partir de evidencia ya recolectada.

# Forbidden operations

Nunca ejecuta ningún comando del plan generado.

# Decision logic

1. `scope`/`scenario` explícitos (ej. "recovery completo de datafile X tras corrupción confirmada", "PDB PITR de PDB_TOKEN a las 14:00").
2. `assumptions` y `required_evidence` declaran exactamente qué se asumió y qué evidencia falta — nunca implícito.
3. `manual_commands` son texto RMAN/SQL literal para ejecución humana, con `prechecks` y `postchecks` explícitos — el plan completo se marca `execution_status: NOT_EXECUTED` siempre, sin excepción (`# 32`).
4. `rollback_fallback` obligatorio — todo plan de recovery declara qué hacer si el recovery falla a mitad de camino.

# Normal state

N/A — este skill sólo se invoca ante una necesidad real de recovery/restore, no forma parte de un healthcheck rutinario.

# Abnormal patterns

N/A.

# False positives

N/A.

# Correlation rules

Consume evidencia de `rman/restore-readiness`, `rman/recovery-readiness`, `rman/pitr-readiness`, `rman/pdb-pitr-awareness`, `rman/dataguard-awareness`, `rman/multitenant-awareness` según el escenario.

# Confidence model

El plan en sí no lleva `confidence` — se basa en la evidencia ya clasificada por los skills prerequisito.

# Severity

N/A — el plan documenta severidad del escenario que lo origina, no genera severidad propia.

# Output schema

```yaml
manual_recovery_plan:
  scope: string|null
  scenario: string|null
  assumptions: [string]
  required_evidence: [string]
  prechecks: [string]
  manual_commands: [string]
  expected_state_transitions: [string]
  validation: [string]
  rollback_fallback: string|null
  postchecks: [string]
  owner_roles: [string]
  execution_status: NOT_EXECUTED
```

# Related skills

`rman/restore-readiness`, `rman/recovery-readiness`, `rman/pitr-readiness`, `rman/pdb-pitr-awareness`.

# Escalation

Todo plan generado para un incidente activo se comparte con `incident-root-cause-analyst`; si el DBA aprueba, se delega a `change-advisor` para la propuesta formal.

# Manual remediation guidance

Es, en sí mismo, la guía de remediación manual — `execution_status: NOT_EXECUTED` siempre.

# Security

Ningún comando del plan se ejecuta; todo path/handle/nombre referenciado se mantiene sanitizado consistente con el resto del dominio.

# Tests

`tests/test_no_restore_execution.sh`, `tests/test_no_recover_execution.sh`, `tests/test_no_arbitrary_rman.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/recovery-readiness.md` y el `recommendations[].manual_action` del Result Package.

# Change history

v1.0.0 — Fase 7, creación inicial.
