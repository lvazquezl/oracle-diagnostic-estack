---
name: assessment
id: rac/assessment
version: 1.0.0
domain: rac
status: active
---

# Purpose

Orquestar `/assessment rac` (`# 42` del prompt de Fase 4): un informe de arquitectura/riesgos/recomendaciones (no un healthcheck puntual) cubriendo architecture, versions, nodes, instances, services, load-balancing configuration, SCAN, listeners, interconnect, ASM summary, configuration findings, risks, recommendations.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-RAC-TOPOLOGY-001`, más la evidencia agregada de `rac/services`, `rac/load-balancing`, `rac/gi-scan`, `rac/gi-listeners`, `rac/interconnect`, `rac/configuration-drift`.

# Optional evidence

- Resumen de `asm/assessment` cuando el análisis lo requiere.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No ejecuta ninguna acción — el assessment es siempre un informe.

# Decision logic

1. Recolectar evidencia de arquitectura/versión/topología/servicios/load-balancing/red/ASM.
2. Clasificar riesgos encontrados (config drift, SPOF potencial, servicio mal configurado) por severidad.
3. Generar recomendaciones — siempre `manual_action`, nunca ejecutadas.

# Confidence model

Hereda el `confidence` de cada skill subordinado.

# Output schema

```yaml
findings:
  - architecture: string
    versions: [string]
    risks: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
    recommendations: [{summary: string}]
```

# Related skills

`rac/healthcheck`, `rac/configuration-drift`, `rac/load-balancing`, `asm/assessment`.

# Escalation

Riesgo `HIGH`/`CRITICAL` no accionable de forma automática → `change-advisor` para propuesta formal.

# Data sensitivity

Media.

# Context budget

Alta — se resume por sección, no se propaga evidencia cruda.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el assessment en Markdown vía `technical-documentation-manager`.

# Evolution via `/change`

Nuevas dimensiones de assessment vía `/change workflow`.
