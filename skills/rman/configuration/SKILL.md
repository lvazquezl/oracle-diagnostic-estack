---
name: configuration
id: rman/configuration
version: 1.0.0
domain: rman
status: active
---

# Purpose

Visibilidad de configuración RMAN persistente (retention policy, backup optimization, default device type, controlfile autobackup + format, parallelism DISK/SBT, channel configuration, snapshot controlfile name, archivelog deletion policy, MAXSETSIZE, encryption, compression) — nunca ejecuta `CONFIGURE` (`# 8` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai. `CON_ID` en `V$RMAN_CONFIGURATION` sólo 12.1+ (ver `compatibility/oracle-dictionary/views.yaml#v-rman-configuration`) — no seleccionada por la variante certificada.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno — primer skill del dominio, base para el resto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`.

# Collector IDs

`get_rman_configuration` (semántico, allowlisted — ver `docs/RMAN_COMMAND_SAFETY_MODEL.md#semantic-collectors`).

# Read-only operations

Lectura de `V$RMAN_CONFIGURATION`.

# Forbidden operations

Nunca ejecuta `CONFIGURE` en ninguna variante.

# Decision logic

1. Ausencia de una entrada `NAME` implica el valor por defecto de RMAN — nunca se reporta como gap.
2. `RETENTION POLICY` ausente/`TO REDUNDANCY 1` (default) → informar explícitamente, correlacionar con `rman/retention-policy`.
3. `CONTROLFILE AUTOBACKUP` OFF (default histórico) → hallazgo `MEDIUM`, correlacionar con `rman/controlfile-backup`.
4. `CHANNEL ... DEVICE TYPE ...` con parms de media manager → correlacionar con `rman/sbt-media-manager`, nunca exponer credenciales embebidas.

# Normal state

`RETENTION POLICY` y `CONTROLFILE AUTOBACKUP` explícitos y alineados a la política del sitio; `DEFAULT DEVICE TYPE` coincide con el device real usado en los backups recientes.

# Abnormal patterns

`CONTROLFILE AUTOBACKUP OFF` en un ambiente de producción; `RETENTION POLICY` en el default sin decisión documentada del DBA.

# False positives

Un `SNAPSHOT CONTROLFILE NAME` no configurado explícitamente no es un problema por sí solo — Oracle usa un default válido; ver `rman/snapshot-controlfile` para el análisis de riesgo real (RAC/path compartido).

# Correlation rules

Correlaciona con todo el resto del dominio — es la fuente de configuración base para `rman/retention-policy`, `rman/backup-optimization`, `rman/channels`, `rman/device-types`, `rman/snapshot-controlfile`, `rman/dataguard-awareness` (archivelog deletion policy).

# Confidence model

`FACT` para cada valor de configuración leído directamente.

# Severity

`CONTROLFILE AUTOBACKUP OFF` o `RETENTION POLICY` sin definir en producción → `MEDIUM`.

# Output schema

```yaml
configuration:
  retention_policy: string|null
  backup_optimization: ON|OFF|UNKNOWN
  default_device_type: DISK|SBT_TAPE|UNKNOWN
  controlfile_autobackup: ON|OFF|UNKNOWN
  controlfile_autobackup_format: string|null
  disk_parallelism: int|null
  sbt_parallelism: int|null
  snapshot_controlfile_path: string|null
  archivelog_deletion_policy: string|null
  encryption_enabled: bool|null
  compression_algorithm: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/retention-policy`, `rman/backup-optimization`, `rman/channels`, `rman/device-types`, `rman/snapshot-controlfile`.

# Escalation

`CONTROLFILE AUTOBACKUP OFF` sostenido sin controlfile backup reciente → `rman/controlfile-backup` para severidad real.

# Manual remediation guidance

Cambios de configuración se entregan vía Manual Action Contract (`CONFIGURE ...`), `execution_status: NOT_EXECUTED` — nunca se ejecuta.

# Security

`snapshot_controlfile_path`/`controlfile_autobackup_format` → MASK. Ningún parm de canal con credenciales de media manager se expone crudo.

# Tests

`tests/test_rman_configuration_query.sh`, `tests/test_no_configure_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/rman-configuration.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
