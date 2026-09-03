---
name: jobs
display_name: "Scheduler / Jobs Summary"
id: oracle/jobs
version: 1.1.0
domain: oracle
status: active
---

# Purpose

Evaluar resumen de jobs `DBMS_SCHEDULER`: fallidos recientes, de larga duración (`BROKEN`/`FAILED`), o con `failure_count > 0`.

# Scope

**En alcance:** estado y resultado reciente de jobs `DBMS_SCHEDULER` (metadata), sin ejecutar ni modificar ninguno. **Fuera de alcance:** el contenido/lógica de negocio de cada job (sección 20, protección de datos de aplicación); jobs legacy `DBMS_JOB`/`DBA_JOBS` — ver Compatibility Hardening abajo.

> **Oracle Core Compatibility Hardening**: `DBA_JOBS` (legacy `DBMS_JOB`) **no está cubierto** por `Q-ORA-JOBS-SUMMARY-001` (corrección de un metadata/reality mismatch — la v1.0 lo declaraba sin consultarlo). Un ambiente que dependa únicamente de `DBMS_JOB` legado reporta `capability_status: PARTIALLY_SUPPORTED` para este skill, con `reason: "DBA_JOBS legacy no cubierto por el catálogo certificado"` y `alternative: "el DBA puede revisar DBA_JOBS/DBA_JOBS_RUNNING manualmente"`. Una query `Q-ORA-JOBS-LEGACY-001` queda `PLANNED` para una fase futura vía `/change query`.

# Supported Oracle versions

10g–23ai. `DBMS_SCHEDULER` disponible desde 10g (reemplaza gradualmente a `DBMS_JOB`, aún presente pero deprecado en versiones recientes).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (jobs pueden tener afinidad a una instancia/service). NON-CDB y CDB (desde 12c, jobs pueden ser CDB-wide o locales a un PDB). ASM y Filesystem (no relevante). Primary (los jobs normalmente no corren en standby).

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-JOBS-SUMMARY-001`

# Optional evidence

Ninguna.

# Data collection

`DBA_SCHEDULER_JOBS` (`STATE`, `LAST_START_DATE`, `FAILURE_COUNT`) vía `Q-ORA-JOBS-SUMMARY-001`. `DBA_SCHEDULER_JOB_RUN_DETAILS` y `DBA_JOBS`/`DBA_JOBS_RUNNING` (legacy) **no** se consultan todavía — ver nota de Compatibility Hardening arriba.

# Diagnostic logic / Decision tree

```text
IF un job STATE='SCHEDULED' con historial de ejecución regular no corrió en su ventana esperada → finding MEDIUM
IF FAILURE_COUNT reciente > 0 en la última ejecución → finding MEDIUM/HIGH según criticidad declarada (si conocida)
IF un job lleva corriendo (RUNNING) mucho más tiempo que su LAST_RUN_DURATION histórico → finding informativo
   (posible job colgado)
IF un job está BROKEN (DBMS_JOB legacy) → finding MEDIUM
```

# Normal behavior

Jobs corriendo en su ventana esperada, sin fallos recientes, duración consistente con el historial.

# Abnormal patterns

Job fallido repetidamente; job `BROKEN`; job corriendo muy por encima de su duración histórica normal (posible bloqueo o degradación).

# Root cause patterns

Un job fallido correlacionado con un error específico en `DBA_SCHEDULER_JOB_RUN_DETAILS.ADDITIONAL_INFO` (ej. `ORA-01653` del tablespace donde escribe) — causa confirmable cruzando con el skill del área específica (`oracle/tablespaces`, etc.).

# Correlation rules

Cruzar con `oracle/tablespaces`/`oracle/temp`/`oracle/undo` cuando el error de un job apunta a esas áreas. Cruzar con `oracle/instance` si el fallo coincide con un restart de instancia.

# False positives

Un job explícitamente deshabilitado por el DBA (documentado, ej. vía `constraints` del Task Package o conocimiento previo declarado) no es un finding.

# Confidence model

`FACT` para estado/resultado leído directamente. `PROBABLE_CAUSE` para la causa de un fallo sólo si el mensaje de error específico lo confirma.

# Findings

```yaml
finding_id: FND-...
category: jobs
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|PROBABLE_CAUSE
impact: string
recommendations: [REC-...]
```

# Recommendations

Investigar y corregir la causa raíz de un job fallido (ej. ampliar tablespace si ese era el error) — `manual_execution_required: true`. Este skill nunca re-habilita (`ENABLE`) ni re-ejecuta un job directamente.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar que la causa raíz del fallo fue corregida antes de re-habilitar
command:    EXEC DBMS_SCHEDULER.ENABLE('<job_name>');   -- o DBMS_JOB.BROKEN(<job>, FALSE) para legacy
expected_result: el job vuelve a ejecutarse en su próxima ventana programada sin fallo
rollback:   EXEC DBMS_SCHEDULER.DISABLE('<job_name>'); si el re-habilitado no fue apropiado
postcheck:  Q-ORA-JOBS-SUMMARY-001 re-ejecutada confirma ejecución exitosa en la ventana siguiente
```

# Version differences

`DBMS_JOB` presente pero deprecado desde 10g en favor de `DBMS_SCHEDULER`; ambos se evalúan si están en uso.

# RAC considerations

Los jobs pueden tener afinidad a un servicio/instancia específica (`INSTANCE_STICKINESS`, `SERVICE`) — este skill lo reporta pero no evalúa el placement en profundidad (eso es `rac/service-placement`, no profundizado en Fase 2).

# Multitenant considerations

Desde 12c, un job puede ser `DBA_SCHEDULER_JOBS.CON_ID`-específico (local a un PDB) o CDB-wide — este skill reporta el alcance detectado.

# Standby considerations

Jobs normalmente no corren en un Physical Standby (la base está en mount o read-only) — si se detectan jobs `SCHEDULED`/`RUNNING` en un standby, es una señal a investigar (posible Active Data Guard con jobs mal configurados apuntando ahí).

# Security

Read-only, `SELECT` sobre `DBA_SCHEDULER_*`/`DBA_JOBS*`. No se lee el código PL/SQL del job (podría contener lógica de negocio) — sólo metadata de ejecución.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/tablespaces`, `oracle/temp`, `oracle/undo`, `oracle/instance`.

# Escalation

Un job crítico (declarado como tal por el DBA) fallando repetidamente escala a `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-standalone-cdb.yaml` (job `NIGHTLY_STATS` fallido 3 veces consecutivas).

# Data sensitivity / Context budget

Sensibilidad BAJA-MEDIA (nombres de job pueden revelar lógica de negocio); presupuesto bajo.

# Tests

`tests/test_oracle_core_jobs.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
| 1.1.0 | Oracle Core Compatibility Hardening | Corregido metadata/reality mismatch (`DBA_JOBS` declarado sin consultarse); alcance acotado explícitamente a `DBMS_SCHEDULER`; `DBA_JOBS` legacy documentado como `PARTIALLY_SUPPORTED`/`PLANNED`. |
