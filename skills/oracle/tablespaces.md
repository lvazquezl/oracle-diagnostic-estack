---
name: tablespaces
id: oracle/tablespaces
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar uso, crecimiento y configuración de tablespaces (incluyendo autoextend y datafiles cercanos al límite) para detectar riesgo de agotamiento de espacio o configuración fuera de mejores prácticas.

# Supported Oracle versions

10g–23ai. `DBA_TABLESPACE_USAGE_METRICS` disponible desde 11g; en 10g se deriva de `DBA_DATA_FILES` + `DBA_FREE_SPACE`.

# Supported OS/platforms

Todas — el skill es lógico sobre el diccionario de datos, no depende del OS.

# Supported architectures

Standalone y RAC (tablespaces son compartidos a nivel base, no por instancia). NON-CDB y CDB (a nivel CDB$ROOT; el detalle por PDB lo cubre `multitenant/storage`). ASM y Filesystem (afecta cómo se interpreta autoextend/espacio disponible). Primary y Physical Standby (en standby, sólo lectura de metadata, sin `DBA_FREE_SPACE` útil si está en mount).

# Prerequisites

Requiere `core/context-discovery` confirmado (versión, storage_mode, container_mode).

# Required evidence

- query_id: `Q-DBA-TBS-USAGE-001` (`get_tablespace_usage`)

# Optional evidence

- query_id: `Q-DBA-TBS-DATAFILES-001` (detalle de datafiles y autoextend por tablespace)
- query_id: `Q-CAP-TBS-TREND-001` (histórico para tendencia, usado normalmente por `capacity/tablespaces`, no por este skill directamente)

# Read-only operations

Lectura de `DBA_TABLESPACES`, `DBA_DATA_FILES`, `DBA_TABLESPACE_USAGE_METRICS`, `DBA_FREE_SPACE`, `V$ASM_DISKGROUP` (si ASM, sólo para espacio disponible al autoextend).

# Forbidden operations

No ejecuta `ALTER TABLESPACE`, no agrega datafiles, no habilita/deshabilita autoextend.

# Decision logic

1. Calcular `used_pct = used_space / (autoextend ? maxbytes : allocated_space)` por tablespace.
2. Si `used_pct >= 90%` y no hay autoextend (o autoextend sin `maxbytes` efectivo por límite de storage) → severidad `HIGH`.
3. Si `used_pct >= 75%` y < 90% → severidad `MEDIUM`.
4. Si un datafile individual está cerca del límite de tamaño máximo del tipo de bloque (2TB con bigfile en bloques de 8k, por ejemplo) → señal aparte, independiente del `used_pct` del tablespace.
5. Si `storage_mode = asm` y el disk group subyacente también está bajo de espacio (evidencia opcional de `asm/capacity`), se correlaciona y se escala severidad.

# Confidence model

`FACT` para el uso actual leído directamente. `PROBABLE_CAUSE` cuando el agotamiento de espacio se correlaciona con un error `ORA-01653`/`ORA-01654`/`ORA-01688` reportado por el DBA en la misma ventana. `UNDETERMINED` si el target es standby en mount y no expone `DBA_FREE_SPACE` útil.

# Output schema

```yaml
findings:
  - tablespace: string
    used_pct: number
    autoextend: bool
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE|UNDETERMINED
    evidence_refs: [EVD-...]
```

# Related skills

`oracle/temp`, `oracle/undo`, `asm/capacity`, `capacity/tablespaces`.

# Escalation

Si severidad es `HIGH` en un tablespace de producción sin autoextend, el skill lo marca para escalar a `change-advisor` (propuesta de ampliación manual) y opcionalmente a `capacity-analyst` para forecast.

# Data sensitivity

Baja-media: nombres de tablespace pueden revelar nombres de aplicación; se enmascaran según política si el DBA no autoriza lo contrario.

# Context budget

Bajo: una consulta agregada por tablespace, sin necesidad de AWR.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_application_data_blocked.sh` (verifica que no se lean tablas de aplicación al analizar tablespaces).

# Documentation requirements

Alimenta `findings.md` con tabla de tablespaces en riesgo y `recommendations.md` con la sugerencia de ampliación (no accionable automáticamente).

# Evolution via `/change`

Cambios de umbral (75%/90%) vía `/change policy` (son parámetros de `policies/`, no hardcodeados aquí); cambios de lógica vía `/change skill`.
