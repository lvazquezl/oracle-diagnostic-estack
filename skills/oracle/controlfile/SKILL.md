---
name: controlfile
display_name: "Controlfile Metadata"
id: oracle/controlfile
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar metadata del controlfile: número de copias (multiplexado), tamaño vs. `MAXINSTANCES`/`MAXLOGHISTORY`/`MAXDATAFILES` (record sections cerca de su límite), y — si RMAN lo reporta — autobackup habilitado.

# Scope

**En alcance:** multiplexado, uso de record sections, autobackup awareness. **Fuera de alcance:** contenido detallado de backups (`rman/*`, no profundizado en Fase 2), recreación de controlfile (nunca — es una operación destructiva potencial).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (controlfile compartido). NON-CDB y CDB. ASM y Filesystem. Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-CONTROLFILE-001`

# Optional evidence

Ninguna (autobackup de RMAN pertenece a `rman/controlfile`, no profundizado en Fase 2 — este skill sólo reporta multiplexado y record sections desde `V$CONTROLFILE`/`V$CONTROLFILE_RECORD_SECTION`).

# Data collection

`V$CONTROLFILE` (nombre, estado de cada copia); `V$CONTROLFILE_RECORD_SECTION` (`TYPE`, `RECORDS_USED`, `RECORDS_TOTAL`).

# Diagnostic logic / Decision tree

```text
IF count(V$CONTROLFILE) < 2 → finding MEDIUM (sin multiplexado — riesgo de punto único de falla)
Para cada record section:
  IF RECORDS_USED / RECORDS_TOTAL >= 90% → finding MEDIUM (ej. sección DATAFILE cerca de MAXDATAFILES)
```

# Normal behavior

Al menos 2 copias del controlfile en ubicaciones/discos distintos; ninguna record section por encima del 90% de uso.

# Abnormal patterns

Una sola copia del controlfile; sección `RMAN CONFIGURATION` o `DATAFILE`/`LOG HISTORY` cerca del límite (riesgo de no poder agregar más datafiles/archivelogs sin recrear el controlfile con un `MAXDATAFILES`/`MAXLOGHISTORY` mayor).

# Root cause patterns

Fallo al agregar un datafile (`ORA-01503`/similar) correlacionado con `RECORDS_USED/RECORDS_TOTAL` cerca de 100% en la sección `DATAFILE` — causa confirmable directamente por la evidencia, sin necesidad de correlación adicional.

# Correlation rules

Cruzar con `oracle/tablespaces` (crecimiento de datafiles) y `oracle/archive` (crecimiento de log history) para anticipar cuándo una record section alcanzará su límite.

# False positives

Ninguno relevante — esta es una de las áreas más objetivas del diagnóstico (conteo directo, sin interpretación).

# Confidence model

`FACT` en todos los casos.

# Findings

```yaml
finding_id: FND-...
category: controlfile
severity: LOW|MEDIUM
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Agregar una copia adicional del controlfile en un disco/disk group distinto si no está multiplexado; planificar una recreación de controlfile con parámetros `MAX*` mayores si una record section se acerca a su límite — ambas `manual_execution_required: true`, la segunda de alto riesgo (requiere backup y ventana de mantenimiento, se marca explícitamente).

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   backup completo del controlfile actual (BACKUP CONTROLFILE TO TRACE / RMAN) antes de cualquier cambio
command:    ALTER DATABASE BACKUP CONTROLFILE TO '<path>'; -- para agregar multiplexado se edita CONTROL_FILES
            en el SPFILE y se hace restart; recreación con MAXDATAFILES mayor requiere generar el trace,
            editarlo, y ejecutar CREATE CONTROLFILE (alto riesgo, requiere ventana de mantenimiento)
expected_result: V$CONTROLFILE muestra la copia adicional; nueva record section con más capacidad
rollback:   restaurar desde el backup del controlfile tomado en el precheck
postcheck:  Q-ORA-CONTROLFILE-001 re-ejecutada confirma multiplexado/capacidad esperada
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai.

# RAC considerations

El controlfile es compartido entre todas las instancias — el multiplexado beneficia al cluster completo, no a una instancia individual.

# Multitenant considerations

El controlfile es a nivel CDB, no por PDB — no varía por contenedor.

# Standby considerations

Un Physical Standby tiene su propio controlfile (generado desde un standby controlfile del primary) — la evaluación de multiplexado aplica igual en el standby.

# Security

Read-only. No se lee el contenido binario del controlfile, sólo metadata vía `V$*`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/spfile`, `oracle/archive`, `oracle/tablespaces`.

# Escalation

Una record section al límite que bloquea operaciones activas (ej. no se pueden agregar más datafiles) escala a `incident-root-cause-analyst` si coincide con un síntoma reportado.

# Examples

Ver `tests/fixtures/10g-standalone-noncdb.yaml` (una sola copia de controlfile, sin multiplexado).

# Data sensitivity / Context budget

Sensibilidad BAJA (rutas de archivo pueden enmascararse); presupuesto muy bajo.

# Tests

`tests/test_oracle_core_controlfile.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
