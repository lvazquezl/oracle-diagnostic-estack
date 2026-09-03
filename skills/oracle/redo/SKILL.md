---
name: redo
display_name: "Redo Configuration"
id: oracle/redo
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar configuración de redo logs: número de grupos, tamaño, multiplexado (miembros por grupo), y frecuencia reciente de log switches, detectando configuración que genere switches excesivamente frecuentes.

# Scope

**En alcance:** configuración estática de grupos/miembros, tamaño, y frecuencia de switch reciente. **Fuera de alcance:** análisis de espera de `log file sync`/`log file parallel write` (eso es `performance/io`, Fase 3), Standby Redo Logs (`dataguard/srl`, no profundizado en Fase 2).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (grupos de redo son por thread/instancia). NON-CDB y CDB. ASM y Filesystem. Primary (foco principal — en standby se aplica redo recibido, no se generan switches locales de la misma manera).

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-REDO-001`

# Optional evidence

- `Q-ORA-REDO-SWITCH-FREQ-001` (frecuencia de switches en una ventana reciente, vía `V$LOG_HISTORY`)

# Data collection

`V$LOG` (grupo, tamaño, estado, thread#), `V$LOGFILE` (miembros por grupo, estado), `V$LOG_HISTORY` (timestamps de switches recientes, ventana acotada).

# Diagnostic logic / Decision tree

```text
Para cada grupo: IF count(miembros) < 2 → finding MEDIUM (sin multiplexado)
IF algún miembro en estado distinto de 'ONLINE'/'STALE' esperado (ej. 'INVALID') → finding HIGH
IF frecuencia de switches en la ventana reciente > umbral (ej. > 1 switch/min sostenido) → finding MEDIUM
   (grupos posiblemente subdimensionados para el volumen de generación de redo actual)
```

# Normal behavior

Al menos 2 grupos con al menos 2 miembros cada uno, en discos distintos; frecuencia de switches estable y proporcional a la carga esperada (sin picos sostenidos de switches cada pocos segundos).

# Abnormal patterns

Grupos sin multiplexado; miembro de redo en estado `INVALID`; switches muy frecuentes (indicativo de grupos subdimensionados o de un incremento de carga transaccional no anticipado).

# Root cause patterns

`log file switch (checkpoint incomplete)` reportado como síntoma de performance (por el DBA, ya que este skill no analiza waits) correlacionado con grupos pequeños y switches frecuentes — causa probable: tamaño de grupo insuficiente para el volumen de redo generado.

# Correlation rules

Cruzar con `oracle/archive` (cada switch genera un archivelog; frecuencia de switch impacta directamente el volumen de archivado).

# False positives

Una ventana de switches frecuentes coincidente con una carga batch conocida y declarada por el DBA no es necesariamente un finding de configuración — puede ser comportamiento esperado bajo esa carga puntual.

# Confidence model

`FACT` para configuración y conteo de switches. `OBSERVATION`/`HYPOTHESIS` para la interpretación de "grupos subdimensionados" sin conocer el patrón de carga normal del ambiente.

# Findings

```yaml
finding_id: FND-...
category: redo
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|OBSERVATION
impact: string
recommendations: [REC-...]
```

# Recommendations

Agregar miembro a un grupo sin multiplexado; aumentar el tamaño de los grupos de redo si la frecuencia de switch es sostenidamente alta — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar espacio disponible para el nuevo tamaño de grupo; el grupo a modificar no debe estar CURRENT
command:    ALTER DATABASE ADD LOGFILE MEMBER '<path>' TO GROUP <n>;
            -- para redimensionar: ALTER DATABASE ADD LOGFILE GROUP <n+1> ('<path1>','<path2>') SIZE <n>M;
            -- luego DROP LOGFILE GROUP <old> una vez INACTIVE
expected_result: V$LOGFILE muestra el nuevo miembro/grupo; frecuencia de switch se normaliza
rollback:   remover el miembro/grupo agregado si no produce el efecto esperado (grupo debe estar INACTIVE)
postcheck:  Q-ORA-REDO-001 y Q-ORA-REDO-SWITCH-FREQ-001 re-ejecutadas confirman la nueva configuración/frecuencia
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai.

# RAC considerations

Cada instancia (thread) tiene su propio conjunto de grupos de redo — este skill reporta por thread, nunca mezcla grupos de distintos threads como si fueran uno solo.

# Multitenant considerations

Redo es a nivel CDB, no por PDB (los PDBs comparten el redo stream de la CDB) — no varía por contenedor.

# Standby considerations

En Physical Standby, `V$LOG` refleja los grupos de redo *online* del standby (usados sólo si se promueve), distintos de los Standby Redo Logs (`V$STANDBY_LOG`, fuera de alcance de este skill — ver `dataguard/srl` en fases futuras). Este skill no confunde ambos.

# Security

Read-only, `SELECT` sobre `V$LOG`/`V$LOGFILE`/`V$LOG_HISTORY`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/archive`, `oracle/controlfile`.

# Escalation

Frecuencia de switch extrema correlacionada con un incidente de performance reportado escala a `incident-root-cause-analyst` (y, en fases futuras, a `oracle-performance-analyst` para el análisis de espera asociado).

# Examples

Ver `tests/fixtures/19c-standalone-cdb.yaml` (grupo `GROUP 3` sin multiplexado, un solo miembro).

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto bajo.

# Tests

`tests/test_oracle_core_redo.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
