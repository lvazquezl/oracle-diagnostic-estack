---
name: session-distribution
id: rac/session-distribution
version: 1.0.0
domain: rac
status: active
---

# Purpose

Evaluar cómo se distribuyen las sesiones entre las instancias de un cluster RAC para detectar desbalance que degrade throughput o sature una instancia mientras otras están subutilizadas.

# Supported Oracle versions

11gR2–23ai (CLB/RLB con comportamiento estable desde 11gR2; versiones anteriores se declaran con soporte limitado).

# Supported OS/platforms

Todas las soportadas por RAC (Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server).

# Supported architectures

RAC y RAC One Node exclusivamente. NON-CDB y CDB. ASM y Filesystem (no afecta directamente la distribución de sesiones). Primary y Physical Standby (en standby con Active Data Guard, aplica a sesiones de sólo lectura).

# Prerequisites

Requiere `core/context-discovery` confirmando `instance_mode = rac` y `rac/topology` ya resuelto en la misma sesión de análisis.

# Required evidence

- query_id: `Q-RAC-SESSION-DIST-001` (`get_session_distribution`)

# Optional evidence

- query_id: `Q-RAC-SERVICE-PLACEMENT-001` (placement de servicios, para correlacionar desbalance con configuración de servicio)

# Read-only operations

Lectura de `GV$SESSION`, `GV$SERVICES`, `DBA_SERVICES` (configuración de `CLB_GOAL`/`RLB_GOAL`, sólo lectura).

# Forbidden operations

No relocaliza sesiones, no modifica `CLB_GOAL`/`RLB_GOAL` de un servicio, no desconecta sesiones.

# Decision logic

1. Contar sesiones activas por instancia, agrupadas por servicio.
2. Calcular desviación porcentual respecto a una distribución uniforme esperada (`100/N_instancias`).
3. Si la desviación de una instancia supera el umbral de política (ver `policies/`) → severidad `MEDIUM`; si además coincide con saturación de CPU en esa instancia (evidencia de `os-platform-analyst`) → `HIGH`.
4. Correlacionar con `CLB_GOAL`/`RLB_GOAL` del servicio: si el goal es `NONE` o el pool de conexiones del lado aplicación no usa balanceo, señalarlo como causa probable en vez de un problema del cluster.

# Confidence model

`FACT` para el conteo de sesiones por instancia. `PROBABLE_CAUSE` para la causa del desbalance (config de servicio vs. connection pooling del lado app) — requiere la evidencia opcional de placement para subir de `HYPOTHESIS` a `PROBABLE_CAUSE`.

# Output schema

```yaml
findings:
  - service: string
    instance: string
    session_count: number
    deviation_pct: number
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`rac/clb`, `rac/rlb`, `rac/service-placement`, `rac/services`, `os/*/cpu` (vía `os-platform-analyst`).

# Escalation

Si el desbalance coincide con saturación de una instancia, escala hacia `os-platform-analyst` para confirmar impacto de CPU/memoria, y hacia `change-advisor` si la causa raíz apunta a configuración de servicio corregible manualmente.

# Data sensitivity

Baja-media: nombres de servicio pueden revelar nombres de aplicación; se enmascaran según política salvo autorización explícita.

# Context budget

Bajo-medio: conteo agregado por instancia/servicio, no el detalle de cada sesión individual salvo que se pida explícitamente.

# Tests

`tests/test_rac_standalone_detection.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `findings.md` con la tabla de distribución por servicio/instancia.

# Evolution via `/change`

Umbral de desviación vía `/change policy`; nuevas queries de distribución vía `/change query`.
