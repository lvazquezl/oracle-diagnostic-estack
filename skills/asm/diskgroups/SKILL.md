---
name: diskgroups
id: asm/diskgroups
version: 1.0.0
domain: asm
status: active
---

# Purpose

Estado, tipo y compatibilidad de cada disk group (`MOUNTED`, `type`, `compatibility`) — vista consolidada que `asm/capacity`/`asm/redundancy` refinan.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/topology` resuelto.

# Required evidence

- `Q-ASM-TOPOLOGY-001` (`V$ASM_DISKGROUP_STAT` — por defecto, no dispara disk discovery)

# Optional evidence

- `Q-DISC-ASM-001` (discovery inicial, ya certificada en Foundation) cuando se requiere confirmar presencia de ASM por primera vez en la sesión.

# Read-only operations

Lectura de `V$ASM_DISKGROUP_STAT`.

# Forbidden operations

No monta/desmonta, no crea/elimina disk groups.

# Decision logic

1. Listar cada disk group con `state` (`MOUNTED`/`DISMOUNTED`), `type`, `compatibility.asm`/`compatibility.rdbms`.
2. Disk group `DISMOUNTED` inesperado (con instancia de base de datos que lo requiere) → `HIGH`.
3. **`V$ASM_DISKGROUP` sólo se usa si disk discovery es explícitamente requerido** (hardening heredado de Foundation, `# 23` del prompt de Fase 4) — nunca para polling rutinario.

# Confidence model

`FACT` para estado leído directamente.

# Output schema

```yaml
findings:
  - diskgroup: string
    state: string
    type: string
    evidence_refs: [EVD-...]
```

# Related skills

`asm/capacity`, `asm/redundancy`, `asm/topology`.

# Escalation

Disk group DISMOUNTED inesperado → `incident-root-cause-analyst`.

# Data sensitivity

Media — nombres de disk group.

# Context budget

Bajo.

# Tests

`tests/test_asm_diskgroup_stat_default.sh`, `tests/test_asm_diskgroup_discovery_not_default.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

Nuevos atributos de disk group vía `/change query`.
