---
name: instance
display_name: "Instance State"
id: oracle/instance
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar el estado operativo de la instancia (`V$INSTANCE`: `STATUS`, `STARTUP_TIME`, `SHUTDOWN_PENDING`, `DATABASE_STATUS`, `INSTANCE_ROLE`) más allá de la identidad ya capturada en el Target Profile.

# Scope

**En alcance:** estado operativo actual de la(s) instancia(s), tiempo de actividad, indicadores de shutdown pendiente. **Fuera de alcance:** distribución de carga entre instancias RAC (futuro `rac/session-distribution`), performance de la instancia (Fase 3).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (si RAC, reporta cada instancia visible vía `GV$INSTANCE`). NON-CDB y CDB. ASM y Filesystem. Primary y Physical Standby.

# Prerequisites

Target Profile publicado (para saber si iterar `GV$INSTANCE` o sólo `V$INSTANCE`).

# Required evidence

- `Q-ORA-INSTANCE-STATE-001`

# Optional evidence

Ninguna.

# Data collection

`V$INSTANCE` (o `GV$INSTANCE` si RAC): `STATUS`, `STARTUP_TIME`, `SHUTDOWN_PENDING`, `DATABASE_STATUS`, `ACTIVE_STATE`, `BLOCKED`.

# Diagnostic logic / Decision tree

```text
IF status != 'OPEN' AND open_mode esperado es READ WRITE/READ ONLY → finding HIGH (instancia no disponible como se esperaba)
IF shutdown_pending = 'YES' → finding HIGH (shutdown en curso, ventana de análisis limitada)
IF active_state = 'STOPPING'|'ABORTING' (RAC) → finding HIGH para esa instancia específica
IF startup_time reciente (< 1h) sin que el DBA lo haya declarado esperado → finding informativo (posible restart no anunciado)
```

# Normal behavior

`status = OPEN`, `shutdown_pending = NO`, `active_state = NORMAL`, `startup_time` consistente con la operación esperada (sin restarts recientes no explicados).

# Abnormal patterns

Instancia en `MOUNTED` cuando se esperaba `OPEN`; `startup_time` muy reciente sin correlato de mantenimiento planificado; en RAC, una instancia en estado distinto al resto del cluster.

# Root cause patterns

Un restart no anunciado correlacionado con un error en `oracle/diagnostics` (alert log) en la misma ventana — causa probable: crash o shutdown abrupto. Sin acceso a alert log, queda `HYPOTHESIS`, no `PROBABLE_CAUSE`.

# Correlation rules

Cruzar `startup_time` con `oracle/diagnostics` (alert log metadata) y con `oracle/jobs` (si un job crítico se interrumpió por el restart).

# False positives

Un `startup_time` reciente coincidente con una ventana de mantenimiento declarada por el DBA (vía `constraints` del Task Package) no es un finding.

# Confidence model

`FACT` para todos los campos — lectura directa sin ambigüedad. La interpretación de "restart no anunciado" es `HYPOTHESIS` salvo confirmación cruzada.

# Findings

```yaml
finding_id: FND-...
category: instance
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|HYPOTHESIS
impact: string
recommendations: [REC-...]
```

# Recommendations

Si se detecta una instancia caída/inesperadamente reiniciada, recomendar revisión de alert log/OS por el DBA — `manual_execution_required: true`, sin comando específico (esto es diagnóstico, no una acción de configuración).

# DBA commands / prechecks / rollback / postchecks

NOT_APPLICABLE — este skill nunca genera un comando de inicio/parada de instancia (`STARTUP`/`SHUTDOWN` están explícitamente prohibidos, ver `policies/forbidden-operations.md`).

# Version differences

`ACTIVE_STATE`/`BLOCKED` estables desde 10g. `INSTANCE_ROLE` (`PRIMARY_INSTANCE`/`STANDBY_INSTANCE`) útil desde 11g para instancias RAC en un standby.

# RAC considerations

En RAC, cada instancia se reporta individualmente vía `GV$INSTANCE`; una instancia caída no implica que el cluster completo esté caído — el finding se asocia a la instancia específica, nunca se generaliza al target completo sin verificar las demás.

# Multitenant considerations

A nivel de instancia física, no de PDB — no varía por contenedor.

# Standby considerations

`DATABASE_STATUS` puede reportar `ACTIVE` con la base en modo `MOUNTED` (aplicando redo) — esto es normal en standby, no un finding, y este skill lo distingue explícitamente usando `database_role` del Target Profile antes de evaluar.

# Security

Read-only, `SELECT` sobre `V$INSTANCE`/`GV$INSTANCE`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/database-state`, `oracle/diagnostics`.

# Escalation

Instancia caída en un cluster RAC con otras instancias sanas escala a `incident-root-cause-analyst` si el DBA reportó un síntoma relacionado.

# Examples

Ver `tests/fixtures/19c-rac-cdb.yaml` (3 instancias, una en estado `MOUNTED` inesperado).

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto bajo, escalable con número de instancias en RAC.

# Tests

`tests/test_oracle_core_instance.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
