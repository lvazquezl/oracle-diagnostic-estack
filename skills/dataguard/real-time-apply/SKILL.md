---
name: real-time-apply
id: dataguard/real-time-apply
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Detectar si real-time apply está activo cuando la versión/arquitectura lo soporte, distinguiendo archived-log apply de real-time apply — nunca asume que una standby está defectuosa sólo porque no use real-time apply si no es requisito del diseño (`# 19` del prompt de Fase 5).

# Supported Oracle versions

11g–23ai (real-time apply requiere SRL, maduro desde 11gR2).

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

`dataguard/apply` y `dataguard/standby-redo-logs` resueltos.

# Required evidence

- `Q-DG-MANAGED-PROCESS-001` (`RECOVERY_MODE` en `V$MANAGED_STANDBY` — `MANAGED REAL TIME APPLY` vs. `MANAGED`)

# Optional evidence

- `Q-DG-SRL-001` (para explicar por qué real-time apply no está activo, si SRL es insuficiente).

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-MANAGED-PROCESS-001`, `Q-DG-SRL-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$MANAGED_STANDBY`.

# Forbidden operations

No activa/desactiva real-time apply.

# Decision logic

1. Leer `RECOVERY_MODE` — `MANAGED REAL TIME APPLY` confirma real-time apply activo; `MANAGED` (sin real-time) indica archived-log apply.
2. Si real-time apply NO está activo, correlacionar con `dataguard/standby-redo-logs` — SRL insuficiente explica la ausencia; SRL suficiente sin real-time apply es una decisión de diseño válida (no un defecto) a menos que el requisito del ambiente lo exija explícitamente.

# Normal state

Real-time apply activo cuando SRL es suficiente y el diseño lo requiere; archived-log apply cuando es la configuración declarada.

# Abnormal patterns

SRL suficiente pero real-time apply inactivo sin explicación de diseño declarada.

# False positives

Ausencia de real-time apply en un ambiente donde nunca fue requisito (ej. standby de solo DR con RPO amplio) — no es un hallazgo si no hay evidencia de que se esperaba.

# Correlation rules

Cruza con `dataguard/standby-redo-logs` (causa de ausencia) y `dataguard/lag` (impacto en apply lag — real-time apply reduce el lag potencial).

# Confidence model

`FACT` para `RECOVERY_MODE` leído directamente. `HYPOTHESIS` para "ausencia es un defecto" sin evidencia de requisito de diseño.

# Severity

Ausencia sin explicación en un ambiente con RPO estricto declarado → `MEDIUM`; ausencia en un ambiente sin ese requisito → `INFO`.

# Output schema

```yaml
findings:
  - thread: number
    real_time_apply_active: bool
    recovery_mode: string
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/apply`, `dataguard/standby-redo-logs`.

# Escalation

Ninguna propia — delega la clasificación de causa raíz a `dataguard/standby-redo-logs`.

# Manual remediation guidance

Ninguna — real-time apply es consecuencia de SRL/configuración, no una acción directa.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_real_time_apply.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `apply-analysis.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
