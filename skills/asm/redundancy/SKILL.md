---
name: redundancy
id: asm/redundancy
version: 1.0.0
domain: asm
status: active
---

# Purpose

Reconocer el nivel de redundancia real de cada disk group (`EXTERNAL`/`NORMAL`/`HIGH`/`FLEX`/`EXTENDED` cuando aplique por versión) — usa metadata reportada por ASM, nunca fórmulas universales incorrectas (`# 25` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai. `FLEX` desde 12.1 (Flex ASM). `EXTENDED` sólo donde la arquitectura lo soporta — declarado explícitamente, nunca asumido.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/diskgroups` resuelto.

# Required evidence

- `Q-ASM-TOPOLOGY-001` (`V$ASM_DISKGROUP_STAT.TYPE`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$ASM_DISKGROUP_STAT`.

# Forbidden operations

No cambia redundancia (`ALTER DISKGROUP ... REDUNDANCY` prohibido).

# Decision logic

1. Leer `TYPE` reportado por ASM directamente — nunca inferido de otra métrica.
2. Publicar la redundancia para que `asm/capacity` la use en su cálculo de `usable_pct`.

# Confidence model

`FACT` — la redundancia es metadata directa, sin ambigüedad.

# Output schema

```yaml
findings:
  - diskgroup: string
    redundancy: EXTERNAL|NORMAL|HIGH|FLEX|EXTENDED
    evidence_refs: [EVD-...]
```

# Related skills

`asm/capacity`, `asm/failure-groups`.

# Escalation

Ninguna propia — alimenta `asm/capacity`.

# Data sensitivity

Baja — metadata estructural.

# Context budget

Bajo.

# Tests

`tests/test_asm_redundancy.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

Nuevos tipos de redundancia futuros vía `/change compatibility`.
