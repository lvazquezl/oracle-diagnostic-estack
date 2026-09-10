---
name: pdb-services
id: multitenant/pdb-services
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Analizar servicios asociados a cada PDB — nombre, instancias, CLB/RLB goal, y correlacionar con registro de red cuando aplique (`# 14` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-SERVICES-001` (`GV$SERVICES`/`GV$ACTIVE_SERVICES`)

# Optional evidence

Ninguna propia — delega a `oracle-network-analyst` para estado de registro real en el listener.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-SERVICES-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `GV$SERVICES`/`GV$ACTIVE_SERVICES`.

# Forbidden operations

No modifica servicios (`# 14`: no modificar servicios).

# Decision logic

1. Asociar cada servicio a su PDB vía `con_id`.
2. Verificar que el servicio esté activo en al menos una instancia esperada (`active_instance` no nulo).
3. Delegar a `oracle-network-analyst` sólo cuando se requiera confirmar registro real en el listener/SCAN — nunca diagnosticar red sin esa evidencia (`# 36`).

# Normal state

Cada servicio de PDB activo en las instancias esperadas por diseño.

# Abnormal patterns

Servicio sin instancia activa (`active_instance` nulo en todas las filas) — la PDB puede estar inaccesible vía ese servicio.

# False positives

Un servicio con afinidad intencional a un subconjunto de instancias no es un error.

# Correlation rules

Correlaciona con `multitenant/pdb-rac-placement` y `multitenant/pdb-state` — un servicio sin instancia activa puede deberse a que la PDB está `MOUNTED`, no a un problema de servicio en sí.

# Confidence model

`FACT` para el estado leído directamente.

# Severity

Servicio de PDB en producción sin instancia activa → `HIGH`.

# Output schema

```yaml
pdb_services:
  - pdb_token: string
    service: string
    instances: [string]|null
    clb_goal: string|null
    rlb_goal: string|null
    severity: LOW|MEDIUM|HIGH
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-rac-placement`, `multitenant/pdb-state`.

# Escalation

Servicio crítico sin instancia activa → `incident-root-cause-analyst`.

# Manual remediation guidance

Cambios de servicio se entregan vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`service`/`pdb_token` tokenizados.

# Tests

`tests/test_pdb_services.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
