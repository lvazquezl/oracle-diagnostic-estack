---
name: instances
id: asm/instances
version: 1.0.0
domain: asm
status: active
---

# Purpose

Confirmar estado individual de cada instancia ASM (`STATUS`, `INSTANCE_NAME`) — distingue una instancia ASM sana de una en transición.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/topology` resuelto.

# Required evidence

- `Q-ASM-TOPOLOGY-001` (`GV$ASM_INSTANCE` — `STATUS`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `GV$ASM_INSTANCE`.

# Forbidden operations

No reinicia instancias ASM.

# Decision logic

1. Clasificar cada instancia ASM por `STATUS` (`STARTED`/`MOUNTED`).
2. Instancia ASM esperada pero ausente → observación, correlacionar con `rac/node-membership` en RAC.

# Confidence model

`FACT` para el estado leído directamente.

# Output schema

```yaml
findings:
  - node: string
    status: string
    evidence_refs: [EVD-...]
```

# Related skills

`asm/topology`, `asm/healthcheck`.

# Escalation

Instancia ASM ausente inesperadamente → `incident-root-cause-analyst`.

# Data sensitivity

Media.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

N/A — vista estable desde 11gR2.
