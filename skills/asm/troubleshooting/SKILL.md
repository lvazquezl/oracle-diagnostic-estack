---
name: troubleshooting
id: asm/troubleshooting
version: 1.0.0
domain: asm
status: active
---

# Purpose

Punto de entrada de `/diagnose asm` para síntomas no cubiertos por un skill específico — enruta al skill correcto.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile con `storage_mode = asm`.

# Required evidence

Ninguna propia.

# Optional evidence

- `Q-ASM-TOPOLOGY-001` como contexto base.

# Read-only operations

Ninguna propia.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Clasificar el síntoma: espacio bajo → `asm/capacity`; disco con errores → `asm/disks`; rebalance en curso → `asm/rebalance`; imbalance → `asm/failure-groups`.
2. Delegar al skill correcto — nunca reconstruye su lógica aquí.

# Confidence model

Hereda el `confidence` del skill al que enruta.

# Output schema

```yaml
findings:
  - symptom: string
    routed_to: string
    evidence_refs: [EVD-...]
```

# Related skills

`asm/disks`, `asm/capacity`, `asm/rebalance`, `asm/failure-groups`.

# Escalation

Síntoma correlacionable con I/O de performance → delega a `oracle-performance-analyst`.

# Data sensitivity

Media.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

N/A propio.

# Evolution via `/change`

Nuevos patrones de síntoma vía `/change knowledge` (`knowledge/errors/ora/`).
