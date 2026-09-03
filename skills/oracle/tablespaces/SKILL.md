---
name: tablespaces
display_name: "Tablespaces"
id: oracle/tablespaces
version: 2.0.0
domain: oracle
status: active
---

# Purpose

Evaluar uso, crecimiento, autoextend y datafiles de todos los tablespaces (excluyendo TEMP/UNDO, cubiertos por skills propios) para detectar riesgo de agotamiento de espacio o configuración fuera de mejores prácticas.

# Scope

**En alcance:** tablespaces permanentes de datos/índices, sus datafiles, autoextend, `MAXSIZE`, y su relación con el storage subyacente (ASM/Filesystem).
**Fuera de alcance:** TEMP (`oracle/temp`), UNDO (`oracle/undo`), forecast de capacidad (`capacity/tablespaces`), contenido de las tablas dentro del tablespace.

# Supported Oracle versions

10g–23ai. `DBA_TABLESPACE_USAGE_METRICS` disponible desde 11g; en 10g se deriva de `DBA_DATA_FILES` + `DBA_FREE_SPACE`. Bigfile tablespaces desde 10g; `MAXSIZE` en unidades ilimitadas (`UNLIMITED`) posible desde 10g.

# Supported OS/platforms

Todas — lógico sobre el diccionario de datos, no depende del OS salvo para el límite físico de tamaño de archivo del filesystem subyacente (informativo, no bloqueante).

# Supported architectures

Standalone y RAC (tablespaces son compartidos a nivel base, no por instancia). NON-CDB y CDB (a nivel CDB$ROOT; detalle por PDB lo cubre `multitenant/storage` en fases futuras — aquí sólo se reporta el `container.type` del Target Profile). ASM y Filesystem (afecta cómo se interpreta autoextend/espacio disponible). Primary y Physical Standby (en standby, sólo lectura de metadata; `DBA_FREE_SPACE` puede no ser representativa si la base está en mount).

# Prerequisites

Requiere Target Profile publicado por `oracle-discovery-analyst` (versión, `storage_mode`, `container.type`, `database_role`, `open_mode`).

# Required evidence

- `Q-DBA-TBS-USAGE-001` (uso agregado por tablespace)

# Optional evidence

- `Q-DBA-TBS-DATAFILES-001` (detalle de datafiles y autoextend)
- `Q-ASM-DG-USAGE-001` (espacio disponible en el disk group ASM subyacente, si `storage_mode = asm`)

# Data collection

Lectura de `DBA_TABLESPACES`, `DBA_DATA_FILES`, `DBA_TABLESPACE_USAGE_METRICS`, `DBA_FREE_SPACE` — todas `V$`/`DBA_*` de diccionario, ninguna tabla de aplicación.

# Diagnostic logic / Decision tree

```text
Para cada tablespace permanente:
  used_pct = used_space / (autoextend ? effective_maxsize : allocated_space)
  IF used_pct >= 90% AND NOT autoextend            → HIGH
  ELIF used_pct >= 90% AND autoextend maxsize alcanzable pronto → MEDIUM (con nota de tendencia)
  ELIF used_pct >= 75%                              → MEDIUM
  ELSE                                               → LOW / no finding
  IF datafile individual cerca del límite físico del tipo de bloque → finding aparte, independiente de used_pct
  IF storage_mode = asm AND disk group subyacente también bajo (evidencia opcional) → escalar severidad
```

# Normal behavior

Tablespaces con `used_pct < 75%`, autoextend habilitado con `MAXSIZE` explícito (no `UNLIMITED` sin monitoreo), y sin datafiles cerca del límite físico.

# Abnormal patterns

`used_pct >= 90%` sin autoextend; autoextend `UNLIMITED` sobre un filesystem con poco espacio libre real (mismatch entre "espacio lógico ilimitado" y "espacio físico real"); un único datafile absorbiendo todo el crecimiento mientras otros del mismo tablespace permanecen estáticos (posible desbalance de I/O, señal para `oracle/diagnostics` o futuro `oracle-performance-analyst`).

# Root cause patterns

`ORA-01653`/`ORA-01654`/`ORA-01688` correlacionados con `used_pct` histórico ascendente sin intervención — causa probable: crecimiento de datos no anticipado o ausencia de política de archivado/purga. Ver `knowledge/errors/ora/ORA-01653-tablespace-full.md`.

# Correlation rules

Cruzar con `os-platform-analyst`/`asm/capacity` (fases futuras) para confirmar si el límite real es lógico (MAXSIZE) o físico (espacio en disco/disk group). Cruzar con `oracle/jobs` si un job de carga masiva coincide temporalmente con el crecimiento.

# False positives

Un tablespace con `used_pct` alto pero `autoextend` con `MAXSIZE` muy por encima del uso actual y espacio físico confirmado disponible no es un finding `HIGH` — es `LOW`/informativo. Un bigfile tablespace recién creado con pre-allocation grande no es "casi lleno" aunque el `used_pct` inicial parezca alto si el tamaño fue deliberado.

# Confidence model

`FACT` para el uso actual leído directamente. `PROBABLE_CAUSE` cuando el agotamiento de espacio se correlaciona con un error `ORA-01653`/`ORA-01654`/`ORA-01688` reportado por el DBA en la misma ventana. `UNDETERMINED` si el target es standby en mount y no expone `DBA_FREE_SPACE` útil.

# Findings

```yaml
finding_id: FND-...
category: tablespaces
severity: LOW|MEDIUM|HIGH
title: "Tablespace <name> near capacity"
observation: "used_pct=92%, autoextend=false"
evidence_refs: [EVD-...]
interpretation: string
confidence: FACT|PROBABLE_CAUSE|UNDETERMINED
impact: "Riesgo de ORA-01653 en escrituras futuras"
recommendations: [REC-...]
```

# Recommendations

Ampliar datafile existente, habilitar/ajustar autoextend con `MAXSIZE` razonable, o agregar datafile nuevo — siempre `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar espacio físico disponible en filesystem/disk group ASM subyacente
command:    ALTER TABLESPACE <name> ADD DATAFILE '<path>' SIZE <n> AUTOEXTEND ON MAXSIZE <n>;
            -- o: ALTER DATABASE DATAFILE '<path>' AUTOEXTEND ON MAXSIZE <n>;
expected_result: used_pct baja por debajo del umbral, autoextend cubre el crecimiento proyectado
rollback:   no aplica reducción de datafile (Oracle no permite shrink por debajo del high-water mark
            sin reorganización); rollback = revertir autoextend a su config anterior si se desea
postcheck:  Q-DBA-TBS-USAGE-001 re-ejecutada muestra used_pct dentro de rango esperado
```

# Version differences

Bigfile tablespaces (10g+); `DBA_TABLESPACE_USAGE_METRICS` (11g+, antes derivar de `DBA_FREE_SPACE`); PDB-level storage quotas (12c+, no evaluado aquí, ver `multitenant/storage` en fases futuras).

# RAC considerations

Ninguna diferencia — tablespaces son compartidos a nivel base de datos, visibles idénticamente desde cualquier instancia.

# Multitenant considerations

En CDB, este skill opera a nivel de la conexión actual (`CDB$ROOT` o un PDB específico según `container.type` del Target Profile); no agrega tablespaces de todos los PDBs en una sola pasada — eso requeriría iterar por PDB, fuera de alcance de Fase 2 (ver `oracle-multitenant-analyst`, no profundizado aún).

# Standby considerations

En Physical Standby en mount, `DBA_FREE_SPACE` puede no reflejar el estado real hasta que la base esté abierta read-only; el finding se marca `confidence: UNDETERMINED` en ese caso, nunca se asume el mismo estado que en Primary.

# Security

Read-only; no requiere privilegios más allá de `SELECT` en las vistas de diccionario listadas. Nombres de tablespace pueden revelar nombres de aplicación — enmascarados según política si el DBA no autoriza lo contrario.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/temp`, `oracle/undo`, `capacity/tablespaces`, `asm/capacity`.

# Escalation

Severidad `HIGH` en producción sin autoextend escala a `change-advisor` (propuesta de ampliación manual) y opcionalmente a `capacity-analyst` para forecast.

# Examples

Ver `tests/fixtures/19c-standalone-cdb.yaml` (tablespace `USERS` al 92% sin autoextend → finding `HIGH`).

# Data sensitivity / Context budget

Sensibilidad MEDIA (nombres); presupuesto bajo (una consulta agregada por tablespace, sin necesidad de AWR).

# Tests

`tests/test_oracle_core_tablespaces.sh`, `tests/test_no_write_operations.sh`, `tests/test_application_data_blocked.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 1 (Foundation) | Materializado como ejemplo representativo del dominio `oracle`. |
| 2.0.0 | Fase 2 (Oracle Core) | Reestructurado a `skills/oracle/tablespaces/SKILL.md` + `manifest.yaml`. Documentación completa (30 secciones), decision tree explícito, patrones normal/anormal/root-cause/falsos-positivos, DBA command generation, consideraciones RAC/multitenant/standby. |
