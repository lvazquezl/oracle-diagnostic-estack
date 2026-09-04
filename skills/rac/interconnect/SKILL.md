---
name: interconnect
id: rac/interconnect
version: 1.0.0
domain: rac
status: active
---

# Purpose

Evaluar salud del interconnect privado usado por Cache Fusion, correlacionando `GV$CLUSTER_INTERCONNECTS`, metadata `oifcfg`/OS y wait indicators — sin asumir que una interfaz/bond/VLAN incorrecta es la causa sin esa evidencia (`# 33` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- `Q-RAC-INTERCONNECT-001` (`GV$CLUSTER_INTERCONNECTS`)

# Optional evidence

- collector `get_network_configuration` (`oifcfg getif`) y evidencia OS de interfaz/bonding vía `os-platform-analyst`.

# Read-only operations

Lectura de `GV$CLUSTER_INTERCONNECTS`, salida estructurada de `oifcfg getif`.

# Forbidden operations

No cambia bonding/VLAN/interfaz/MTU.

# Decision logic

1. Confirmar la(s) interfaz(ces) declarada(s) como interconnect vs. lo que `GV$CLUSTER_INTERCONNECTS` reporta activo.
2. Distinguir red pública, interconnect privado, red ASM (si existe como red separada) y red de backup (si existe).
3. Correlacionar con `rac/global-cache` (gc waits elevados) antes de sugerir causa de red — un gc wait elevado sin discrepancia de interfaz no se atribuye a interconnect.

# Confidence model

`FACT` para la interfaz reportada. `HYPOTHESIS` para "interconnect como causa" sin corroborar con `rac/global-cache` o evidencia OS.

# Output schema

```yaml
findings:
  - interface: string
    type: PUBLIC|PRIVATE|ASM|BACKUP
    status: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/global-cache`, `network/interconnect`, `os/linux/network` (y equivalentes por plataforma vía `os-platform-analyst`).

# Escalation

Discrepancia de interfaz confirmada + gc waits elevados correlacionados → escala a `os-platform-analyst` para confirmar bonding/VLAN a nivel OS.

# Data sensitivity

Media-alta — IPs/nombres de interfaz enmascarados por defecto.

# Context budget

Media.

# Tests

`tests/test_rac_interconnect.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_network_change.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Redes ASM/backup dedicadas adicionales vía `/change query` cuando la arquitectura las requiera.
