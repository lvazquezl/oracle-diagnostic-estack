---
name: service-placement
id: rac/service-placement
version: 1.0.0
domain: rac
status: active
---

# Purpose

Modelar `preferred instances` vs. `available instances` vs. `current instances` de cada servicio, y detectar cuándo un servicio corre en una instancia distinta a la preferida (failover ya ocurrido).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/services` resuelto.

# Required evidence

- `Q-RAC-SERVICES-001` (`GV$SERVICES`, `GV$ACTIVE_SERVICES`)

# Optional evidence

- collector `get_service_configuration` (`srvctl config service`) para `preferred`/`available` declarados (no siempre expuestos por `GV$SERVICES` según versión).

# Read-only operations

Lectura de `GV$SERVICES`/`GV$ACTIVE_SERVICES` y salida estructurada de `srvctl config service`.

# Forbidden operations

No relocaliza el servicio a su instancia preferida ni modifica `preferred`/`available`.

# Decision logic

1. Comparar `current_instances` contra `preferred_instances`.
2. Si difieren, correlacionar con `rac/failover` (¿hubo un evento de failover reciente que lo explique?) antes de reportarlo como anomalía — un servicio corriendo en `available` en vez de `preferred` tras un failover válido es esperado, no un error.
3. Sin evidencia de failover que lo explique → `MEDIUM`, candidato a `change-advisor` (relocate manual).

# Confidence model

`FACT` para placement leído directamente. `PROBABLE_CAUSE` para "placement no preferido explicado por failover reciente" cuando ambas evidencias coinciden en ventana de tiempo.

# Output schema

```yaml
findings:
  - service_name: string
    preferred_instances: [string]
    available_instances: [string]
    current_instances: [string]
    matches_preferred: bool
    evidence_refs: [EVD-...]
```

# Related skills

`rac/services`, `rac/failover`, `rac/session-distribution`.

# Escalation

Placement no preferido sin explicación de failover → recomendación manual vía `change-advisor`.

# Data sensitivity

Media — `service_name` enmascarado.

# Context budget

Bajo.

# Tests

`tests/test_rac_service_placement.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `service-analysis.md`.

# Evolution via `/change`

Nuevas fuentes de `preferred`/`available` (ej. Application Continuity) vía `/change query`.
