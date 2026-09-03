---
name: temp
display_name: "TEMP Tablespace Usage"
id: oracle/temp
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar uso y configuración de tablespaces temporales (TEMP), incluyendo tempfiles, autoextend, y uso agregado actual vs. asignado.

# Scope

**En alcance:** configuración y uso agregado de TEMP a nivel instancia/CDB. **Fuera de alcance:** uso de TEMP por sesión individual (eso requeriría `V$SORT_USAGE`/`V$TEMPSEG_USAGE` con detalle de sesión, más cercano a `performance/temp`, Fase 3), causas de uso excesivo de TEMP por SQL específico (Fase 3).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (TEMP típicamente compartido; TEMP tablespace groups posibles). NON-CDB y CDB (desde 12c, TEMP puede ser compartido a nivel CDB o local por PDB según el modo). ASM y Filesystem. Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-TEMP-001`

# Optional evidence

Ninguna.

# Data collection

`DBA_TEMP_FILES` (tempfiles, tamaño, autoextend), `V$TEMPSEG_USAGE` o `DBA_TEMP_FREE_SPACE` (uso agregado actual).

# Diagnostic logic / Decision tree

```text
used_pct = (tamaño_total - espacio_libre) / tamaño_total
IF used_pct >= 90% → finding HIGH
ELIF used_pct >= 75% → finding MEDIUM
IF tempfile sin autoextend y cerca de su capacidad → finding MEDIUM adicional
```

# Normal behavior

`used_pct` con margen razonable, tempfiles con autoextend habilitado o dimensionados generosamente para la carga esperada.

# Abnormal patterns

`used_pct` sostenidamente alto (a diferencia de picos transitorios durante una operación batch conocida); un único tempfile absorbiendo todo el uso mientras otros permanecen vacíos (desbalance).

# Root cause patterns

`ORA-1652` (unable to extend temp segment) correlacionado con `used_pct` cercano a 100% — causa directa, sin necesidad de correlación adicional.

# Correlation rules

Cruzar con `oracle/jobs` (un job batch con sort/hash join grande explicaría un pico de uso de TEMP) y, en fases futuras, con `performance/temp` para atribuir el uso a SQL específico.

# False positives

Un pico de uso de TEMP durante una ventana batch conocida y declarada por el DBA no es un finding — es esperado. Sólo el uso *sostenido* fuera de esas ventanas es relevante.

# Confidence model

`FACT` para el uso actual. `HYPOTHESIS` para atribuir la causa a una carga específica sin evidencia de sesión/SQL (fuera de alcance de este skill en Fase 2).

# Findings

```yaml
finding_id: FND-...
category: temp
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|HYPOTHESIS
impact: string
recommendations: [REC-...]
```

# Recommendations

Ampliar tempfile o habilitar autoextend con `MAXSIZE` razonable — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar espacio físico disponible
command:    ALTER TABLESPACE TEMP ADD TEMPFILE '<path>' SIZE <n> AUTOEXTEND ON MAXSIZE <n>;
expected_result: used_pct baja por debajo del umbral
rollback:   no aplica reducción directa; considerar ALTER TABLESPACE ... SHRINK SPACE si se sobre-dimensionó
postcheck:  Q-ORA-TEMP-001 re-ejecutada confirma used_pct esperado
```

# Version differences

`ALTER TABLESPACE TEMP SHRINK SPACE` disponible desde 11g (antes, requería recrear el tempfile). Sin otras diferencias estructurales relevantes.

# RAC considerations

TEMP suele ser compartido entre todas las instancias — un pico de uso puede originarse en cualquier instancia; sin distribución por sesión (fuera de alcance de este skill), no se puede atribuir a una instancia específica en Fase 2.

# Multitenant considerations

Desde 12c, el modo de TEMP (compartido a nivel CDB vs. local por PDB) afecta la interpretación — este skill reporta el modo detectado y ajusta el `container_scope` de su evidencia en consecuencia.

# Standby considerations

TEMP no se aplica desde el redo de Data Guard — cada standby gestiona su propio TEMP independientemente del primary; el uso puede diferir significativamente y eso es normal.

# Security

Read-only, `SELECT` sobre `DBA_TEMP_FILES`/`V$TEMPSEG_USAGE`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/tablespaces`, `oracle/undo`, `capacity/temp`.

# Escalation

Uso sostenidamente alto sin ventana batch que lo explique escala a `oracle-performance-analyst` (Fase 3) para atribución a SQL específico.

# Examples

Ver `tests/fixtures/19c-standalone-cdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto bajo.

# Tests

`tests/test_oracle_core_temp.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
