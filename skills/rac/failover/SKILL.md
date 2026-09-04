---
name: failover
id: rac/failover
version: 1.0.0
domain: rac
status: active
---

# Purpose

Reconocer evidencia de failover/relocation ya ocurrido (servicio corriendo fuera de su instancia preferida, recurso Clusterware relocalizado) para explicar placement actual — nunca dispara ni simula un failover.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/services`/`rac/service-placement` resueltos.

# Required evidence

- `Q-RAC-SERVICES-001` (placement actual vs. preferido)

# Optional evidence

- collector `get_cluster_resources` para el `state_details` de un recurso relocalizado.

# Read-only operations

Lectura de `GV$SERVICES`, salida estructurada de `crsctl stat res -t`.

# Forbidden operations

No relocaliza servicios ni instancias — TAF/Application Continuity se reconocen como metadata cuando existe, nunca se configuran ni disparan desde este stack.

# Decision logic

1. Detectar placement actual ≠ preferido (de `rac/service-placement`).
2. Si el recurso Clusterware asociado muestra `state_details` de relocation reciente, correlacionar como evento de failover explicado.
3. Sin esa correlación, se reporta como `HYPOTHESIS` de failover no confirmado — nunca se afirma como `FACT` sin evidencia directa del evento.

# Confidence model

`OBSERVATION` para placement no preferido sin más contexto. `PROBABLE_CAUSE` cuando el `state_details` del recurso confirma relocation.

# Output schema

```yaml
findings:
  - service: string
    current_instance: string
    preferred_instance: string
    failover_confirmed: bool
    confidence: OBSERVATION|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`rac/service-placement`, `rac/instance-eviction`, `rac/cluster-resources`.

# Escalation

Failover confirmado sin causa raíz clara (no coincide con mantenimiento) → escala a `incident-root-cause-analyst`.

# Data sensitivity

Media — `service_name`/nombres de instancia enmascarados.

# Context budget

Bajo.

# Tests

`tests/test_rac_service_placement.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_srvctl_relocate.sh`.

# Documentation requirements

Alimenta `service-analysis.md`.

# Evolution via `/change`

Metadata TAF/Application Continuity más rica vía `/change query` cuando esté certificada.
