---
name: instance-state
id: rac/instance-state
version: 1.0.0
domain: rac
status: active
---

# Purpose

Determinar el estado individual de cada instancia RAC (`STATUS`, `DATABASE_STATUS`, `ACTIVE_STATE`, tiempo de arranque) para distinguir una instancia sana de una en transición o degradada.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` ya resuelto en la misma sesión.

# Required evidence

- `Q-RAC-TOPOLOGY-001` (`GV$INSTANCE` — columnas `status`, `database_status`, `active_state`, `startup_time`)

# Optional evidence

Ninguna adicional — el estado de instancia es autocontenido en `GV$INSTANCE`.

# Read-only operations

Lectura de `GV$INSTANCE`.

# Forbidden operations

No reinicia ni relocaliza instancias.

# Decision logic

1. Clasificar cada instancia por `status` (`OPEN`/`MOUNTED`/`STARTED`) y `active_state` (`NORMAL`/`QUIESCING`/`QUIESCED`).
2. `startup_time` reciente sin ventana de mantenimiento conocida → candidato a investigar (posible reinicio/eviction reciente, correlacionar con `rac/instance-eviction`).
3. Instancia en `QUIESCING`/`QUIESCED` se reporta como observación explícita, no como anomalía — puede ser deliberado (`ALTER SYSTEM QUIESCE`, fuera del alcance de escritura de este stack, pero visible en lectura).

# Confidence model

`FACT` para el estado leído directamente. `HYPOTHESIS` para "posible reinicio reciente" hasta correlacionar con `rac/instance-eviction` o evidencia de mantenimiento.

# Output schema

```yaml
findings:
  - instance: string
    status: string
    active_state: string
    startup_time: string
    confidence: FACT|HYPOTHESIS
    evidence_refs: [EVD-...]
```

# Related skills

`rac/topology`, `rac/node-membership`, `rac/instance-eviction`.

# Escalation

Instancia inesperadamente `MOUNTED` (no `OPEN`) sin mantenimiento conocido → escala a `incident-root-cause-analyst`.

# Data sensitivity

Media — nombres de instancia enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_rac_instance_state.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md` con el estado por instancia.

# Evolution via `/change`

Nuevos estados/columnas vía `/change query`.
