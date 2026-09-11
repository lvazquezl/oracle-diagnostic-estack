---
name: channel-contention
id: rman/channel-contention
version: 1.0.0
domain: rman
status: active
---

# Purpose

Análisis de contención de canales (ej. una segunda base esperando canales SBT/media manager) — correlaciona RMAN parallelism, concurrencia de media manager, límites de servidor, pools SBT, política Commvault/Simpana y job scheduler, nunca asume causa Oracle única (`# 23` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/channels` resuelto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`
- `Q-RMAN-BACKUP-DEVICE-001`
- `Q-RMAN-STATUS-001`

# Optional evidence

Delegación a `os-platform-analyst`/`oracle-network-analyst` para el lado proceso/conectividad.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-DEVICE-001`, `Q-RMAN-STATUS-001`.

# Collector IDs

`get_rman_configuration`, `get_backup_summary`.

# Read-only operations

Lectura de las vistas certificadas.

# Forbidden operations

Nunca ejecuta `ALLOCATE CHANNEL`/`RELEASE CHANNEL`.

# Decision logic

1. Parallelism configurado (`rman/channels`) vs. canales realmente en uso concurrentemente (`V$BACKUP_DEVICE` a lo largo del tiempo, `V$RMAN_STATUS` de jobs solapados) — un job esperando mientras otro consume todo el parallelism SBT es contención real.
2. Nunca se asume causa Oracle única: correlacionar con límites de servidor (CPU/memoria del media manager), pools SBT configurados en el vendor, política de scheduling (ej. dos backups programados a la misma hora) — delegar a `os-platform-analyst`/`oracle-network-analyst` para confirmar el lado proceso/conectividad antes de concluir.
3. `single_cause_asserted` siempre `false` en el output — el hallazgo se presenta con las causas candidatas correlacionadas, nunca una única causa confirmada sin evidencia cruzada.

# Normal state

Canales disponibles cuando se solicitan, sin jobs esperando sostenidamente.

# Abnormal patterns

Un job esperando canal SBT de forma sostenida mientras otro lo consume.

# False positives

Una espera breve y aislada durante solapamiento intencional de ventanas de backup no es contención sostenida.

# Correlation rules

Correlaciona con `rman/channels`, `rman/sbt-media-manager`, `rman/rac-awareness`; delega a `os-platform-analyst`/`oracle-network-analyst`/`oracle-performance-analyst`.

# Confidence model

`OBSERVATION` para contención medida. `PROBABLE_CAUSE` sólo con correlación cruzada confirmada — nunca `CONFIRMED_ROOT_CAUSE`.

# Severity

Contención sostenida con impacto en ventana de backup de producción → `HIGH`.

# Output schema

```yaml
channel_contention:
  detected: bool
  correlated_with: [string]
  single_cause_asserted: false
  evidence_refs: [EVD-...]
```

# Related skills

`rman/channels`, `rman/sbt-media-manager`, `rman/rac-awareness`, `rman/backup-duration`.

# Escalation

Contención sostenida sin resolución → `os-platform-analyst`/`oracle-network-analyst` → `incident-root-cause-analyst`.

# Manual remediation guidance

Ajuste de parallelism/scheduling se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_channel_contention_analysis.sh`, `tests/test_channel_contention_not_assumed_oracle_only.sh`, `tests/test_no_channel_allocation_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/channel-analysis.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
