---
name: mount-options
id: os/mount-options
version: 1.0.0
domain: os
status: active
---

# Purpose

Awareness de opciones de mount (`rw`/`ro`, `noexec`, `nosuid`, `nodev`, `directio`/asíncrono
donde aplique) — nunca declara mala configuración sin contexto.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`/proc/mounts`, `mount`): `SUPPORTED`. Solaris (`mount -v`): `SUPPORTED`. Windows:
`NOT_APPLICABLE` (modelo de mount distinto).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/filesystems` ya ejecutado.

# Required evidence

- collector `get_mount_summary`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de opciones de mount vía collector semántico.

# Forbidden operations

Nunca remonta ni cambia opciones.

# Decision logic

1. Reportar opciones por mount relevante a Oracle.
2. `noexec`/`nosuid` en un mount de `ORACLE_HOME` **impediría el arranque de la instancia** —
   hallazgo `CRITICAL` sólo si el mount efectivamente aloja binarios Oracle (correlacionado con
   `os/filesystems#oracle_role`), nunca reportado genéricamente para mounts sin ese rol (`# 31`
   del prompt: "No declarar mala configuración sin contexto").
3. `directio` (o equivalente asíncrono) es una elección de diseño válida para datafiles en
   algunos filesystems — su ausencia no es intrínsecamente un hallazgo sin contexto de
   performance reportado.

# Normal state

Opciones de mount consistentes con el rol de cada filesystem (ej. `rw` en `ORACLE_HOME`/`DATA`,
sin `noexec` en binarios).

# Abnormal patterns

`noexec`/`ro` en un mount que aloja binarios Oracle o datafiles activos.

# False positives

`noexec` en un mount de datos (no binarios) es una práctica de hardening válida — nunca reportado
como hallazgo negativo por sí solo.

# Correlation rules

Alimenta `os/filesystems`, `os/security-filesystem-awareness`.

# Confidence model

`FACT` para opciones leídas directamente.

# Severity

`CRITICAL` sólo si `noexec`/`ro` está en un mount con rol de binarios Oracle confirmado.

# Output schema

```yaml
mount_options:
  - mount_point: string   # MASK/TOKENIZE
    options: [string]
    oracle_role: binaries|data|other|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/filesystems`, `os/security-filesystem-awareness`.

# Escalation

`CRITICAL` en binarios escala a `oracle-dba-analyst`.

# Manual remediation guidance

`manual_action` para remount con opciones correctas — siempre `NOT_EXECUTED`.

# Security

`mount_point` → `MASK`/`TOKENIZE` por defecto.

# Tests

`tests/test_mount_options.sh`, `tests/test_no_mount_execution.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
