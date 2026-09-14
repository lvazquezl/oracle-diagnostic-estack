---
name: inodes
id: os/inodes
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza inodes totales/usados/libres/porcentaje por filesystem — detecta escenarios de muchos
archivos pequeños (ej. archivelog fragmentado, trace files acumulados) que agotan inodes antes
que el espacio.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`df -i`): `SUPPORTED`. Solaris (filesystems con inodes fijos, ej. UFS; ZFS no usa inodes
tradicionales — awareness explícita de la diferencia): `PARTIALLY_SUPPORTED`. Windows:
`NOT_APPLICABLE` (NTFS no usa el modelo de inodes de Unix).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/filesystems` ya ejecutado.

# Required evidence

- collector `get_inode_usage` (`df -i` equivalente)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de uso de inodes vía collector semántico.

# Forbidden operations

Nunca borra archivos, nunca reformatea filesystem.

# Decision logic

1. Reportar `inode_total`, `inode_used`, `inode_free`, `inode_percent` por filesystem relevante.
2. **Inode alto sin espacio agotado** es un escenario distinto y real (`# 30` del prompt:
   "Detectar escenarios de muchos archivos pequeños") — reportado independientemente del hallazgo
   de `os/filesystems`, nunca asumido cubierto por el chequeo de capacidad.
3. `inode_percent > 90%` en un mount con rol Oracle (trace/log destination, archivelog) → `HIGH`.

# Normal state

Inodes con margen suficiente en todos los filesystems relevantes.

# Abnormal patterns

Inodes cerca de agotarse mientras el espacio en bytes todavía tiene margen — típico de
directorios `trace`/`cdump`/archivelog con muchos archivos pequeños sin purga.

# False positives

Filesystems ZFS/tipos sin modelo de inodes fijo no generan hallazgo — `NOT_APPLICABLE`, nunca un
falso `HEALTHY` ni un falso `CRITICAL`.

# Correlation rules

Alimenta `os/filesystems`, `os/log-pressure`.

# Confidence model

`FACT` para uso leído directamente.

# Severity

`HIGH` si `inode_percent > 90%`; `CRITICAL` si `> 98%`.

# Output schema

```yaml
inodes:
  - mount_point: string   # MASK/TOKENIZE
    inode_total: int|null
    inode_used: int|null
    inode_percent: number|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/filesystems`, `os/log-pressure`.

# Escalation

Inode pressure en destino de diagnóstico escala a `oracle-dba-analyst`.

# Manual remediation guidance

`manual_action` sugiere purga manual de archivos antiguos (trace/log) — siempre `NOT_EXECUTED`.

# Security

`mount_point` → `MASK`/`TOKENIZE` por defecto.

# Tests

`tests/test_inode_usage.sh`, `tests/test_no_storage_change_execution.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
