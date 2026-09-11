---
name: device-types
id: rman/device-types
version: 1.0.0
domain: rman
status: active
---

# Purpose

Visibilidad de device types en uso (DISK/SBT_TAPE) y su alineación con el `DEFAULT DEVICE TYPE` configurado.

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

`Q-RMAN-BACKUP-SET-001` para el device type realmente usado en backups recientes.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-DEVICE-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de `V$RMAN_CONFIGURATION`/`V$BACKUP_DEVICE`.

# Forbidden operations

Ninguna operación de escritura.

# Decision logic

1. `DEFAULT DEVICE TYPE` configurado vs. device type real usado en el backup más reciente — un mismatch es señal de un `BACKUP ... DEVICE TYPE` explícito sobrescribiendo el default (no es un error por sí solo).
2. `SBT_TAPE` presente sin `rman/sbt-media-manager` confirmando la librería → correlacionar antes de reportar.

# Normal state

Device type consistente con la estrategia declarada (disk-based, SBT-based, o mixta documentada).

# Abnormal patterns

`SBT_TAPE` configurado sin evidencia de media manager funcional.

# False positives

Uso mixto DISK+SBT (ej. backup a disco luego copiado a tape) es una estrategia válida, no un hallazgo.

# Correlation rules

Correlaciona con `rman/sbt-media-manager`, `rman/channels`.

# Confidence model

`FACT` para device types leídos.

# Severity

N/A — informativo salvo mismatch con `rman/sbt-media-manager`.

# Output schema

```yaml
configuration:
  default_device_type: DISK|SBT_TAPE|UNKNOWN
  evidence_refs: [EVD-...]
```

# Related skills

`rman/sbt-media-manager`, `rman/channels`, `rman/configuration`.

# Escalation

Ninguna directa.

# Manual remediation guidance

`CONFIGURE DEFAULT DEVICE TYPE` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_rman_configuration_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/rman-configuration.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
