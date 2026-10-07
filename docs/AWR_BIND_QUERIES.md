# Consultas AWR con ventana: deltas en lugar de acumulados

`/change query|compatibility` — `CHG-ESTACK-AWR-BIND-QUERIES-001`. Rama `change/awr-bind-queries` sobre `main` (`83427df`, `v0.26.0-awr-licensed`).

## Por qué

Al construir el lote B4 (`docs/AWR_LICENSED.md`) aparecieron defectos en las dos consultas AWR con ventana (`:window_start`, `:window_end`) que usan los skills `performance/*` y la ruta humana:

| Query | Defecto | Efecto |
|---|---|---|
| `Q-PERF-WAIT-AWR-001` 2.2.0 | `SUM` de `time_waited_micro_fg` de todos los snapshots de la ventana | Los valores son acumulados desde el arranque: con N snapshots, la misma espera se cuenta hasta N veces |
| | Variante V1 (10.2–11.2) con `time_waited_micro_fg` | La columna no existe en 10g; en 10.2 la query fallaba |
| | Join con `DBA_HIST_SNAPSHOT` sin `dbid` | Con AWR importado de otra base, una fila podía emparejarse con un snapshot ajeno con el mismo `snap_id` |
| `Q-PERF-DBTIME-001` 1.0.0 | Devolvía el valor acumulado de cada snapshot | Los skills y sus fixtures lo leen como carga del intervalo |
| | `(end_interval_time - begin_interval_time) * 86400` | La resta de `TIMESTAMP` da un `INTERVAL`; multiplicarlo da otro `INTERVAL`, no segundos |
| | Join sin `dbid` | Igual que arriba |

El validador estático no detectó el caso de 10g porque `time_waited_micro_fg` no estaba en `RISKY_COLUMNS`. El registro del diccionario ya lo anotaba como hueco conocido.

## Corrección

| Query | Versión | Cambio |
|---|---|---|
| `Q-PERF-WAIT-AWR-001` | 3.0.0 | `MAX − MIN` por `dbid`, instancia, arranque (`startup_time`) y evento, sumado después por instancia y evento; `dbid` en el join. Variantes: V1 10.2 con `time_waited_micro` (foreground + background, dicho en la etiqueta), V2 11.1–11.2 con `_fg` y `ROWNUM`, V3 12.1+ con `_fg`, `FETCH FIRST` y `con_dbid = dbid` |
| `Q-PERF-DBTIME-001` | 2.0.0 | Delta por snapshot con `LAG … PARTITION BY dbid, instance_number, startup_time`, `elapsed_sec` numérico vía `CAST … AS DATE`, `snap_id` y `dbid` en el join. V1 10.2–11.2 y V2 12.1+ con `con_dbid = dbid` |

Las columnas de salida se conservan (`DBTIME-001` agrega `snap_id`). La ventana tiene la misma semántica que un reporte AWR: entre el primer y el último snapshot cuyo `end_interval_time` cae en `[window_start, window_end]`. El intervalo que termina en el primer snapshot no se cuenta; para incluirlo, abre la ventana un snapshot antes.

## Guardas nuevas

- `tests/test_sql_static_validator.sh`: `time_waited_micro_fg` (11.0) y `con_dbid` (12.1) se agregan a `RISKY_COLUMNS`. Todo el catálogo pasa.
- `tests/test_awr_cumulative_counters_use_deltas.sh` (nuevo) revisa toda query de `queries/performance/` que lea `DBA_HIST_SYS_TIME_MODEL` o `DBA_HIST_SYSTEM_EVENT`, bloque por bloque, y exige:
  - no hacer `SUM` de contadores acumulados;
  - particionar cada `LAG` por `startup_time`, o hacer `MAX − MIN` agrupado por `startup_time`;
  - incluir `dbid` en el join con `DBA_HIST_SNAPSHOT`;
  - no multiplicar `INTERVAL`s por 86400;
  - no usar `con_dbid` en variantes de antes de 12.1.

  Cubre también las dos queries de B4. Las versiones anteriores de `WAIT-AWR-001` y `DBTIME-001` no pasan.

## Verificación en el lab (`lab-ol8-19c`, 19c, `CDB$ROOT`, 2026-10-06)

Por la ruta humana se generaron las solicitudes `ER-20261007-003643-70d31e` (`Q-PERF-WAIT-AWR-001-V3`) y `ER-20261007-003643-22008f` (`Q-PERF-DBTIME-001-V2`). Ventana: 2026-10-06 de 10:00 a 15:00. Diagnostics Pack confirmado por `REV-DBAMANAGER`. El DBA ejecutó los scripts en el servidor del lab con SQL*Plus y entregó los CSV. `ingest` verificó el hash del SQL renderizado y produjo `EVD-HR-20261007-003643-22008f` (DB time, 5 filas) y `EVD-HR-20261007-003643-70d31e` (esperas, 20 filas), reportados por `REV-DBAMANAGER` el 2026-10-07T02:02Z con la confirmación de licencia en la procedencia:

- **`Q-PERF-DBTIME-001`:** 5 snapshots (94–98). El 94, primero tras el arranque, sale sin delta. Los deltas fueron 0.92/1.25, 0.53/0.83, 0.67/1.12 y 0.69/1.06 s (DB time/DB CPU), con `elapsed_sec` numérico (657, 2224, 3605, 3605, 3608). Coinciden exactamente con los valores crudos de `DBA_HIST_SYS_TIME_MODEL` y con el collector `Q-PERF-AWR-DBTIME-24H-001`.
- **`Q-PERF-WAIT-AWR-001`:** 20 eventos foreground, el mayor `library cache: bucket mutex X` con 0.08 s. `control file sequential read` da 0.01 s foreground, frente a 9.7 s totales en 24 h del collector `Q-PERF-AWR-WAITS-24H-001`. Es coherente: esa espera la generan sobre todo procesos de fondo, que `_fg` excluye. Con la 2.2.0, la misma ventana habría sumado los acumulados de los 5 snapshots, que incluyen todo lo ocurrido desde el arranque.

**Nivel de validación:**
- **Evidencia:** `HUMAN_REPORTED`. Es una observación real, pero no la hizo el e-stack, así que la confianza máxima es `PROBABLE_CAUSE` (`policies/field-validation-policy.md`).
- **Query:** queda `DOCUMENTATION_ONLY` en `config/field-validation-registry.json`. El registro sólo admite corridas observadas por el gateway (`EVR-*`), y estas dos queries tienen binds, así que el gateway no las ejecuta.

La misma lógica de deltas sí está `FIELD_VALIDATED` en los collectors `Q-PERF-AWR-DBTIME-24H-001` y `Q-PERF-AWR-WAITS-24H-001`, y los valores coinciden.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Revisión de las queries AWR con ventana durante `CHG-ESTACK-AWR-LICENSED-001` |
| PROPOSAL | Deltas por arranque, `dbid` en el join, segundos numéricos, V1 propia para 10g y guardas en el validador |
| IMPLEMENT | 2 queries, matriz de compatibilidad (`DBTIME-001` deja `implicit_full_range` y `max: latest`), nota de `views.yaml`, `RISKY_COLUMNS`, prueba nueva referenciada desde las 4 queries AWR |
| TEST | `test_awr_cumulative_counters_use_deltas.sh` 4/4 y rechaza las versiones anteriores; solicitudes de la ruta humana en 19c (V3 y V2) generadas y verificadas por hash |
| SECURITY | Sin cambios de superficie: siguen siendo SELECT de solo lectura con binds tipados y gate de licencia. 7/7 mutaciones detectadas: `SUM` del acumulado, join sin `dbid`, `MAX − MIN` sin arranque, un `LAG` sin arranque, `INTERVAL × 86400`, `_fg` en 10g y `con_dbid` en V1 |
| REGRESSION | 973/973 en macOS (bash 5.3); `generate.py --check` sin drift |
| LAB | CSV del DBA ingeridos: `EVD-HR-20261007-003643-22008f` y `EVD-HR-20261007-003643-70d31e` (`HUMAN_REPORTED`), coinciden con los valores crudos de AWR y con los collectors B4. La query queda `DOCUMENTATION_ONLY` en el registro, que sólo admite corridas del gateway |
| HUMAN REVIEW | Pendiente |
