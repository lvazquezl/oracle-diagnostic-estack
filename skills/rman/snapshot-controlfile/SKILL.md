---
name: snapshot-controlfile
id: rman/snapshot-controlfile
version: 1.0.0
domain: rman
status: active
---

# Purpose

Análisis de path del snapshot controlfile (configurado, accesibilidad compartida en RAC, ASM/filesystem, riesgo de path local-only) — atención especial a `ORA-00245`. Nunca ejecuta `CONFIGURE SNAPSHOT CONTROLFILE NAME` (`# 21` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (riesgo específico de path local-only sólo aplica en RAC).

# Prerequisites

`rman/configuration` resuelto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`

# Optional evidence

Target Profile `rac.enabled`/`asm.enabled` para evaluar riesgo de path.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`.

# Collector IDs

`get_snapshot_controlfile_configuration`.

# Read-only operations

Lectura de `V$RMAN_CONFIGURATION` (`SNAPSHOT CONTROLFILE NAME`).

# Forbidden operations

Nunca ejecuta `CONFIGURE SNAPSHOT CONTROLFILE NAME`.

# Decision logic

1. Path en ASM (`+DISKGROUP/...`) → compartido por diseño entre nodos RAC, riesgo bajo.
2. Path en filesystem local (no montado compartido, ej. NFS/cluster filesystem) en un target RAC → riesgo real de `ORA-00245` (snapshot controlfile no accesible desde todas las instancias durante backup/restore multi-instancia).
3. Standalone → el riesgo de accesibilidad compartida no aplica.

# Normal state

Path en ASM, o en filesystem compartido confirmado (cluster filesystem/NFS) en RAC; cualquier path válido en standalone.

# Abnormal patterns

Path en filesystem local no compartido en un target RAC.

# False positives

Un path en filesystem local en standalone no es un riesgo — sólo aplica el riesgo compartido en RAC.

# Correlation rules

Correlaciona con `rman/rac-awareness`, delega a `oracle-rac-analyst`/`oracle-asm-storage-analyst` si se requiere confirmación de accesibilidad real del path.

# Confidence model

`FACT` para el path leído. `OBSERVATION` para el riesgo inferido según arquitectura.

# Severity

Path local-only en RAC sin confirmación de accesibilidad compartida → `HIGH` (riesgo de `ORA-00245`).

# Output schema

```yaml
configuration:
  snapshot_controlfile_path: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/configuration`, `rman/rac-awareness`.

# Escalation

Riesgo confirmado en producción RAC → `change-advisor` (propuesta de mover a path compartido/ASM).

# Manual remediation guidance

`CONFIGURE SNAPSHOT CONTROLFILE NAME` se entrega como recomendación manual — nunca ejecutado.

# Security

`snapshot_controlfile_path` → MASK siempre.

# Tests

`tests/test_snapshot_controlfile_shared_path.sh`, `tests/test_snapshot_controlfile_local_path_risk.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/rman-configuration.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
