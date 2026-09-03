---
name: invalid-objects
display_name: "Invalid Objects"
id: oracle/invalid-objects
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Identificar objetos inválidos (`DBA_OBJECTS.STATUS = 'INVALID'`) por schema/tipo, distinguiendo entre invalidaciones transitorias normales (que se resuelven con recompilación automática al primer uso) y acumulación anómala.

# Scope

**En alcance:** inventario de objetos inválidos, agrupación por schema/tipo, antigüedad de la invalidación si determinable. **Fuera de alcance:** recompilación (nunca — ver Forbidden capabilities del agente), análisis de la causa de invalidación a nivel de dependencia individual profunda (se reporta el patrón, no cada cadena de dependencias).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (metadata compartida). NON-CDB y CDB (`CDB_OBJECTS` desde 12c). ASM y Filesystem (no relevante). Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-INVALID-OBJECTS-001`

# Optional evidence

Ninguna.

# Data collection

`DBA_OBJECTS` filtrado a `STATUS = 'INVALID'`, agrupado por `OWNER`/`OBJECT_TYPE`; conteo total y lista acotada (con límite de filas del catálogo) de los más relevantes (schemas de sistema vs. de aplicación).

# Diagnostic logic / Decision tree

```text
IF hay objetos inválidos en schemas de sistema (SYS, SYSTEM, componentes Oracle) → finding HIGH
   (correlacionar con oracle/components — probablemente un upgrade incompleto)
IF hay objetos inválidos en schemas de aplicación en cantidad significativa (umbral configurable) → finding MEDIUM
IF pocos objetos inválidos (1-2) en schema de aplicación → finding LOW (frecuentemente transitorio,
   se resuelven solos al próximo acceso vía recompilación automática de Oracle)
```

# Normal behavior

Cero o muy pocos objetos inválidos, todos en schemas de aplicación, resueltos rápidamente por el mecanismo de recompilación automática de Oracle.

# Abnormal patterns

Objetos inválidos en schemas de sistema; una cantidad grande y persistente de objetos inválidos en un schema de aplicación (sugiere un deployment con dependencias rotas, no un caso transitorio).

# Root cause patterns

Objetos inválidos en cascada tras un `DROP`/`ALTER` de un objeto del que muchos otros dependen (típicamente reportado por el DBA como "hicimos un cambio y ahora hay X inválidos") — causa confirmable si el DBA declara el cambio reciente; sin esa declaración, queda `HYPOTHESIS`.

# Correlation rules

Cruzar con `oracle/components` (objetos de sistema inválidos casi siempre correlacionan con un componente en mal estado) y con `oracle/jobs` (¿coincide con un deployment automatizado?).

# False positives

Objetos inválidos que ya no aparecen en una segunda captura (se resolvieron por recompilación automática) no ameritan un finding persistente — este skill reporta el estado en el momento de la captura, y el workflow puede re-verificar antes de escalar severidad si hay dudas.

# Confidence model

`FACT` para el conteo/listado en el momento de la captura. `HYPOTHESIS` para la causa de la invalidación sin declaración explícita del DBA.

# Findings

```yaml
finding_id: FND-...
category: invalid-objects
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|HYPOTHESIS
impact: string
recommendations: [REC-...]
```

# Recommendations

Recompilar los objetos inválidos (típicamente vía `utlrp.sql`/`DBMS_UTILITY.COMPILE_SCHEMA`) — `manual_execution_required: true`. Este skill nunca ejecuta la recompilación directamente (prohibido explícitamente, ver `agents/oracle-dba-analyst/AGENT.md#forbidden-capabilities`).

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   identificar si la invalidación es de sistema (requiere utlrp.sql como SYS) o de aplicación
            (DBMS_UTILITY.COMPILE_SCHEMA por schema)
command:    @?/rdbms/admin/utlrp.sql   -- objetos de sistema
            -- o: EXEC DBMS_UTILITY.COMPILE_SCHEMA('<owner>');   -- objetos de un schema específico
expected_result: DBA_OBJECTS ya no muestra esos objetos como INVALID
rollback:   no aplica — recompilar no es una operación destructiva ni requiere rollback
postcheck:  Q-ORA-INVALID-OBJECTS-001 re-ejecutada confirma reducción del conteo de inválidos
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai; `utlrp.sql` es el mecanismo estándar en todas las versiones del catálogo.

# RAC considerations

Ninguna — el estado de objetos es compartido, idéntico desde cualquier instancia.

# Multitenant considerations

Con CDB, la invalidación puede ser específica de un PDB tras un `PDB PLUG`/upgrade parcial — este skill lo reporta si el análisis está acotado a ese PDB.

# Standby considerations

Idéntico al primary (se replica vía redo apply); no se puede recompilar en un standby de sólo lectura de todas formas (irrelevante para este skill, que nunca ejecuta recompilación).

# Security

Read-only, `SELECT` sobre `DBA_OBJECTS`/`CDB_OBJECTS`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/components`, `oracle/objects`.

# Escalation

Objetos inválidos de sistema (`SYS`/`SYSTEM`) escalan a `incident-root-cause-analyst` — señal de alta severidad, potencial problema estructural post-upgrade.

# Examples

Ver `tests/fixtures/12c-cdb-pdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (nombres de objeto/schema); presupuesto bajo (lista acotada por `max_rows`).

# Tests

`tests/test_oracle_core_invalid_objects.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
