---
name: oracle-groups
id: os/oracle-groups
version: 1.0.0
domain: os
status: active
---

# Purpose

Awareness de grupos OS relevantes a Oracle (`oinstall`, `dba`, `oper`, `asmadmin`, `asmdba`,
`asmoper`, `backupdba`, `dgdba`, `kmdba`, `racdba` donde aplique) y su membresía — nunca crea o
modifica grupos.

# Supported Oracle versions

N/A directo — el conjunto de grupos SYSBACKUP/SYSDG/SYSKM (`backupdba`/`dgdba`/`kmdba`) es
12.1+; versiones anteriores usan un modelo de grupos más simple (`dba`/`oper`/`asmdba`
únicamente) — este skill reporta lo que existe, nunca asume el modelo completo en versiones
donde no aplica.

# Supported OS/platforms

Linux/Solaris (`/etc/group`, `getent group` de sólo lectura): `SUPPORTED`. Windows: `NOT_APPLICABLE`
(modelo de grupos local/AD distinto, fuera de alcance de este skill).

# Supported architectures

Standalone y RAC (ASM-related groups son más relevantes en configuraciones con ASM).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_os_identity` (extendido con `getent group` de los grupos relevantes)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `/etc/group`/`getent group` vía collector semántico.

# Forbidden operations

Nunca crea/modifica/elimina un grupo, nunca cambia membresía.

# Decision logic

1. Reportar existencia y membresía (usernames tokenizados) de los grupos relevantes presentes en
   el host.
2. Grupo esperado (según versión/edición declarada en Target Profile) ausente → `MEDIUM`,
   correlacionado con `oracle-security-analyst` para separación de privilegios administrativos.
3. Correlacionar con `security/admin-privileges` (Fase 8) — grupos OS y privilegios SYSDBA/
   SYSBACKUP/SYSDG/SYSKM a nivel de base de datos son capas relacionadas pero distintas, nunca
   confundidas.

# Normal state

Grupos esperados presentes con membresía consistente con el modelo de separación de privilegios
declarado.

# Abnormal patterns

Grupo de privilegio administrativo (ej. `asmadmin`) con membresía inesperadamente amplia.

# False positives

Ausencia de `backupdba`/`dgdba`/`kmdba` en una instalación pre-12.1 no es un hallazgo — esos
grupos no existen en ese modelo.

# Correlation rules

Alimenta `os/oracle-processes`, `os/security-filesystem-awareness`,
`oracle-security-analyst` (`security/admin-privileges`, por referencia).

# Confidence model

`FACT` para membresía leída directamente.

# Severity

`MEDIUM` si un grupo de privilegio administrativo tiene membresía inesperadamente amplia.

# Output schema

```yaml
oracle_groups:
  - group: string
    exists: bool
    members: [string]   # TOKENIZE por defecto
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/oracle-processes`, `os/security-filesystem-awareness`.

# Escalation

Membresía amplia inesperada escala a `oracle-security-analyst`.

# Manual remediation guidance

`manual_action` para ajuste de membresía de grupo — siempre `NOT_EXECUTED`, ejecución delegada
al administrador OS.

# Security

Usernames → `TOKENIZE` por defecto.

# Tests

`tests/test_oracle_groups_awareness.sh`, `tests/test_no_group_change_execution.sh`.

# Documentation requirements

Alimenta `oracle-processes.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
