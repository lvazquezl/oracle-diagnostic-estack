---
name: topology
id: asm/topology
version: 1.0.0
domain: asm
status: active
---

# Purpose

Mapear la topología ASM: instancias ASM y disk groups visibles — la base sobre la que se apoyan el resto de skills ASM.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC (ASM típicamente compartido en RAC).

# Prerequisites

Target Profile con `architecture.storage_mode = asm`.

# Required evidence

- `Q-ASM-TOPOLOGY-001` (`V$ASM_DISKGROUP_STAT`, `GV$ASM_INSTANCE` cuando aplique)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$ASM_DISKGROUP_STAT`/`GV$ASM_INSTANCE`.

# Forbidden operations

No monta/desmonta disk groups.

# Decision logic

1. Enumerar instancias ASM visibles y disk groups montados por cada una.
2. Publicar el conteo para que el resto de skills ASM lo reutilicen sin recalcularlo.

# Confidence model

`FACT` para topología leída directamente.

# Output schema

```yaml
findings:
  - asm_instances: [{node: string, status: string}]
    diskgroups: [string]
    evidence_refs: [EVD-...]
```

# Related skills

`asm/instances`, `asm/diskgroups`.

# Escalation

Ninguna propia — es la base para el resto de skills ASM.

# Data sensitivity

Media — nombres de disk group pueden enmascararse según política.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_asm_diskgroup_stat_default.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

Nuevas columnas/vistas ASM vía `/change query`.
