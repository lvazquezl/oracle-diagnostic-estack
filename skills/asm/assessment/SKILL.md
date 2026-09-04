---
name: assessment
id: asm/assessment
version: 1.0.0
domain: asm
status: active
---

# Purpose

Informe de arquitectura/riesgos/recomendaciones de almacenamiento ASM — complementa `rac/assessment` cuando el análisis lo invoca (resumen de ASM, no un healthcheck puntual).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile con `storage_mode = asm`.

# Required evidence

- Evidencia agregada de `asm/diskgroups`, `asm/capacity`, `asm/redundancy`, `asm/disks`.

# Optional evidence

Ninguna adicional.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No ejecuta ninguna acción.

# Decision logic

1. Recolectar evidencia de capacidad/redundancia/salud de discos.
2. Clasificar riesgos (headroom crítico, redundancia insuficiente para failure groups disponibles, discos con errores).
3. Generar recomendaciones — siempre `manual_action`.

# Confidence model

Hereda el `confidence` de cada skill subordinado.

# Output schema

```yaml
findings:
  - risks: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
    recommendations: [{summary: string}]
```

# Related skills

`asm/healthcheck`, `asm/capacity`, `capacity-analyst`.

# Escalation

Riesgo `HIGH`/`CRITICAL` → `change-advisor`.

# Data sensitivity

Media.

# Context budget

Alta — se resume por sección.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el assessment en Markdown vía `technical-documentation-manager`.

# Evolution via `/change`

Nuevas dimensiones vía `/change workflow`.
