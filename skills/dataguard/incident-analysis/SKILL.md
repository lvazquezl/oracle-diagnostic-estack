---
name: incident-analysis
id: dataguard/incident-analysis
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Punto de coordinación cuando `incident-root-cause-analyst` declara un incidente Data Guard activo (`# 44` del prompt de Fase 5) — comparte Evidence IDs con los dominios correlacionados (network/asm/rac/performance/os), nunca transcript completo.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

Target Profile con `dataguard.enabled = true`; contexto de incidente declarado por `incident-root-cause-analyst`.

# Required evidence

Ninguna propia — consolida evidencia ya recolectada por otros skills `dataguard/*`.

# Optional evidence

- `Q-DG-ROLE-001` como contexto base si aún no se recolectó en la sesión.

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

1. Recolectar `evidence_refs` ya generados por `dataguard/lag`, `dataguard/archive-gaps`, `dataguard/transport`, `dataguard/apply`, `dataguard/broker` relevantes al incidente.
2. Correlacionar con hipótesis de `incident-root-cause-analyst` — nunca reconstruye el análisis de causa raíz, sólo aporta el contexto Data Guard.
3. Compartir por referencia (`EVD-*`), nunca el transcript completo de la sesión (`# 44`).

# Normal state

N/A — se activa exclusivamente en contexto de incidente.

# Abnormal patterns

N/A propio — hereda el de los skills consolidados.

# False positives

N/A propio.

# Correlation rules

Coordina bidireccionalmente con `incident-root-cause-analyst` y, según el incidente, con `oracle-network-analyst`/`oracle-asm-storage-analyst`/`oracle-rac-analyst`/`oracle-performance-analyst`/`os-platform-analyst`.

# Confidence model

Hereda el de los skills consolidados.

# Severity

Hereda la del incidente declarado.

# Output schema

```yaml
findings:
  - incident_context: string
    consolidated_evidence_refs: [EVD-...]
    correlated_domains: [string]
```

# Related skills

`dataguard/lag`, `dataguard/archive-gaps`, `dataguard/failover-readiness`.

# Escalation

N/A — este skill es en sí un punto de escalación.

# Manual remediation guidance

Ninguna propia.

# Security

Evidence IDs compartidos nunca incluyen transcript completo ni secretos.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta el análisis de incidente coordinado por `incident-root-cause-analyst`.

# Change history

v1.0.0 — Fase 5, creación inicial.
