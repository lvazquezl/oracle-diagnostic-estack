---
name: manual-hardening-plan
id: os/manual-hardening-plan
version: 1.0.0
domain: os
status: active
---

# Purpose

Convierte cada hallazgo del dominio OS en un `manual_action` (Manual Action Contract, `# 61` del
prompt) — toda recomendación operativa queda como procedimiento para ejecución humana autorizada,
nunca ejecutada por el e-stack.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas las soportadas por el dominio — el contrato es agnóstico de plataforma, cada acción
declara su `platform` específica.

# Supported architectures

Standalone y RAC.

# Prerequisites

Al menos un hallazgo de otro skill `os/*` con severidad `MEDIUM`+.

# Required evidence

- findings de los skills `os/*` que generaron la recomendación

# Optional evidence

Ninguna.

# Read-only operations

Ninguna — este skill sólo redacta el procedimiento, nunca lo ejecuta.

# Forbidden operations

Nunca ejecuta ningún comando de cambio bajo ninguna circunstancia — `execution_status:
NOT_EXECUTED` es un campo fijo, nunca condicional.

# Decision logic

1. Cada `manual_action` declara: `action_id, purpose, owner_role, platform, command,
   config_file, prechecks, expected_result, risk, rollback, postchecks, reboot_required,
   execution_status: NOT_EXECUTED` (`# 61` del prompt) — ningún campo omitido.
2. Recomendaciones de `sysctl -w` quedan bajo "MANUAL OS ADMIN ACTION" (`# 62`); recomendaciones
   de `limits.conf`/systemd overrides quedan como procedimiento manual (`# 63`); cambios de
   bond/VLAN/MTU/route/firewall/DNS quedan bajo "MANUAL NETWORK/OS ADMIN ACTION" (`# 64`);
   cambios de Windows (registry/servicio/pagefile/firewall/adaptador) quedan sólo manuales
   (`# 65`) — la categoría se declara explícitamente en cada acción, nunca genérica.
3. `reboot_required` se declara honestamente — HugePages/kernel boot args frecuentemente
   requieren reinicio para garantía real (contigüidad de memoria, boot params), nunca se afirma
   "aplica en caliente" sin esa certeza.

# Normal state

N/A — este skill se activa sólo cuando hay hallazgos que requieren remediación.

# Abnormal patterns

N/A.

# False positives

N/A — este skill no genera hallazgos propios, sólo formaliza los de otros skills.

# Correlation rules

Consume findings de cualquier skill `os/*`. Alimenta `change-advisor` para convertir en
propuesta de cambio formal si el DBA lo aprueba.

# Confidence model

N/A — procedimientos, no diagnóstico.

# Severity

Heredada del finding que originó la acción.

# Output schema

```yaml
manual_action:
  action_id: string
  purpose: string
  owner_role: string
  platform: string
  command: string|null
  config_file: string|null
  prechecks: [string]
  expected_result: string
  risk: string
  rollback: string
  postchecks: [string]
  reboot_required: bool
  execution_status: NOT_EXECUTED
```

# Related skills

Todos los skills `os/*`.

# Escalation

Ninguna directa — el DBA/administrador autorizado decide si ejecuta el procedimiento.

# Manual remediation guidance

Este skill ES la guía de remediación manual del dominio.

# Security

Ningún comando se ejecuta; `command`/`config_file` se presentan como texto, nunca interpolados
en una llamada real.

# Tests

`tests/test_no_sysctl_execution.sh`, `tests/test_no_limits_change_execution.sh`,
`tests/test_no_network_change_execution.sh`, `tests/test_no_mount_execution.sh`,
`tests/test_no_storage_change_execution.sh`, `tests/test_no_sshd_change_execution.sh`,
`tests/test_no_group_change_execution.sh`.

# Documentation requirements

Alimenta `manual-hardening.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
