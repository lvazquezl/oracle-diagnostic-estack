---
name: sessions
display_name: "Sessions Summary"
id: oracle/sessions
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Producir un resumen agregado de sesiones (conteo por estado/tipo, sesiones bloqueadas, sesiones de larga duración) sin distribución cross-instance (eso es `rac/session-distribution`, no profundizado en Fase 2) ni atribución a SQL específico (Fase 3).

# Scope

**En alcance:** conteo agregado por `STATUS`/`TYPE`, sesiones `BLOCKING`/`BLOCKED` (metadata de bloqueo, no análisis de locking profundo), sesiones con `LAST_CALL_ET` extremo. **Fuera de alcance:** distribución por instancia/servicio (RAC), atribución a SQL/wait event (Performance).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (agregado por instancia si RAC, sin cruzar — eso es `rac/session-distribution`). NON-CDB y CDB (con `CON_ID` visible desde 12c). ASM y Filesystem (no relevante). Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-SESSIONS-SUMMARY-001`

# Optional evidence

Ninguna.

# Data collection

`V$SESSION` agregado: `COUNT(*) GROUP BY STATUS, TYPE`; sesiones con `BLOCKING_SESSION IS NOT NULL`; `MAX(LAST_CALL_ET)` para sesiones `ACTIVE`. Nunca `SQL_TEXT`, `MODULE`/`ACTION` con contenido potencialmente sensible sin sanitizar, ni columnas de aplicación.

# Diagnostic logic / Decision tree

```text
IF count(sesiones ACTIVE con BLOCKING_SESSION) > 0 → finding MEDIUM (contención de locks presente,
   sin profundizar en la cadena — eso requeriría performance/locking, Fase 3)
IF count(sesiones) cerca del límite de 'sessions' (cruzar con oracle/resource-limits) → finding HIGH
IF alguna sesión ACTIVE con LAST_CALL_ET extremo (ej. > umbral configurado) → finding informativo
   (posible sesión colgada o transacción muy larga)
```

# Normal behavior

Conteo de sesiones estable y por debajo del límite configurado; sin cadenas de bloqueo sostenidas; `LAST_CALL_ET` de sesiones activas dentro de rangos esperados para el tipo de carga.

# Abnormal patterns

Crecimiento sostenido del conteo de sesiones sin explicación (posible connection leak del lado aplicación); cadena de bloqueo presente en el momento de la captura; sesiones activas con `LAST_CALL_ET` de horas.

# Root cause patterns

Saturación de conexiones (`ORA-00018`: maximum number of sessions exceeded) correlacionada con un conteo creciente sin liberación — causa probable: connection leak o pool de conexiones mal configurado del lado aplicación (fuera del control del e-stack, pero se documenta como observación).

# Correlation rules

Cruzar con `oracle/resource-limits` (¿qué tan cerca del límite configurado?) y con `oracle/processes` (el conteo de procesos OS debe ser consistente con el de sesiones).

# False positives

Un pico de sesiones durante una ventana de conexión masiva conocida (ej. inicio de jornada laboral) no es un finding si está dentro del límite configurado con margen.

# Confidence model

`FACT` para conteos y estados leídos directamente. `OBSERVATION` para "posible connection leak" — requiere series de tiempo (fuera de una sola captura) para confirmar tendencia, así que en una sola invocación queda como observación, no como hallazgo confirmado.

# Findings

```yaml
finding_id: FND-...
category: sessions
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|OBSERVATION
impact: string
recommendations: [REC-...]
```

# Recommendations

Revisar configuración de connection pooling del lado aplicación si se sospecha leak; ampliar `sessions`/`processes` si el crecimiento es legítimo — ambas `manual_execution_required: true`, ninguna ejecutada por este skill (nunca se mata una sesión — eso está explícitamente prohibido, ver `policies/forbidden-operations.md`).

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar impacto de ampliar 'sessions'/'processes' en memoria de la instancia (requiere restart si SCOPE=SPFILE)
command:    ALTER SYSTEM SET sessions=<n> SCOPE=SPFILE;  -- (o processes=<n>, ver oracle/parameters)
expected_result: mayor margen antes de ORA-00018
rollback:   ALTER SYSTEM SET sessions=<valor_anterior> SCOPE=SPFILE;
postcheck:  Q-ORA-SESSIONS-SUMMARY-001 y oracle/resource-limits re-ejecutadas confirman margen esperado
```

# Version differences

`CON_ID` en `V$SESSION` desde 12c. Sin otras diferencias estructurales relevantes.

# RAC considerations

Este skill agrega por instancia individual, sin cruzar — la distribución/desbalance entre instancias es responsabilidad de `rac/session-distribution` (no profundizado en Fase 2; se señala `capability_status: UNSUPPORTED` para ese análisis específico si el DBA lo pide explícitamente).

# Multitenant considerations

Desde 12c, se puede filtrar por `CON_ID` si el análisis se acota a un PDB específico (`constraints.area_scope`/contexto del Task Package); por defecto se reporta a nivel de la conexión actual.

# Standby considerations

En Active Data Guard, un standby puede tener sesiones de sólo lectura activas — este skill las cuenta igual, sin asumir que un standby siempre tiene cero sesiones de usuario.

# Security

Read-only, `SELECT` sobre `V$SESSION` agregado únicamente — nunca se lee `SQL_TEXT` completo, `MODULE`/`ACTION` sin sanitizar, ni ninguna columna que pueda contener datos de aplicación.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/resource-limits`, `oracle/processes`, `oracle/undo`.

# Escalation

Cadena de bloqueo sostenida escala a `incident-root-cause-analyst`. Distribución cross-instance y locking profundo escalan (como `capability_status: UNSUPPORTED` por ahora) hacia `oracle-rac-analyst`/`oracle-performance-analyst` en fases futuras.

# Examples

Ver `tests/fixtures/19c-rac-cdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (conteos agregados, no contenido individual); presupuesto bajo.

# Tests

`tests/test_oracle_core_sessions.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
