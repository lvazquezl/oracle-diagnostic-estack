---
name: platform-assessment
id: os/platform-assessment
version: 1.0.0
domain: os
status: active
---

# Purpose

Implementa `/assessment os-platform` — evaluación integral (no reactiva a un síntoma puntual)
que produce: resumen de plataforma, topología CPU, postura de memoria, swap, HugePages, THP,
limits, parámetros de kernel, filesystem, dispositivos, red, sincronización de tiempo,
integración Oracle/Grid, postura de seguridad, riesgos, recomendaciones y manual hardening plan.

# Supported Oracle versions

N/A directo — orquesta el resto del dominio, igual alcance que `os/platform-healthcheck` pero en
formato de assessment integral (no gate-oriented).

# Supported OS/platforms

Hereda el soporte de cada skill orquestado.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno — punto de entrada de `/assessment os-platform`.

# Required evidence

- Mismo conjunto que `os/platform-healthcheck`, más `os/rac-interconnect-awareness`,
  `os/dataguard-network-awareness`, `os/rman-media-manager-awareness`,
  `os/security-filesystem-awareness` cuando la arquitectura los haga relevantes (siempre
  incluidos en un assessment integral, a diferencia del healthcheck que los activa
  condicionalmente).

# Optional evidence

Ninguna adicional.

# Read-only operations

Ninguna propia — orquesta skills ya read-only.

# Forbidden operations

Ninguna capacidad de cambio.

# Decision logic

1. Resultado mínimo (`# 53` del prompt): platform summary, CPU topology, memory posture, swap,
   hugepages, THP, limits, kernel parameters, filesystem, devices, network, time
   synchronization, Oracle/Grid integration, security posture, risks, recommendations, manual
   hardening plan.
2. A diferencia de `os/platform-healthcheck` (gate rápido, activación condicional de
   cross-domain), este assessment siempre incluye la correlación cross-domain completa —
   evaluación integral, no reactiva.
3. Cada riesgo se prioriza por severidad e impacto declarado, nunca listado sin orden de
   prioridad.

# Normal state

Todas las dimensiones saludables, sin riesgos de prioridad alta.

# Abnormal patterns

Cualquier riesgo `HIGH`/`CRITICAL` reportado con su plan de remediación manual asociado.

# False positives

Ninguno propio — hereda la disciplina de cada skill orquestado.

# Correlation rules

Orquesta todo el dominio `os/*` incluyendo los 4 skills cross-domain. Alimenta
`technical-documentation-manager`.

# Confidence model

Hereda de cada skill orquestado.

# Severity

Heredada — priorizada explícitamente en el reporte final.

# Output schema

```yaml
os_platform_assessment:
  platform_summary: {...}
  cpu_topology: {...}
  memory_posture: {...}
  hugepages_thp: {...}
  limits: {...}
  kernel_parameters: {...}
  filesystem: {...}
  devices: {...}
  network: {...}
  time_sync: {...}
  oracle_grid_integration: {...}
  security_posture: {...}
  risks: [{priority: int, observation: string, severity: string}]
  recommendations: [...]
  manual_hardening_plan: [...]
```

# Related skills

Todos los skills `os/*`.

# Escalation

Riesgos `CRITICAL` escalan al agente Oracle correspondiente.

# Manual remediation guidance

Consolida el `os/manual-hardening-plan` completo.

# Security

Hereda la sanitización de cada skill orquestado.

# Tests

Cubierto transitivamente por los tests de cada skill orquestado.

# Documentation requirements

Genera el reporte de assessment completo en `analysis/ANA-*/`.

# Change history

v1.0.0 — Fase 9, creación inicial.
