---
name: services
id: rac/services
version: 1.0.0
domain: rac
status: active
---

# Purpose

Enumerar servicios de base de datos y su configuración declarada (rol, política, CLB/RLB goal, TAF/AC metadata) — base para `rac/service-placement` y `rac/load-balancing`.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- `Q-RAC-SERVICES-001` (`GV$SERVICES`, `GV$ACTIVE_SERVICES`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `GV$SERVICES`/`GV$ACTIVE_SERVICES`.

# Forbidden operations

No crea/modifica/relocaliza servicios (`srvctl modify service` prohibido).

# Decision logic

1. Listar cada servicio con su `clb_goal`, `goal` (RLB), y estado activo por instancia.
2. Diferenciar `configured placement` (declarado) de `actual placement` (activo ahora) — una diferencia entre ambos se reporta como observación, no como error automático (puede reflejar un failover ya resuelto).

# Confidence model

`FACT` para configuración/estado leído directamente.

# Output schema

```yaml
findings:
  - service_name: string
    clb_goal: string
    rlb_goal: string
    configured_instances: [string]
    active_instances: [string]
    evidence_refs: [EVD-...]
```

# Related skills

`rac/service-placement`, `rac/session-distribution`, `rac/load-balancing`, `rac/clb`, `rac/rlb`.

# Escalation

Servicio configurado sin ninguna instancia activa → escala a `incident-root-cause-analyst`.

# Data sensitivity

Media — `service_name` enmascarado por defecto (puede revelar nombre de aplicación).

# Context budget

Bajo.

# Tests

`tests/test_rac_services.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_srvctl_modify_execution.sh`.

# Documentation requirements

Alimenta `service-analysis.md`.

# Evolution via `/change`

Nuevos atributos de servicio (ej. Application Continuity metadata futura) vía `/change query`.
