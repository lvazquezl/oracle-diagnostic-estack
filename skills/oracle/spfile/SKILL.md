---
name: spfile
display_name: "SPFILE / PFILE Awareness"
id: oracle/spfile
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Determinar si la instancia usa SPFILE o PFILE, y si los parámetros persistidos en el SPFILE coinciden con los efectivos en memoria (`ISMODIFIED`/`SCOPE`), detectando cambios `MEMORY`-only no persistidos que se perderían en el próximo restart.

# Scope

**En alcance:** existencia/ubicación de SPFILE, consistencia SPFILE vs. memoria. **Fuera de alcance:** el contenido detallado de cada parámetro (eso es `oracle/parameters`).

# Supported Oracle versions

9i+ técnicamente; en el catálogo de este e-stack, 10g–23ai.

# Supported OS/platforms

Todas — la ruta del SPFILE difiere por convención de plataforma (`?/dbs/spfile<SID>.ora` en Unix/Linux, `%ORACLE_HOME%\database\SPFILE<SID>.ORA` en Windows) pero la vista `V$SPPARAMETER`/`V$PARAMETER.ISSPFILE_MODIFIABLE` es igual en todas.

# Supported architectures

Standalone y RAC (en RAC, el SPFILE es típicamente compartido — ver RAC considerations). NON-CDB y CDB. ASM (SPFILE puede residir en un disk group) y Filesystem. Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-SPFILE-001`

# Optional evidence

Ninguna.

# Data collection

`V$PARAMETER.ISSPFILE_MODIFIABLE` agregado y comparación con `V$SPPARAMETER` (existencia de SPFILE); `V$PARAMETER` filtrado por `ISMODIFIED = 'MODIFIED'` (cambios en memoria via `SCOPE=MEMORY` que no persistieron).

# Diagnostic logic / Decision tree

```text
IF no existe SPFILE (instancia arrancada con PFILE) → finding MEDIUM (riesgo operativo: cambios ALTER SYSTEM
   con SCOPE=SPFILE/BOTH fallarán o no persistirán correctamente)
IF existen parámetros con ISMODIFIED='MODIFIED' y no reflejados en V$SPPARAMETER → finding LOW/MEDIUM
   (cambio en memoria no persistido — se perderá en el próximo restart)
```

# Normal behavior

SPFILE presente y en uso; ningún parámetro con cambio `MEMORY`-only no documentado.

# Abnormal patterns

Ausencia de SPFILE en un ambiente productivo; múltiples parámetros con cambios en memoria no persistidos (indicativo de troubleshooting ad-hoc sin seguimiento).

# Root cause patterns

Un valor de parámetro que "vuelve a su default" tras un restart, reportado como síntoma por el DBA, correlacionado con `ISMODIFIED='MODIFIED'` sin persistencia en SPFILE — causa confirmable: el cambio se hizo con `SCOPE=MEMORY` en vez de `SCOPE=BOTH`.

# Correlation rules

Cruzar con `oracle/parameters` para identificar cuáles parámetros específicos no persistieron.

# False positives

Ausencia de SPFILE en un ambiente de desarrollo/laboratorio explícitamente declarado como tal (`environment_class` en `config/allowed-targets.local.yaml`) se reporta con severidad reducida, no como riesgo operativo pleno.

# Confidence model

`FACT` — comparación directa entre dos vistas de diccionario, sin ambigüedad.

# Findings

```yaml
finding_id: FND-...
category: spfile
severity: LOW|MEDIUM
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Crear SPFILE desde el PFILE actual si no existe; persistir con `SCOPE=BOTH` los cambios detectados sólo en memoria — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar que el PFILE actual refleja la configuración deseada antes de crear el SPFILE
command:    CREATE SPFILE FROM PFILE;   -- requiere restart para tomar efecto como spfile activo
expected_result: V$SPPARAMETER refleja los parámetros persistidos
rollback:   restaurar el PFILE original si el SPFILE generado no es el esperado
postcheck:  Q-ORA-SPFILE-001 re-ejecutada confirma SPFILE activo y sin ISMODIFIED='MODIFIED' pendientes
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai.

# RAC considerations

En RAC, el SPFILE es típicamente único y compartido (en ASM o filesystem compartido) entre todas las instancias — si cada instancia reporta un SPFILE distinto, es un finding `MEDIUM` (configuración no estándar, riesgo de divergencia).

# Multitenant considerations

El SPFILE es a nivel de instancia física (CDB), no por PDB — no varía por contenedor.

# Standby considerations

Un Physical Standby normalmente tiene su propio SPFILE (no compartido con el primary) — esto es normal, no un finding.

# Security

Read-only. No se lee el contenido crudo del archivo SPFILE (binario), sólo su representación vía `V$SPPARAMETER`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/parameters`, `oracle/controlfile`.

# Escalation

Ninguna especial — hallazgos de este skill rara vez requieren escalar a otro dominio.

# Examples

Ver `tests/fixtures/11g-standalone.yaml` (instancia arrancada con PFILE, sin SPFILE).

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto muy bajo.

# Tests

`tests/test_oracle_core_spfile.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
