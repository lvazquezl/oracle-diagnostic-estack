---
name: protection
id: dataguard/protection
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Analizar `PROTECTION_MODE` (configurado: `MAXIMUM PROTECTION`/`MAXIMUM AVAILABILITY`/`MAXIMUM PERFORMANCE`) vs. `PROTECTION_LEVEL` (efectivo) — una diferencia entre ambos puede ser evidencia de degradación, pero nunca se afirma error automáticamente sin contexto transitorio (`# 32` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY. Aplica igual conceptualmente a LOGICAL_STANDBY.

# Prerequisites

`dataguard/role` resuelto.

# Required evidence

- `Q-DG-ROLE-001` (`V$DATABASE.PROTECTION_MODE`/`PROTECTION_LEVEL`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-ROLE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$DATABASE`.

# Forbidden operations

No cambia `PROTECTION_MODE`.

# Decision logic

1. Comparar `PROTECTION_MODE` (declarado) contra `PROTECTION_LEVEL` (efectivo).
2. Si difieren, correlacionar con `dataguard/transport` — una standby SYNC caída temporalmente degrada `PROTECTION_LEVEL` sin cambiar `PROTECTION_MODE`; si la caída es reciente (ventana corta), es transitorio, no necesariamente un error persistente.
3. `MAXIMUM PROTECTION`/`MAXIMUM AVAILABILITY` con `PROTECTION_LEVEL` degradado sostenido → correlación directa con riesgo de disponibilidad del primary (en `MAXIMUM PROTECTION`, el primary puede detenerse si no hay standby SYNC disponible).

# Normal state

`PROTECTION_MODE` == `PROTECTION_LEVEL`.

# Abnormal patterns

`PROTECTION_LEVEL` degradado sostenido (más de una ventana de observación) respecto a `PROTECTION_MODE`.

# False positives

Degradación momentánea durante un switch de log o reconexión transitoria de red — correlacionar duración antes de escalar.

# Correlation rules

Cruza con `dataguard/transport` (estado SYNC/ASYNC de cada destino) y `dataguard/switchover-readiness` (protección consistente es un prerequisito de readiness).

# Confidence model

`FACT` para ambos valores leídos directamente. `PROBABLE_CAUSE` para la causa de degradación cuando se correlaciona con `dataguard/transport`.

# Severity

Degradación sostenida en `MAXIMUM PROTECTION` → `HIGH` (riesgo de detención del primary); en `MAXIMUM PERFORMANCE` → `LOW` (comportamiento esperado, ASYNC no garantiza SYNC).

# Output schema

```yaml
findings:
  - protection_mode: string
    protection_level: string
    consistent: bool
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/role`, `dataguard/transport`, `dataguard/switchover-readiness`.

# Escalation

Degradación sostenida en `MAXIMUM PROTECTION`/`MAXIMUM AVAILABILITY` → `incident-root-cause-analyst`.

# Manual remediation guidance

Cambio de `PROTECTION_MODE` es siempre `manual_action` — nunca ejecutado (`# 36` boundary general, prohibición explícita en `manifest.yaml` del agente).

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_dataguard_role_query.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `dataguard-topology.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
