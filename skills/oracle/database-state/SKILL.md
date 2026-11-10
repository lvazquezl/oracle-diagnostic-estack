---
name: database-state
display_name: "Database State"
id: oracle/database-state
version: 1.1.0
domain: oracle
status: active
---

# Purpose

Evaluar consistencia y flags globales de la base de datos (`open_mode`, `log_mode`, `force_logging`, `protection_mode`, `flashback_on`, `guard_status`) más allá de lo ya capturado en el Target Profile, detectando combinaciones inconsistentes o inesperadas.

# Scope

**En alcance:** flags de `V$DATABASE` no cubiertos por discovery (flashback, guard status, protection mode declarado, remote archive), y su consistencia entre sí. **Fuera de alcance:** re-determinar `database_role`/versión/arquitectura (ya en el Target Profile), Data Guard interno.

# Supported Oracle versions

10g–23ai. `GUARD_STATUS`/`FLASHBACK_ON` desde 10g; `PROTECTION_MODE`/`PROTECTION_LEVEL` sólo relevantes si hay Data Guard configurado (se reportan igual, `NOT_APPLICABLE` si no aplica).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB (a nivel CDB$ROOT). ASM y Filesystem. Primary y Physical Standby (algunos flags, como `GUARD_STATUS`, sólo tienen sentido en standby).

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-DB-STATE-001`

# Optional evidence

- `Q-ORA-DATABASE-MODE-001`

**Gateway (lote C, `CHG-ESTACK-C-NEW-QUERIES-001`):** `Q-ORA-DATABASE-MODE-001` entrega modo ARCHIVELOG, force logging, supplemental logging mínimo, open mode, edición (palabra cerrada del banner), CDB y estado de block change tracking. Hallazgos: `NOARCHIVELOG` en una base productiva (sin recuperación a un punto en el tiempo ni backups en línea, HIGH); `force_logging` `NO` con Data Guard o una réplica lógica (operaciones `NOLOGGING` no llegan al standby, MEDIUM); block change tracking deshabilitado con backups incrementales (cada incremental lee todos los datafiles, LOW). `block_change_tracking` nulo es "no observado" (en el lab, `V$BLOCK_CHANGE_TRACKING` no devolvió filas al usuario de diagnóstico desde `CDB$ROOT`): no hay hallazgo y el estado nunca se infiere. La edición filtra qué features aplican; `UNKNOWN` (banner de 10g/11g Standard Edition) nunca se infiere.

# Data collection

`V$DATABASE` completo (más allá de los campos ya en el Target Profile): `FLASHBACK_ON`, `GUARD_STATUS`, `PROTECTION_MODE`, `PROTECTION_LEVEL`, `REMOTE_ARCHIVE`, `SWITCHOVER_STATUS`.

# Diagnostic logic / Decision tree

```text
IF database_role = PRIMARY AND protection_mode != 'MAXIMUM PERFORMANCE' AND no standby evidente
   → finding: modo de protección configurado sin standby operativo confirmado (MEDIUM)
IF flashback_on = 'NO' AND es producción (según config/allowed-targets.local.yaml environment_class)
   → finding informativo: sin Flashback Database habilitado (LOW, recomendación no obligatoria)
IF guard_status != 'NONE' AND database_role = PRIMARY
   → finding: guard status inesperado en primary (MEDIUM) — posible configuración residual de un rol anterior
```

# Normal behavior

`FLASHBACK_ON` y `GUARD_STATUS` consistentes con el rol (`GUARD_STATUS = NONE` en primary típico salvo arquitecturas específicas); `PROTECTION_MODE` coherente con la topología Data Guard real cuando existe.

# Abnormal patterns

`GUARD_STATUS` distinto de `NONE` en un primary sin standby activo (residual de una reconfiguración anterior); `SWITCHOVER_STATUS` en un estado que sugiere un switchover interrumpido.

# Root cause patterns

`SWITCHOVER_STATUS` anómalo correlacionado con un evento de switchover reportado por el DBA — causa probable: switchover incompleto o revertido manualmente sin limpiar el estado.

# Correlation rules

Cruzar con `oracle-dataguard-analyst` (fases futuras) cuando `protection_mode`/`guard_status` sugiera una topología Data Guard activa no detectada por discovery.

# False positives

`PROTECTION_MODE = 'MAXIMUM PERFORMANCE'` sin standby no es un finding por sí solo — es el valor por defecto de una base standalone sin Data Guard configurado nunca.

# Confidence model

`FACT` para todos los campos, leídos directamente de `V$DATABASE`. No hay interpretación ambigua en este skill — es reporte de estado, no correlación compleja.

# Findings

```yaml
finding_id: FND-...
category: database-state
severity: LOW|MEDIUM
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Revisar configuración residual de Data Guard/Flashback si se detecta inconsistencia — siempre `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

NOT_APPLICABLE — este skill es puramente observacional; cualquier corrección de flags (`ALTER DATABASE FLASHBACK ON`, etc.) se genera, si aplica, desde `oracle-dataguard-analyst` en fases futuras, no aquí.

# Version differences

`GUARD_STATUS`/`SWITCHOVER_STATUS` estables desde 10g. Ninguna diferencia estructural relevante hasta 23ai.

# RAC considerations

Ninguna — `V$DATABASE` es idéntica desde cualquier instancia.

# Multitenant considerations

A nivel CDB$ROOT únicamente; no varía por PDB (estos flags son de la base física, no del contenedor).

# Standby considerations

`GUARD_STATUS`/`PROTECTION_MODE` son más relevantes en standby que en primary — este skill los reporta igual en ambos roles, sin asumir irrelevancia en standby.

# Security

Read-only, `SELECT` sobre `V$DATABASE`.

# Licensing

No depende de ninguna feature licenciada (Flashback Database no requiere Diagnostics/Tuning Pack).

# Related skills

`oracle/instance`, `oracle-discovery-analyst` (Target Profile).

# Escalation

Inconsistencias en flags de Data Guard escalan a `oracle-dataguard-analyst` cuando se profundice en fases futuras; por ahora se reportan como `capability_status: UNSUPPORTED` para el análisis profundo, con el finding observacional igual disponible.

# Examples

Ver `tests/fixtures/19c-physical-standby.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto muy bajo (una sola consulta compacta).

# Tests

`tests/test_oracle_core_database_state.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
| 1.1.0 | `CHG-ESTACK-C-NEW-QUERIES-001` (lote C) | Evidencia opcional del gateway: `Q-ORA-DATABASE-MODE-001` (ver Optional evidence). |
