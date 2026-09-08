---
name: troubleshooting
id: dataguard/troubleshooting
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Punto de entrada de `/diagnose` para los escenarios `dataguard`, `transport`, `apply`, `lag`, `gap`, `broker`, `fsfo`, `switchover-readiness`, `failover-readiness` (`# 48` del prompt de Fase 5) — enruta al skill correcto, no crea un comando slash por cada código ORA.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

Target Profile con `dataguard.enabled = true`.

# Required evidence

Ninguna propia.

# Optional evidence

- `Q-DG-ROLE-001` como contexto base.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna propia.

# Collector IDs

Ninguno propio.

# Read-only operations

Ninguna propia.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Clasificar el síntoma: réplica atrasada → `dataguard/lag`; MRP detenido → `dataguard/apply`; error de destino → `dataguard/transport`; gap → `dataguard/archive-gaps`; problema Broker → `dataguard/broker`; pregunta de readiness → `dataguard/switchover-readiness`/`dataguard/failover-readiness`.
2. Delegar al skill correcto — nunca reconstruye su lógica aquí.
3. No se crea un comando slash por cada código ORA/CRS individual — la taxonomía vive en `knowledge/errors/ora/`.

# Normal state

N/A — es un enrutador.

# Abnormal patterns

N/A propio.

# False positives

N/A propio.

# Correlation rules

Hereda la del skill al que enruta.

# Confidence model

Hereda el `confidence` del skill al que enruta.

# Severity

Hereda la del skill al que enruta.

# Output schema

```yaml
findings:
  - symptom: string
    routed_to: string
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/lag`, `dataguard/transport`, `dataguard/apply`, `dataguard/archive-gaps`, `dataguard/broker`, `dataguard/switchover-readiness`, `dataguard/failover-readiness`.

# Escalation

Síntoma correlacionable con múltiples dominios → `dataguard/incident-analysis`.

# Manual remediation guidance

Ninguna propia.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

N/A propio — el skill destino documenta.

# Change history

v1.0.0 — Fase 5, creación inicial.
