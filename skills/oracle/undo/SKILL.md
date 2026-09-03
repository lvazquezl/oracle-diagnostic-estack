---
name: undo
display_name: "UNDO Configuration & Usage"
id: oracle/undo
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar configuración (`undo_tablespace`, `undo_retention`, `undo_management` en versiones donde aplica) y uso del tablespace UNDO, detectando riesgo de `ORA-01555` (snapshot too old) o de agotamiento de espacio.

# Scope

**En alcance:** configuración y uso agregado del tablespace UNDO activo. **Fuera de alcance:** análisis de transacciones largas específicas causando presión de UNDO (requiere `V$TRANSACTION` con detalle de sesión, más cercano a Fase 3).

# Supported Oracle versions

10g–23ai. `undo_management` (`AUTO`/`MANUAL`) relevante hasta 11g; desde 12c automatic undo management es el único modo soportado en la práctica (`MANUAL` deprecado).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (cada instancia tiene su propio `undo_tablespace` — parámetro que *debe* diferir entre instancias, ver False positives). NON-CDB y CDB (desde 18c, UNDO puede ser local por PDB en modo "PDB local undo"). ASM y Filesystem. Primary (foco principal).

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-UNDO-001`

# Optional evidence

Ninguna.

# Data collection

`DBA_TABLESPACES` (tipo UNDO), `V$UNDOSTAT` (estadísticas recientes de uso/retention), `DBA_DATA_FILES` filtrado al tablespace UNDO activo.

# Diagnostic logic / Decision tree

```text
used_pct del tablespace UNDO activo (igual lógica que oracle/tablespaces)
IF used_pct >= 90% → finding HIGH
IF V$UNDOSTAT muestra "tuned undo retention" muy por debajo de undo_retention configurado
   AND used_pct alto → finding MEDIUM (el sistema está reduciendo la retención real por presión de espacio,
   riesgo de ORA-01555 para consultas largas)
```

# Normal behavior

`used_pct` con margen razonable; retención efectiva (`V$UNDOSTAT.TUNED_UNDORETENTION`) igual o cercana a `undo_retention` configurado.

# Abnormal patterns

Retención efectiva muy por debajo de la configurada (el tablespace UNDO es demasiado pequeño para la actividad transaccional actual con la retención deseada); `used_pct` sostenidamente alto.

# Root cause patterns

`ORA-01555` reportado por el DBA correlacionado con retención efectiva reducida en `V$UNDOSTAT` en la ventana del error — causa probable confirmable cruzando el timestamp del error con las estadísticas de `V$UNDOSTAT`.

# Correlation rules

Cruzar con `oracle/jobs` (una carga batch larga puede generar presión de UNDO) y con `oracle/sessions` (transacciones de larga duración, si se detectan).

# False positives

`undo_tablespace` distinto entre instancias RAC no es un finding — es la configuración esperada (cada instancia usa su propio undo tablespace).

# Confidence model

`FACT` para configuración y uso actual. `PROBABLE_CAUSE` para correlación con `ORA-01555` sólo si el timestamp coincide con la ventana de presión confirmada.

# Findings

```yaml
finding_id: FND-...
category: undo
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|PROBABLE_CAUSE
impact: string
recommendations: [REC-...]
```

# Recommendations

Ampliar el tablespace UNDO o su datafile; revisar si `undo_retention` es mayor de lo que el tamaño actual puede sostener — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar espacio físico disponible
command:    ALTER DATABASE DATAFILE '<undo_datafile>' RESIZE <n>;
            -- o ALTER TABLESPACE <undo_ts> ADD DATAFILE '<path>' SIZE <n> AUTOEXTEND ON MAXSIZE <n>;
expected_result: used_pct baja, retención efectiva se acerca a la configurada
rollback:   no aplica reducción directa sin verificar high-water mark
postcheck:  Q-ORA-UNDO-001 re-ejecutada confirma used_pct y retención esperados
```

# Version differences

`undo_management` como parámetro relevante sólo hasta 11g (en 12c+ automatic es el único modo real); PDB local undo desde 18c.

# RAC considerations

Cada instancia tiene su propio `undo_tablespace` — este skill evalúa cada uno independientemente si RAC, nunca los mezcla.

# Multitenant considerations

Desde 18c, con "PDB local undo" habilitado, cada PDB tiene su propio undo tablespace — este skill detecta el modo pero, en Fase 2, evalúa a nivel de la conexión actual, no itera todos los PDBs.

# Standby considerations

Un Physical Standby en modo de sólo aplicar redo no genera actividad transaccional propia significativa en UNDO — el uso se mide igual pero se interpreta con matiz distinto (no comparable directamente al patrón del primary).

# Security

Read-only, `SELECT` sobre `DBA_TABLESPACES`/`V$UNDOSTAT`/`DBA_DATA_FILES`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/tablespaces`, `oracle/temp`, `oracle/sessions`.

# Escalation

Presión de UNDO sostenida correlacionada con `ORA-01555` recurrente escala a `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/12c-cdb-pdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto bajo.

# Tests

`tests/test_oracle_core_undo.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
