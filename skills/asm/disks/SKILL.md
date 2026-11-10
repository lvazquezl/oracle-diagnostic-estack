---
name: disks
id: asm/disks
version: 1.1.0
domain: asm
status: active
---

# Purpose

Evaluar salud de discos individuales: `MOUNT_STATUS`, `HEADER_STATUS`, `MODE_STATUS`, `STATE`, `READ_ERRS`/`WRITE_ERRS` (`# 26` del prompt de Fase 4) — nunca expone paths sensibles completos si el sanitizer lo prohíbe.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/diskgroups` resuelto.

# Required evidence

- `Q-ASM-DISKS-001` (`V$ASM_DISK` — sólo top-N discos anómalos, no el listado completo)

**Gateway (lote B8, `CHG-ESTACK-B8-OPS-COVERAGE-001`):** `Q-ASM-DISKS-001` 2.0.0 lee `V$ASM_DISK_STAT` (sin discovery) y entrega conteos por disk group y failure group: discos no `MEMBER`, fuera de línea, en estado anormal y errores de lectura/escritura. Un disco concreto no se identifica: si un conteo es mayor que 0, la remediación indica al DBA consultar `V$ASM_DISK` en la instancia ASM.

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$ASM_DISK`.

# Forbidden operations

No agrega/quita discos, no cambia `MOUNT_STATUS`.

# Decision logic

1. Filtrar discos con `HEADER_STATUS != MEMBER` o `READ_ERRS`/`WRITE_ERRS > 0` — sólo estos se detallan al modelo (`# 76`), el resto se resume como conteo.
2. Cualquier disco con errores de lectura/escritura → `HIGH`.

# Confidence model

`FACT` para el estado leído directamente.

# Output schema

```yaml
findings:
  - disk: string                # PATH tokenizado
    diskgroup: string
    mount_status: string
    header_status: string
    mode_status: string
    read_errs: number
    write_errs: number
    evidence_refs: [EVD-...]
```

# Related skills

`asm/failure-groups`, `asm/diskgroups`.

# Escalation

Disco con errores de lectura/escritura → `change-advisor` para reemplazo (ejecución manual).

# Data sensitivity

Alta — `PATH` siempre tokenizado, nunca expuesto completo si el sanitizer lo prohíbe.

# Context budget

Media — top-N discos anómalos, no el listado completo.

# Tests

`tests/test_asm_disk_health.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_asmcmd_write_operation.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

Nuevos umbrales de error vía `/change policy`.

v1.1.0 — `CHG-ESTACK-B8-OPS-COVERAGE-001`: forma de la evidencia expuesta por el gateway (ver Required evidence).
