---
name: rman-media-manager-awareness
id: os/rman-media-manager-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

Correlaciona open files, process limits, filesystem y red del host con RMAN/procesos del media
manager (SBT) — nunca ejecuta jobs del vendor de backup.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux/Solaris/Windows: `SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/open-files`, `os/process-limits`, `os/filesystems` ya ejecutados.

# Required evidence

- evidencia de `os/open-files`, `os/filesystems` acotada al destino de FRA/backups y a los
  procesos SBT del media manager cuando identificables

# Optional evidence

- `os/process-limits` (canales RMAN paralelos consumen procesos/FDs adicionales)

# Read-only operations

Ninguna adicional — consolida evidencia ya recolectada.

# Forbidden operations

Nunca ejecuta jobs del vendor de media manager (`# 49` del prompt: "No ejecutar vendor jobs").

# Decision logic

1. Correlacionar `os/open-files` con el número de canales RMAN paralelos configurados — cada
   canal SBT abre file descriptors adicionales, un límite bajo con muchos canales es `HIGH`.
2. Correlacionar `os/filesystems` (rol FRA/backups) con la ventana de backup activa — presión de
   espacio durante una ventana de backup es más crítica que la misma presión fuera de ventana.
3. Nunca asume el vendor/producto de media manager específico sin que el Target Profile lo
   declare (mismo principio que `rman/sbt-media-manager`, Fase 7) — awareness genérica de
   proceso SBT, nunca vendor-specific sin evidencia.

# Normal state

Open files/process limits con margen suficiente para el número de canales RMAN configurados;
FRA/backups con espacio suficiente.

# Abnormal patterns

Límite de open files/procesos cerca de agotarse durante backup con múltiples canales; FRA cerca
de agotarse durante ventana de backup activa.

# False positives

Presión de FRA fuera de ventana de backup y sin canales SBT activos no escala con la misma
severidad que durante backup activo.

# Correlation rules

Consolida `os/open-files`, `os/process-limits`, `os/filesystems`. Alimenta
`oracle-backup-recovery-analyst`.

# Confidence model

`PROBABLE_CAUSE` cuando el hallazgo OS coincide temporalmente con una ventana de backup activa
reportada por `oracle-backup-recovery-analyst`.

# Severity

`HIGH` si el límite está cerca de agotarse durante una ventana de backup activa.

# Output schema

```yaml
rman_media_manager_os:
  open_files_adequacy: adequate|insufficient|unknown
  fra_backup_filesystem_adequacy: adequate|insufficient|unknown
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/open-files`, `os/process-limits`, `os/filesystems`.

# Escalation

Cualquier hallazgo escala a `oracle-backup-recovery-analyst`.

# Manual remediation guidance

Consolida las `manual_action` de los skills individuales — siempre `NOT_EXECUTED`, nunca ejecuta
comandos del vendor de media manager.

# Security

Hereda la sanitización de cada skill consolidado.

# Tests

`tests/test_os_rman_media_manager_awareness.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
