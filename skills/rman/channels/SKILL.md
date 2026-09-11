---
name: channels
id: rman/channels
version: 1.0.0
domain: rman
status: active
---

# Purpose

Inventario de canales (automáticos/manuales, device type, parallelism, afinidad de instancia) — visibilidad, nunca `ALLOCATE CHANNEL`/`RELEASE CHANNEL` reales (`# 23` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/configuration` resuelto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`
- `Q-RMAN-BACKUP-DEVICE-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-DEVICE-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de `V$RMAN_CONFIGURATION`/`V$BACKUP_DEVICE`.

# Forbidden operations

Nunca ejecuta `ALLOCATE CHANNEL`/`RELEASE CHANNEL`/`CONFIGURE CHANNEL` reales.

# Decision logic

1. Canales configurados (`CHANNEL ... DEVICE TYPE ...`) vs. canales activos en este momento (`V$BACKUP_DEVICE`) — distinción explícita, nunca mezclados.
2. Parallelism configurado (`DEVICE TYPE DISK/SBT PARALLELISM N`) vs. canales realmente en uso — un mismatch sostenido es señal de sub-utilización o contención.

# Normal state

Parallelism configurado acorde a los recursos disponibles (CPU/I/O/media manager), canales activos coherentes con jobs en curso.

# Abnormal patterns

Canales configurados sin uso sostenido, o jobs esperando canal sin disponibilidad.

# False positives

`V$BACKUP_DEVICE` vacía fuera de una ventana de backup activa no es un problema.

# Correlation rules

Correlaciona con `rman/device-types`, `rman/channel-contention`, `rman/rac-awareness` (afinidad de instancia).

# Confidence model

`FACT` para canales leídos.

# Severity

Contención sostenida de canales → `MEDIUM`.

# Output schema

```yaml
channels:
  - device_type: DISK|SBT_TAPE|UNKNOWN
    parallelism: int|null
    allocation_type: AUTOMATIC|MANUAL|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`rman/device-types`, `rman/channel-contention`, `rman/rac-awareness`.

# Escalation

Contención sostenida con impacto en ventana de backup → `rman/channel-contention` → `os-platform-analyst`.

# Manual remediation guidance

Ajuste de parallelism/canales se entrega como recomendación manual — nunca ejecutado.

# Security

`instance_affinity` → MASK.

# Tests

`tests/test_channel_inventory.sh`, `tests/test_channel_parallelism.sh`, `tests/test_no_channel_allocate_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/channel-analysis.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
