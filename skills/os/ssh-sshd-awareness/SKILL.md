---
name: ssh-sshd-awareness
id: os/ssh-sshd-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

**Sólo posture awareness** (`# 42` del prompt): estado del servicio, ownership/permisos del
archivo de configuración, awareness de política de protocolo/cifrado cuando se pueda recolectar
de forma segura. Nunca edita `sshd_config`, nunca reinicia `sshd`.

# Supported Oracle versions

N/A directo — relevante para SSH equivalence entre nodos RAC (requerido por Grid Infrastructure
para ciertas operaciones administrativas, nunca ejecutadas por este e-stack).

# Supported OS/platforms

Linux (`systemctl status sshd`, `stat` sobre `sshd_config`): `SUPPORTED`. Solaris (`svcs`
equivalente): `SUPPORTED`. Windows: `NOT_APPLICABLE` (no aplica SSH/SSHD nativo).

# Supported architectures

Standalone y RAC (RAC requiere SSH equivalence entre nodos, awareness de esa configuración sin
inspeccionar claves).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_os_identity` (extendido con estado de servicio SSH)

# Optional evidence

- ownership/permisos de `sshd_config` (nunca su contenido completo)

# Read-only operations

Lectura de estado de servicio y metadata de archivo (ownership/permisos) — nunca el contenido
completo de `sshd_config` (podría revelar política de seguridad detallada innecesaria para el
diagnóstico).

# Forbidden operations

Nunca edita `sshd_config`, nunca reinicia `sshd` (`# 42`: "No editar sshd_config. No reiniciar
sshd").

# Decision logic

1. Reportar `service_status` (running/stopped), ownership/permisos de `sshd_config` (debe ser
   `root:root`, `600`/`644` según distribución — desviación es un hallazgo de hardening).
2. Awareness de protocolo/cifrado **sólo si recolectada de forma segura** (ej. metadata de
   versión de OpenSSH, nunca parseando el archivo completo de configuración) — sin esa evidencia
   segura, el campo queda `null`, nunca inventado.
3. Nunca inspecciona claves privadas ni `authorized_keys` de contenido — sólo existencia/
   permisos cuando sea relevante para el diagnóstico de SSH equivalence de RAC.

# Normal state

Servicio activo, `sshd_config` con ownership/permisos correctos.

# Abnormal patterns

`sshd_config` con permisos world-readable/writable, servicio inesperadamente detenido.

# False positives

Ninguno conocido — este skill es deliberadamente mínimo en alcance.

# Correlation rules

Alimenta `os/security-filesystem-awareness`.

# Confidence model

`FACT` para estado/permisos leídos directamente.

# Severity

`MEDIUM` si `sshd_config` tiene permisos incorrectos; `HIGH` si el servicio está inesperadamente
detenido y RAC requiere SSH equivalence activo.

# Output schema

```yaml
ssh_sshd:
  service_status: running|stopped|unknown
  config_ownership: string|null
  config_permissions: string|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/security-filesystem-awareness`.

# Escalation

Permisos incorrectos escala a `oracle-security-analyst`.

# Manual remediation guidance

`manual_action` sugiere corregir permisos/ownership — siempre `NOT_EXECUTED`, nunca edita
`sshd_config` ni reinicia el servicio.

# Security

Nunca lee contenido de `sshd_config` completo ni claves — sólo metadata.

# Tests

`tests/test_ssh_sshd_awareness.sh`, `tests/test_no_sshd_change_execution.sh`.

# Documentation requirements

Alimenta `oracle-processes.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
