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

## Validación en el lab

`lab-ol8-19c`, contexto `LAB-OL8-19C-CDBROOT-ASM` (19.32, `CDB$ROOT`, ASM), 2026-11-10, con la cuenta de diagnóstico (`SELECT_CATALOG_ROLE` + `CONTAINER_DATA`): **no hizo falta ningún privilegio nuevo**. Todas las vistas `CDB_*` nuevas existen y son legibles. Todas las respuestas son `REAL` y `SANITIZED`, sin valores descartados; ningún `feature_name` quedó fuera del patrón de término de Oracle.

**Una query falló y se corrigió.** `Q-PERF-WORKAREA-001` devolvió ORA-00937: una subconsulta escalar no correlacionada junto a un agregado sin `GROUP BY`. Ahora agrega en dos vistas en línea (`738baf6`) y la aserción de P18 lo exige. Las otras 10 queries no tienen ese patrón en ninguna variante. La versión corregida corrió con el mismo gateway del lab invocado en local, porque el servidor MCP tenía cargado el catálogo anterior.

| Collector | Filas | Lo que confirma | Evidencia |
|---|---|---|---|
| `Q-ORA-DATABASE-MODE-001` | 1 | `ARCHIVELOG`, sin force logging ni supplemental logging, `READ WRITE`, `ENTERPRISE`, CDB. `block_change_tracking` nulo (ver abajo) | `EVR-6a868972c9a04fe92b696243` / `REQ-24cbf312ac8d` |
| `Q-PERF-AWR-STARTUP-HISTORY-001` | 1 | Un arranque en AWR, hace 438 h, coherente con `Q-CDB-PDB-STATE-001` (PDB abierta hace 438 h); 427 h de historia AWR; una versión | `EVR-3583e12b93e5d99e2d43cf4e` / `REQ-67a1a25bc434` |
| `Q-ORA-SQLPATCH-001` | 2 | RU 39472050 (`RU`, `19.32.0.0.0`) aplicado con `SUCCESS` en el root y en la PDB hace 1184 h: coincide con el `release_update` 19.32 del contexto | `EVR-c806cf5cc1f651f1a71f96ed` / `REQ-2d08fa6c31e0` |
| `Q-ORA-FEATURE-USAGE-001` | 72 | 37 features con uso detectado en el root y 35 en la PDB (RMAN y `ORACLE_LOADER` ya no en uso actual); muestreo hace 0.2 h | `EVR-9c60e5552b71bcbfeb8a4cf4` / `REQ-3c3f17429bf2` |
| `Q-ORA-OPTIMIZER-STATS-001` | 5 | `FIXED`, `ORACLE` y `CUSTOM` (solo en la PDB, 7 tablas, todas con estadísticas). Fixed objects analizados una vez, hace 1171 h | `EVR-99930cef7b5531dd412b3293` / `REQ-c0acf8accc12` |
| `Q-ORA-AUTOTASK-001` | 6 | Los 3 clientes `ENABLED` con 7 ventanas en cada contenedor, sin fallas; último éxito hace 163 h en el root y 0.8 h en la PDB | `EVR-7dbaf76698477d06c64f0a7a` / `REQ-a271bceae784` |
| `Q-ORA-SCHEDULER-STATE-001` | 6 | Solo jobs de Oracle: 6 `DISABLED`, 15–16 `SCHEDULED` y 1 `SUCCEEDED` por contenedor, sin fallas. Ninguna fila `LEGACY_JOB` (variante 19c+, por diseño) | `EVR-866767df79f7dae7ed7039e9` / `REQ-9763d33a8791` |
| `Q-ORA-UNDO-STATS-001` | 1 | Solo el root (ver abajo): 34 intervalos, 18.2 MB generados, consulta más larga de 1850 s, retención ajustada hasta 2750 s, sin ORA-01555 ni robos | `EVR-70921987590dd30e150ebc1c` / `REQ-2074b0defb2d` |
| `Q-ORA-TEMP-HWM-001` | 2 | Root: pico de 17 MB de 130 MB asignados; PDB: 3 MB de 51 MB; autoextend hasta 32 GB | `EVR-22bce098a19c7c33e7ca6053` / `REQ-09f55d9ab523` |
| `Q-PERF-SGA-COMPONENTS-001` | 19 | Buffer cache 1888 MB, shared pool 560 MB, large pool 48 MB, Shared IO Pool 128 MB; sin resize desde el arranque | `EVR-ec5ab22f9749812f2df6c4c5` / `REQ-5e7480f1ee45` |
| `Q-PERF-WORKAREA-001` | 1 | 73 001 ejecuciones óptimas, ninguna one-pass ni multi-pass, PGA cache hit 100 %, pico de PGA 761 MiB | `EVR-9231c0db53ab50616aad3957` / `REQ-ea97c9ba595d` |

**Sondas del diccionario** (regeneradas por este cambio): las 7 confirman todas las vistas y columnas declaradas, incluidas `CDB_REGISTRY_SQLPATCH`, `CDB_FEATURE_USAGE_STATISTICS`, `CDB_AUTOTASK_*` y `CDB_JOBS`. La única diferencia es `STATS$SNAPSHOT` y `STATS$SYSTEM_EVENT` como `VIEW_NOT_FOUND` (Statspack no instalado, igual que antes).

| Sonda | Evidencia |
|---|---|
| `Q-DICT-VERIFY-001` | `EVR-0d4489e553090ab3ea5aa154` / `REQ-1252944d9f04` |
| `Q-DICT-VERIFY-002` | `EVR-c2152ca322a4f20e5afaa827` / `REQ-d82fbe9e407d` |
| `Q-DICT-VERIFY-003` | `EVR-5a4d2651225b138095c9b8ca` / `REQ-647e31e909ea` |
| `Q-DICT-VERIFY-004` | `EVR-f7b8a95710cf9367199f0747` / `REQ-69cae2900960` |
| `Q-DICT-VERIFY-005` | `EVR-4e49b32dc94c700b16a172ed` / `REQ-5afa6223af3f` |
| `Q-DICT-VERIFY-006` | `EVR-4ab95c5caf4f1ff16a0cf5e1` / `REQ-340bae2cee43` |
| `Q-DICT-VERIFY-007` | `EVR-9a2d2629f581dc6684d18b1b` / `REQ-4c6f2471b08c` |

**Límites observados en el lab** (documentados en la query y el skill, sin cambio de SQL):
- **UNDO de las PDB.** `V$UNDOSTAT` leída desde `CDB$ROOT` solo devolvió filas del root, aunque la PDB usa undo local (`local_undo` = 1 en `Q-CDB-PDB-STATE-001`). El UNDO de cada PDB queda `PARTIAL` desde el root.
- **Block change tracking.** `V$BLOCK_CHANGE_TRACKING` no devolvió ninguna fila visible para el usuario de diagnóstico desde `CDB$ROOT`, así que el campo sale nulo. Nulo significa "no observado", nunca `DISABLED`.

**Revisión de los especialistas:**
1. **`oracle-dba-analyst`:**
   - Modo de la base, parche y arranques son coherentes entre sí y con el contexto registrado (19.32, un arranque hace 438 h).
   - **Estadísticas del root.** La recolección automática del root no tiene un éxito en las últimas 48 h (163 h), y el skill lo reporta como MEDIUM. Es un hallazgo real del lab, no del stack: el root abre ventanas pero casi no tiene carga.
   - **Fixed objects.** 156 de 1335 fixed tables siguen sin estadísticas. Es lo esperable tras `GATHER_FIXED_OBJECTS_STATS`, porque algunas `X$` nunca se analizan. Como no son todas, no hay hallazgo.
   - **Jobs.** Los 6 jobs de Oracle `DISABLED` vienen así de fábrica. El skill solo marca jobs propios, así que no hay hallazgo.
   - **UNDO, corregido en este cambio.** La regla del skill comparaba `max_query_seconds` (1850) con `min_tuned_retention_seconds`, que fue 0 en un intervalo, y daba siempre un falso positivo. Ahora compara con `max_tuned_retention_seconds` (2750).
2. **`oracle-performance-analyst`:**
   - Las work areas trabajan en memoria (100 % óptimas). La SGA no cambió de tamaño desde el arranque y el pico de TEMP es mínimo.
   - Los 34 intervalos de UNDO en 24 h indican que el lab estuvo detenido o suspendido gran parte del día. Son datos del lab, no de la query.
   - `OTHER` en los componentes de la SGA agrupa nombres fuera de la lista cerrada, todos de 0 MB. No requiere cambio.
3. **`oracle-security-analyst` (licenciamiento):**
   - Ninguna feature se reporta como incumplimiento.
   - **Variantes `(system)`, corregido en este cambio.** Las variantes como `Partitioning (system)` son uso de Oracle y el skill ya no las marca.
   - **Uso que requiere revisar licencia.** `Real-Time SQL Monitoring` y `Automatic SQL Tuning Advisor` sí quedan `LICENSE_CHECK_REQUIRED`, porque corresponden al Tuning Pack. En el lab solo está confirmado el Diagnostics Pack.
   - **Multitenant.** `Oracle Multitenant` con una sola PDB no requiere licencia en 19c (hasta 3 PDB), pero se reporta igual para revisión.

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
| REGRESSION | 975/975 en macOS (bash 5.3), también después del paso por el lab; 15/15 mutaciones repetidas sobre el árbol final |
| LAB | Las 11 queries y las 7 sondas `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` (18 registros nuevos; el registro pasa de 91 a 109). Sin privilegios nuevos. `Q-PERF-WORKAREA-001` falló con ORA-00937 y se corrigió. La revisión de especialistas corrigió dos reglas de skills (UNDO y licenciamiento) y documentó dos límites (UNDO de las PDB y block change tracking) |
| HUMAN REVIEW | Aprobado: `AUTH-C-NEW-QUERIES-001`, revisor `REV-DBAMANAGER`, `2026-11-11T03:09:41Z`, contra el digest `d3496444…21ef563c02` (`STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`). PROMOTE: pendiente (push, PR y merge, acciones humanas) |
