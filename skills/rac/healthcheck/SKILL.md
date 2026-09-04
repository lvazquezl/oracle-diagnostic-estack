---
name: healthcheck
id: rac/healthcheck
version: 1.0.0
domain: rac
status: active
---

# Purpose

Orquestar el workflow `/healthcheck rac` (`# 39` del prompt de Fase 4): Target Profile → Capability Gate → GI Discovery → RAC Topology → Instances → Services → SCAN/VIP/Listeners → ASM summary → Interconnect summary → Findings → Markdown, produciendo el Cluster Health Model correlacionado (`# 38`).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Target Profile publicado con `cluster_mode` RAC.

# Required evidence

- `Q-RAC-TOPOLOGY-001` y, según lo que el flujo determine necesario, la evidencia de `rac/cluster-resources`, `rac/services`, `rac/gi-scan`, `rac/gi-vip`, `rac/gi-listeners`.

# Optional evidence

- Resumen de `asm/healthcheck` y `network/healthcheck` cuando el análisis lo requiere (delegado, no reconstruido).

# Read-only operations

Orquesta lecturas ya cubiertas por los skills subordinados — no introduce lecturas propias adicionales.

# Forbidden operations

No ejecuta ninguna acción correctiva — el healthcheck es siempre observación + findings.

# Decision logic

1. Ejecutar la secuencia declarada en `# Purpose` en orden.
2. Producir un `HEALTH MODEL` correlacionado por dimensión: `NODE HEALTH`, `INSTANCE HEALTH`, `RESOURCE HEALTH`, `SERVICE HEALTH`, `NETWORK HEALTH` (delegado a `oracle-network-analyst`), `ASM HEALTH` (delegado a `oracle-asm-storage-analyst`) — nunca un score opaco único (`# 38`).
3. Cada dimensión reporta `HEALTHY|DEGRADED|WARNING|CRITICAL|UNKNOWN` con evidencia, nunca sin ella.

# Confidence model

Hereda el `confidence` de cada skill subordinado — el healthcheck no reclasifica confianza, sólo agrega.

# Output schema

```yaml
findings:
  - dimension: NODE|INSTANCE|RESOURCE|SERVICE|NETWORK|ASM
    status: HEALTHY|DEGRADED|WARNING|CRITICAL|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`rac/topology`, `rac/cluster-resources`, `rac/services`, `rac/gi-scan`, `rac/gi-vip`, `rac/gi-listeners`, `asm/healthcheck`, `network/healthcheck`.

# Escalation

Cualquier dimensión `CRITICAL` → escala a `incident-root-cause-analyst`.

# Data sensitivity

Media — hereda la sensibilidad de cada dimensión.

# Context budget

Alta — agrega múltiples dimensiones; se resume por dimensión, no se propaga el detalle crudo de cada skill.

# Tests

`tests/test_rac_healthcheck.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el healthcheck en Markdown vía `technical-documentation-manager`.

# Evolution via `/change`

Nuevas dimensiones de salud vía `/change workflow`.
