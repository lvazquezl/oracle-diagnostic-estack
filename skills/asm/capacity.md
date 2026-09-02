---
name: capacity
id: asm/capacity
version: 1.0.0
domain: asm
status: active
---

# Purpose

Evaluar espacio libre/usado y headroom de cada disk group ASM, considerando la redundancia configurada, para detectar riesgo de agotamiento antes de que impacte a la base de datos.

# Supported Oracle versions

11g–23ai (ASM/GI). Diferencias de columnas en `V$ASM_DISKGROUP` documentadas por versión (ej. `USABLE_FILE_MB` disponible desde 11g).

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC (ASM típicamente compartido). ASM exclusivamente (no aplica a Filesystem). Primary y Physical Standby (ASM propio de cada sitio).

# Prerequisites

Requiere `core/context-discovery` confirmando `storage_mode = asm`.

# Required evidence

- query_id: `Q-ASM-DG-USAGE-001` (`get_asm_usage`)

# Optional evidence

- query_id: `Q-ASM-OPERATION-001` (rebalance en curso, sólo lectura de progreso)

# Read-only operations

Lectura de `V$ASM_DISKGROUP`, `V$ASM_DISK`, `V$ASM_OPERATION`.

# Forbidden operations

No ejecuta `ALTER DISKGROUP ADD/DROP/RESIZE DISK`, no inicia/detiene rebalance.

# Decision logic

1. Calcular `usable_free_pct = USABLE_FILE_MB / (TOTAL_MB aplicando factor de redundancia)` por disk group.
2. Si `usable_free_pct < 15%` → `HIGH`; si `< 25%` → `MEDIUM`.
3. Si hay una operación de rebalance activa (`V$ASM_OPERATION`), correlacionar el tiempo estimado restante con el headroom actual — un rebalance lento sobre un disk group casi lleno es agravante, no causa por sí solo.
4. Si `REDUNDANCY = EXTERNAL` y un disco reporta problemas de I/O, señalar riesgo de disponibilidad además de capacidad (sin redundancia Oracle de respaldo).

# Confidence model

`FACT` para el espacio usable leído directamente. `PROBABLE_CAUSE` cuando el agotamiento se correlaciona con errores `ORA-15041`/`ORA-15080` reportados por el DBA.

# Output schema

```yaml
findings:
  - diskgroup: string
    redundancy: string
    usable_free_pct: number
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`asm/diskgroups`, `asm/redundancy`, `asm/rebalance-analysis`, `capacity/asm`.

# Escalation

Severidad `HIGH` escala a `capacity-analyst` (forecast) y a `change-advisor` (propuesta de ampliación manual).

# Data sensitivity

Baja: nombres de disk group pueden enmascararse según política.

# Context budget

Bajo: estado de disk groups es compacto salvo cluster con decenas de disk groups, donde se agrega.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_asm_read_only.sh`.

# Documentation requirements

Alimenta `findings.md` con tabla de disk groups en riesgo.

# Evolution via `/change`

Umbrales (15%/25%) vía `/change policy`; nuevas queries ASM vía `/change query`.
