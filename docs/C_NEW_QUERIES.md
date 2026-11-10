# Lote C: queries nuevas para los dominios sin evidencia

`/change query|skill|security|compatibility|documentation` — `CHG-ESTACK-C-NEW-QUERIES-001`. Rama `change/c-new-queries` sobre `main` (`be64435`).

Origen: el plan de lotes acordado con el DBA (C: estadísticas del optimizer, feature usage, SQL patches, `log_mode`/edición, historial de arranques, undo/TEMP/memoria/Scheduler). En el assessment `ANA-20261020-001` estos dominios quedaron `NOT_ASSESSED` o `PARTIAL` porque no había ninguna query certificada que los cubriera; a diferencia de B7 y B8, no alcanzaba con exponer queries existentes.

## Queries nuevas

Todas son 1.0.0 y agregan en la base: no sale ningún nombre de tabla, esquema, job, ventana ni archivo, ningún texto libre ni fecha absoluta.

| Query | Dominio del assessment | Qué entrega | Versiones |
|---|---|---|---|
| `Q-ORA-DATABASE-MODE-001` | A identidad, L redo | `log_mode`, `force_logging`, supplemental logging mínimo, `open_mode`, edición (palabra cerrada del banner), CDB, block change tracking; `db_unique_name` enmascarado | 10.2–23ai |
| `Q-PERF-AWR-STARTUP-HISTORY-001` | A identidad | Por instancia, desde AWR: arranques registrados, en 7 y 30 días, horas desde el último, versiones distintas y horas de historia AWR | 10.2–23ai, **Diagnostics Pack** |
| `Q-ORA-SQLPATCH-001` | W componentes | Historial de datapatch por contenedor: acción, estado, tipo de parche (18c+), versión destino (18c+) y horas desde la acción | 10.2–23ai |
| `Q-ORA-FEATURE-USAGE-001` | Z licenciamiento | Features con uso detectado por contenedor: usos, uso actual, horas desde el primer y el último uso y desde el último muestreo | 10.2–23ai |
| `Q-ORA-OPTIMIZER-STATS-001` | X optimizer | Por contenedor y tipo de dueño (fixed objects, Oracle, propios): tablas sin estadísticas, obsoletas, bloqueadas y antigüedad del análisis | 10.2–23ai |
| `Q-ORA-AUTOTASK-001` | X optimizer, V Scheduler | Tareas de mantenimiento automático por contenedor: estado, ventanas habilitadas, ejecuciones y fallas en 7 días, horas desde el último éxito | 11.1–23ai |
| `Q-ORA-SCHEDULER-STATE-001` | V Scheduler | Jobs del Scheduler y de `DBMS_JOB` por contenedor, tipo de dueño y estado (incluye `DISABLED` y `BROKEN`): cantidad, con fallas, peor antigüedad | 10.2–23ai |
| `Q-ORA-UNDO-STATS-001` | K UNDO | Últimas 24 h de `V$UNDOSTAT` por contenedor: undo generado, consulta más larga, retención ajustada, ORA-01555, falta de espacio, robos de extents y reparto activo/no expirado/expirado | 10.2–23ai |
| `Q-ORA-TEMP-HWM-001` | J TEMP | Por contenedor y tablespace temporal: pico usado desde el arranque, ordenamiento más grande, tamaño asignado y máximo con autoextend | 10.2–23ai |
| `Q-PERF-SGA-COMPONENTS-001` | C memoria | Componentes dinámicos de la SGA (incluye java y streams pool): tamaños y operaciones de resize desde el arranque | 10.2–23ai |
| `Q-PERF-WORKAREA-001` | C memoria | Work areas óptimas, one-pass y multi-pass, PGA cache hit, bytes extra y pico de PGA | 10.2–23ai |

## Decisiones de diseño

- **Por contenedor desde 12.1.** Las variantes 12.1+ leen `CDB_*` (o `V$` con `CON_ID`), como B5: desde `CDB$ROOT` cada PDB queda visible.
- **Propio u Oracle.** `owner_kind` usa `ORACLE_MAINTAINED` desde 12.1.0.2. Antes, solo `SYS`/`SYSTEM` se clasifican como Oracle y el resto sale `OTHER`, nunca `CUSTOM`.
- **`DBMS_JOB` sin el literal `dbms_`.** El guard de solo lectura rechaza `dbms_` en cualquier parte de la sentencia, también dentro de un literal, y no se relaja. Desde 19c los jobs de `DBMS_JOB` son jobs del Scheduler y aparecen en las dos vistas, así que la variante 19c+ lee solo el Scheduler. Hasta 18c se suma `DBA_JOBS` como `LEGACY_JOB`. Así se implementa la lectura de `DBA_JOBS` que quedó PLANNED en `Q-ORA-JOBS-SUMMARY-001`.
- **`feature_name` es término de Oracle.** Se agrega a `ORACLE_TERM_FIELDS` en `mcp_gateway/catalog.py`, como los nombres de evento o de privilegio. Es el único cambio de seguridad del catálogo. `FEATURE_INFO`, que puede nombrar objetos o esquemas, nunca se selecciona.
- **Uso no es licencia.** El uso detectado se reporta como `LICENSE_CHECK_REQUIRED`, nunca como incumplimiento (`security/licensing-gates`).
- **Historial de arranques con licencia.** Sin licencia no hay una fuente en la base para el historial de arranques: `V$INSTANCE` solo tiene el último arranque, y el alert log es del lote E. Por eso la query usa AWR, vive en la familia AWR (`queries/performance/awr/`, porque Oracle Core no puede depender de un pack opcional: lo exige `tests/test_oracle_core_respects_license_gate.sh`, que la detectó en la primera regresión) y va en un lote propio (CL), con el fixture de `fixture-licensed-19c`, como B4. Sin `diagnostics_pack` confirmado, el collector queda `LICENSE_RESTRICTED`.
- **Edición.** La edición se deriva del banner de `V$VERSION` como palabra cerrada. En 10g/11g Standard Edition el banner no la nombra: sale `UNKNOWN` y nunca se infiere.

## Cambios

**Campos.**
- 76 definiciones nuevas en `config/collector-factory/columns.json`: conteos, horas y MB acotados, y enums cerrados.
- Identificadores enmascarados: `db_unique_name` (alias `dbu`) y `tablespace_name`.
- `open_mode` agrega `READ ONLY WITH APPLY` (Active Data Guard).
- El lote C restringe `state` en `Q-ORA-SCHEDULER-STATE-001` a los estados del Scheduler.

**Skills.**
- Nuevo `oracle/optimizer-statistics` 1.0.0. Es el área 19 de `oracle-dba-analyst` (agente 2.1.0) y entra en `/healthcheck`. Test: `tests/test_oracle_core_optimizer_statistics.sh`.
- 10 skills agregan las queries como evidencia opcional, con su lógica de hallazgos:
  - `oracle/database-state`, `oracle/archive`, `oracle/instance` (historial de arranques AWR), `oracle/components` y `oracle/undo`: 1.1.0.
  - `oracle/jobs`: 1.2.0.
  - `oracle/temp`, `performance/sga`, `performance/pga` y `security/licensing-gates`: 1.1.0.

**Diccionario y compatibilidad.**
- 18 vistas nuevas en `compatibility/oracle-dictionary/views.yaml`, entre ellas:
  - `CDB_REGISTRY_SQLPATCH`, `CDB_FEATURE_USAGE_STATISTICS`, `CDB_TAB_STATISTICS`, `CDB_JOBS`;
  - `CDB_AUTOTASK_*` y `DBA_AUTOTASK_*`;
  - `DBA_HIST_DATABASE_INSTANCE`, `V$SGA_DYNAMIC_COMPONENTS` y `V$SQL_WORKAREA_HISTOGRAM`.
- Columnas en 12 vistas existentes.
- Tres filas nuevas en `V$PGASTAT`.
- Las sondas del diccionario pasan de 5 a 7 (`Q-DICT-VERIFY-006` y `007`). Se registran en el adaptador del lab, en la matriz, en el registro de queries, en el registro de madurez y en el target de fixtures.
- El resolver de 10g no encuentra variante para AutoTask (11.1+).

**Registros.**
- Catálogo: de 101 a 114 collectors (11 queries y 2 sondas).
- Registro de madurez: 182 componentes.
- Matriz de compatibilidad y `queries/REGISTRY.md` actualizados.

**Validaciones en campo retiradas** hasta revalidar en el lab, porque su SQL cambió: las sondas `Q-DICT-VERIFY-001`..`005`. El registro pasa de 96 a 91.

## Riesgos que se verifican en el lab

- **Vistas `CDB_*` no verificadas.** No toda vista `DBA_*` tiene su `CDB_*` (ver la nota de `DBA_USERS_WITH_DEFPWD` en el diccionario). `CDB_REGISTRY_SQLPATCH`, `CDB_FEATURE_USAGE_STATISTICS`, `CDB_AUTOTASK_*` y `CDB_JOBS` se confirman con las sondas `Q-DICT-VERIFY` antes de dar por buena cada query.
- **Privilegios.** Se esperan cubiertos por `SELECT_CATALOG_ROLE` + `CONTAINER_DATA`. Un `ORA-00942` en el lab indica un grant faltante, y se informa con un script para el DBA.
- **Nombres de feature.** Un nombre que no cumpla el patrón de término de Oracle se descarta en el gateway: la fila queda, pero sin `feature_name`. Se revisa cuántos se descartan en el lab.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | `ANA-20261020-001`: X (estadísticas) `NOT_ASSESSED`; A, C, J, K, L, V, W y Z `PARTIAL` por falta de query |
| CHANGE REQUEST | `CHG-ESTACK-C-NEW-QUERIES-001`, tipos `query`, `skill`, `security`, `compatibility` y `documentation` |
| GAP ANALYSIS | Ninguna query certificada cubría estos datos; se crean 11 (arriba) |
| IMPACT ANALYSIS | Catálogo de 101 a 114 collectors; sin privilegio nuevo esperado; una query requiere Diagnostics Pack (gate existente); `feature_name` como término de Oracle; sin tools nuevas; guard de solo lectura sin cambios |
| PROPOSAL | Este documento |
| IMPLEMENT | 11 contratos nuevos; lotes C y CL; 76 campos; diccionario, matriz, registros, target de fixtures; skill nuevo y 10 skills actualizados; sondas del diccionario regeneradas (7) |
| TEST | P18 41/41 (2 casos nuevos); P14 16/16; resolvers 10g–23ai; test del skill nuevo. La primera regresión detectó tres problemas que se corrigieron: el historial de arranques (AWR) en Oracle Core (movido a la familia AWR), el conteo de skills de `oracle` en el registro de madurez (19) y dos pruebas P15 que asumían 5 sondas |
| SECURITY | 15/15 mutaciones detectadas: `FEATURE_INFO`, `DESCRIPTION` de parches, nombres de tabla, papelera contada, `JOB_ACTION`, literal `dbms_`, doble conteo de `DBMS_JOB` en 19c, nombres de ventana, `MAXQUERYID`, nombres de tempfile, texto del banner, `db_unique_name` en `KEEP`, `feature_name` fuera de `ORACLE_TERM_FIELDS`, historial de arranques sin gate de licencia y override de `state` quitado. Dos de ellas (`JOB_ACTION` y banner) pasaron en el primer intento porque el helper del test ignoraba referencias con alias: se endurecieron las aserciones |
| REGRESSION | 975/975 en macOS (bash 5.3) |
| LAB | pendiente |
| HUMAN REVIEW | pendiente |
