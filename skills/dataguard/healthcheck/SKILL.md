---
name: healthcheck
id: dataguard/healthcheck
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Orquestar `/healthcheck dataguard` (`# 46` del prompt de Fase 5): Target Profile → Role Discovery → Topology → Protection → Transport → Apply → Lag → Gaps → SRL → Broker/FSFO (si aplica) → Findings → Markdown, produciendo el Data Guard Health Model por dimensión.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

Target Profile con `dataguard.enabled = true`.

# Required evidence

Evidencia agregada de `dataguard/role`, `dataguard/topology`, `dataguard/protection`, `dataguard/transport`, `dataguard/apply`, `dataguard/lag`, `dataguard/archive-gaps`, `dataguard/standby-redo-logs`, `dataguard/broker` (si habilitado).

# Optional evidence

Ninguna adicional.

# Licensing requirements

Ninguno propio — hereda el de cada skill subordinado.

# Query IDs

Ninguna propia.

# Collector IDs

Ninguno propio.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Ejecutar la secuencia declarada en `# Purpose`, en orden.
2. Producir el Data Guard Health Model (`# 45`) por dimensión: `ROLE`, `TRANSPORT`, `APPLY`, `LAG`, `GAPS`, `BROKER`, `SRL`, `PROTECTION`, `FSFO`, `READINESS` — cada una `HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE`, nunca un score opaco único.
3. `NOT_APPLICABLE` para dimensiones que no aplican al ambiente (ej. `FSFO` cuando no está habilitado) — nunca se fuerza un estado sobre una dimensión inexistente.

# Normal state

Todas las dimensiones `HEALTHY` o `NOT_APPLICABLE`.

# Abnormal patterns

Cualquier dimensión `DEGRADED`/`CRITICAL`.

# False positives

Dimensión `WARNING` transitoria explicada por una ventana de mantenimiento conocida.

# Correlation rules

Hereda el `confidence`/`severity` de cada skill subordinado — el healthcheck no reclasifica, sólo agrega.

# Confidence model

Hereda el de cada skill subordinado.

# Severity

Cualquier dimensión `CRITICAL` eleva la severidad global del healthcheck.

# Output schema

```yaml
findings:
  - dimension: ROLE|TRANSPORT|APPLY|LAG|GAPS|BROKER|SRL|PROTECTION|FSFO|READINESS
    status: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE
    evidence_refs: [EVD-...]
```

# Related skills

Todos los skills `dataguard/*` de rol/transporte/apply/lag/gaps/SRL/Broker.

# Escalation

Cualquier dimensión `CRITICAL` → `incident-root-cause-analyst`.

# Manual remediation guidance

Ninguna propia — cada dimensión aporta la suya vía su skill subordinado.

# Security

Hereda la sensibilidad de cada dimensión.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el healthcheck en Markdown vía `technical-documentation-manager`.

# Change history

v1.0.0 — Fase 5, creación inicial.
