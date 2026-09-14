---
name: platform-healthcheck
id: os/platform-healthcheck
version: 1.0.0
domain: os
status: active
---

# Purpose

Implementa `/healthcheck os` — recorre el flujo completo de discovery → CPU/NUMA → memoria/swap →
HugePages/THP → limits/IPC/AIO → filesystem/devices → red/time sync → integración Oracle/Grid →
findings → recomendaciones, consolidado en un solo reporte Markdown.

# Supported Oracle versions

N/A directo — orquesta el resto del dominio.

# Supported OS/platforms

Hereda el soporte de cada skill orquestado — degrada por plataforma según corresponda.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno — punto de entrada de `/healthcheck os`.

# Required evidence

- Orquesta: `os/discovery`, `os/platform-version`, `os/cpu-topology`, `os/numa`, `os/memory`,
  `os/swap`, `os/memory-pressure`, `os/hugepages`, `os/transparent-hugepages`,
  `os/process-limits`, `os/open-files`, `os/ulimits`, `os/systemd-limits`, `os/shared-memory`,
  `os/semaphores`, `os/aio`, `os/kernel-parameter-assessment`, `os/ephemeral-ports`,
  `os/tcp-socket-awareness`, `os/filesystems`, `os/inodes`, `os/mount-options`,
  `os/block-devices`, `os/multipath-awareness`, `os/io-performance`, `os/network-interfaces`,
  `os/bonding`, `os/vlan`, `os/mtu`, `os/routing`, `os/dns`, `os/time-sync`,
  `os/ssh-sshd-awareness`, `os/oracle-groups`, `os/oracle-processes`, `os/grid-processes`,
  `os/cgroups`, `os/log-pressure`

# Optional evidence

- `os/rac-interconnect-awareness`, `os/dataguard-network-awareness`,
  `os/rman-media-manager-awareness`, `os/security-filesystem-awareness` (sólo si la arquitectura
  del Target Profile los hace relevantes)

# Read-only operations

Ninguna propia — orquesta skills ya read-only.

# Forbidden operations

Ninguna capacidad de cambio.

# Decision logic

1. Flujo fijo (`# 52` del prompt): Target Profile → OS Discovery → CPU/NUMA → Memory/Swap →
   HugePages/THP → Limits/IPC/AIO → Filesystem/Devices → Network/Time Sync → Oracle/Grid
   Integration → Findings → Recommendations → Markdown.
2. Capability Filter aplicado antes de cada bloque — una plataforma `NOT_APPLICABLE` para un
   skill específico (ej. NUMA en Windows) omite ese bloque sin fallar el healthcheck completo.
3. Consolida el Health Model de 25 dimensiones (`agents/os-platform-analyst/output-schema.yaml`)
   en el reporte final — nunca un score único opaco.

# Normal state

Todas las dimensiones `HEALTHY`/`NOT_APPLICABLE`.

# Abnormal patterns

Cualquier dimensión `WARNING`/`DEGRADED`/`CRITICAL` — reportada con su propio detalle, nunca
colapsada.

# False positives

Ninguno propio — hereda la disciplina de cada skill orquestado.

# Correlation rules

Orquesta todo el dominio `os/*`. Alimenta `os/platform-assessment`,
`technical-documentation-manager`.

# Confidence model

Hereda de cada skill orquestado — nunca sobre-generaliza a `FACT` global.

# Severity

Heredada — el reporte muestra la dimensión más severa de forma destacada, sin ocultar el resto.

# Output schema

```yaml
os_platform_healthcheck:
  os_target: {...}   # de os/discovery
  health: {...}       # 25 dimensiones, ver output-schema.yaml del agente
  findings: [...]
  recommendations: [...]
```

# Related skills

Todos los skills `os/*`.

# Escalation

Cualquier hallazgo `CRITICAL` escala al agente Oracle correspondiente según correlación.

# Manual remediation guidance

Consolida las `manual_action` de todos los skills orquestados — siempre `NOT_EXECUTED`.

# Security

Hereda la sanitización de cada skill orquestado.

# Tests

Cubierto transitivamente por los tests de cada skill orquestado.

# Documentation requirements

Genera `os-summary.md` consolidado en `analysis/ANA-*/`.

# Change history

v1.0.0 — Fase 9, creación inicial.
