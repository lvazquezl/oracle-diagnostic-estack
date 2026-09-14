---
name: filesystems
id: os/filesystems
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza capacidad, uso y tipo de filesystem — correlaciona con binarios Oracle, destinos de
diagnóstico, FRA, backups, logs y wallet.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`df`): `SUPPORTED`. Solaris (`df -h`): `SUPPORTED`. Windows (`get_windows_memory_summary`
análogo para discos, vía collector dedicado): `SUPPORTED`.

# Supported architectures

Standalone y RAC (por nodo; filesystems compartidos como ACFS/NFS se correlacionan sin
duplicarse por nodo).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_filesystem_usage` (`df` equivalente)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de uso de filesystem vía collector semántico.

# Forbidden operations

Nunca crea/borra archivos, nunca redimensiona filesystems.

# Decision logic

1. Reportar `capacity`, `used`, `available`, `percent_used`, `mount_point` (tokenizado según
   policy), `filesystem_type` por mount relevante.
2. Correlacionar cada mount con su rol Oracle cuando identificable: binarios (`ORACLE_HOME`),
   `diagnostic_dest`, FRA, destino de backups, logs, wallet — el umbral de severidad depende del
   rol (FRA/backups al 95% es `CRITICAL`; un mount genérico sin rol Oracle identificado es
   `LOW`/`INFO`).
3. `percent_used > 90%` en un mount con rol Oracle crítico (FRA, `diagnostic_dest`, `DATA`) →
   `HIGH`; `> 95%` → `CRITICAL`.

# Normal state

Todos los mounts relevantes con margen suficiente (`< 85%` como referencia, ajustable por
policy).

# Abnormal patterns

Mount con rol Oracle crítico cerca de agotarse, especialmente FRA/backups/`diagnostic_dest`.

# False positives

Un mount genérico sin rol Oracle identificado cerca de su capacidad no es `HIGH`/`CRITICAL` —
severidad depende del rol.

# Correlation rules

Alimenta `os/inodes`, `os/log-pressure`, `os/rman-media-manager-awareness`,
`os/security-filesystem-awareness`.

# Confidence model

`FACT` para uso leído directamente.

# Severity

`CRITICAL` > 95% en mount crítico; `HIGH` > 90%; `MEDIUM`/`LOW` por debajo.

# Output schema

```yaml
filesystems:
  - mount_point: string   # MASK/TOKENIZE según policy
    filesystem_type: string
    capacity_bytes: int
    used_bytes: int
    percent_used: number
    oracle_role: binaries|diagnostic_dest|fra|backups|logs|wallet|unknown|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/inodes`, `os/mount-options`, `os/log-pressure`, `os/rman-media-manager-awareness`,
`os/security-filesystem-awareness`.

# Escalation

Mount crítico agotándose escala a `oracle-backup-recovery-analyst` (FRA/backups) u
`oracle-dba-analyst` (`diagnostic_dest`/`DATA`).

# Manual remediation guidance

`manual_action` sugiere ampliar filesystem/limpiar espacio — siempre `NOT_EXECUTED`, ejecución
delegada al administrador OS/storage.

# Security

`mount_point`/paths → `MASK`/`TOKENIZE` por defecto salvo autorización explícita.

# Tests

`tests/test_filesystem_usage.sh`, `tests/test_no_storage_change_execution.sh`,
`tests/test_os_path_sanitization.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
