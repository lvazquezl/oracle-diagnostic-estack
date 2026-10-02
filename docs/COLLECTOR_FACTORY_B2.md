# Fábrica de collectors — lote B2 (rendimiento)

`/change query|security|documentation` — `CHG-ESTACK-COLLECTOR-FACTORY-B2`. Rama `change/collector-factory-b2` sobre `main` (`5c6e2d3`, `v0.23.0-collector-factory`). La fábrica, sus reglas y el lote B1 están en [COLLECTOR_FACTORY.md](COLLECTOR_FACTORY.md).

## Qué agrega

Son **16 collectors de rendimiento** sin vistas de Diagnostics Pack (ni ASH ni AWR). Con ellos, `/diagnose` y `/healthcheck` de rendimiento obtienen evidencia real sin licencia adicional y sin ejecución del DBA. El catálogo pasa de 39 a 55 collectors.

| Collector | Qué entrega |
|---|---|
| `Q-PERF-WAIT-SYSTEM-001` (nueva) | Top 25 eventos de espera no idle desde el arranque: esperas, timeouts, tiempo y espera promedio en ms |
| `Q-PERF-WAIT-CLASS-001` (nueva) | Tiempo de espera por clase (User I/O, Commit, Concurrency…): primer corte para decidir el especialista |
| `Q-PERF-DBTIME-CURRENT-001` | DB time y DB CPU desde el arranque, y uptime |
| `Q-PERF-IO-001` | Esperas de I/O y commit dominantes |
| `Q-PERF-IO-FILESTAT-001` | Lecturas/escrituras y latencia promedio por datafile, sin rutas y con el tablespace enmascarado |
| `Q-PERF-LIBCACHE-001` | Hit ratios, reloads e invalidaciones de library cache por namespace |
| `Q-PERF-PGA-001`, `Q-PERF-SGA-001`, `Q-PERF-SHAREDPOOL-001` | Memoria: PGA, SGA y pools, y el hit ratio del dictionary cache |
| `Q-PERF-REDO-001` | Redo generado, commits y rollbacks |
| `Q-PERF-HARDPARSE-001` | Parses totales y hard, y aciertos del cache de cursores de sesión |
| `Q-PERF-TOPSQL-CURRENT-001` | Top 20 SQL por tiempo: `sql_id` y métricas, **nunca el texto SQL** |
| `Q-PERF-BLOCKING-001` | Sesiones bloqueadas: sesión que espera y sesión bloqueadora, evento, segundos y `sql_id` |
| `Q-PERF-TEMP-001` | Top 50 consumidores de TEMP: sesión, `sql_id`, tablespace enmascarado y bytes |
| `Q-PERF-PARALLEL-001` | Servidores de ejecución paralela activos por coordinador |
| `Q-ORA-REDO-SWITCH-24H-001` (nueva) | Log switches por hilo en las últimas 24 h, por hora hacia atrás |

## Nuevos tipos de campo

Los dos se pueden conservar (`KEEP`) sólo en campos con nombre fijo, igual que `parameter_name`. El catálogo rechaza cualquier otro uso.

| Tipo | Campos | Forma | Por qué es seguro |
|---|---|---|---|
| `oracle_term` | `event`, `namespace` | Letra inicial; letras, dígitos, espacio y `:_/().,*#$&+-`; hasta 64 caracteres; sin forma de secreto | Es vocabulario de Oracle, como `enq: TX - row lock contention` o `TABLE/PROCEDURE`, no dato del cliente |
| `sql_id` | `sql_id`, `waiter_sql_id` | 13 caracteres base-32 en minúsculas | Identifica un cursor para correlacionar; no contiene texto SQL |

## Correcciones a queries existentes

| Query | Versión | Problema | Corrección |
|---|---|---|---|
| `Q-PERF-HARDPARSE-001` | 1.1.0 | Nunca se podía resolver: el nombre de estadística `execute count` contiene la palabra `execute`, que el guard veta | Se retira ese contador. La proporción parse/ejecución queda fuera |
| `Q-PERF-PARALLEL-001` | 1.1.0 | `V$PX_SESSION` no tiene `SERVER_NAME` ni `SQL_ID` | Usa `SERVER_GROUP`, `SERVER_SET` y `SERVER#` |
| `Q-PERF-IO-FILESTAT-001` | 1.3.0 | Exponía la ruta del datafile; la latencia llamada «ms» estaba en centésimas de segundo; en un CDB cada archivo salía duplicado (el `TS#` se repite por contenedor; visto en el lab) | `file_id` y tablespace (enmascarado) sustituyen a la ruta; `READTIM`/`WRITETIM` se multiplican por 10; el join con `V$TABLESPACE` incluye `con_id` |
| `Q-PERF-TOPSQL-CURRENT-001` | 1.2.0 | En un CDB, el mismo `sql_id` aparecía dos veces, una por contenedor (visto en el lab) | V2 agrega `con_id` |
| `Q-PERF-TEMP-001` | 1.2.0 | `session_addr` es `RAW`, que el adaptador real rechaza | Se retira; `serial#` sale como `serial_no` |
| `Q-PERF-DBTIME-CURRENT-001` | 1.1.0 | ORA-00937: subconsulta escalar junto a agregados sin `GROUP BY` (detectado en LAB19S, 19.30, desde Windows) | `V$INSTANCE` entra en el `FROM` y `uptime_sec` se agrega con `MAX` |
| `Q-ORA-PROCESSES-SUMMARY-001` | 1.0.1 | ORA-00923: faltaba `FROM dual` (LAB19S) | `FROM dual` |
| `Q-ORA-SPFILE-001` | 1.2.0 | Sin parámetros `MODIFIED` no devolvía el conteo (hallazgo del lab en B1) | `FROM dual LEFT JOIN v$parameter`: siempre hay al menos una fila con el conteo |

`Q-ORA-REDO-SWITCH-24H-001` es la versión sin binds, con ventana fija de 24 h, de `Q-ORA-REDO-SWITCH-FREQ-001`. Esta última se conserva para ejecución humana con ventana arbitraria.

## Saneador: nombres largos de owner

B1 dejó un hallazgo del lab: un owner de 20 caracteres o más, como `REMOTE_SCHEDULER_AGENT`, se descartaba como posible secreto antes de enmascararlo.

Ahora un identificador legible en una sola caja, con inicial alfabética y a lo más 25 % de dígitos, no cuenta como token. Se sigue enmascarando igual. Se siguen descartando los secretos estructurados y las palabras con forma de token aleatorio. Un nombre con muchos dígitos, como `APEX_190200_PUBLIC_USR`, se sigue descartando: es el lado conservador.

## Validación en el lab (`lab-ol8-19c`, contexto `LAB-OL8-19C-CDBROOT-ASM`)

Ejecución real vía `oracle-estack-lab`, el 2026-10-02, después del cambio de IP del lab. La identidad observada sigue siendo la misma base: 19.32, PRIMARY, CDB.

1. **Primera pasada (`16ad6cd`):**
   - 14 de los 16 collectors funcionaron, más `Q-ORA-SPFILE-001`.
   - `Q-PERF-IO-FILESTAT-001` duplicaba cada archivo: en un CDB, el `TS#` se repite por contenedor.
   - `Q-PERF-TOPSQL-CURRENT-001` mostraba el mismo `sql_id` una vez por contenedor.
   - `Q-PERF-DBTIME-CURRENT-001` estaba pendiente de la corrección de ORA-00937 (`b40b52b`).
2. **Corrección (`59e24ba`):** se agregó `con_id` al join de `FILESTAT` y a la salida de `TOPSQL`.
3. **Segunda pasada:** los 3 funcionaron. Los demás no cambiaron de SQL, así que vale su primera ejecución.
4. **Tercera pasada (`d7ded1d`):** `Q-PERF-WAIT-CLASS-001` usaba `V$SYSTEM_WAIT_CLASS`, que no está en el diccionario del e-stack (lo detectó la suite). Se reescribió sobre `V$SYSTEM_EVENT`, agregando por clase, y se volvió a correr.

En los 17, el `query_sha256` observado coincide con el SQL versionado. La validación anterior de `Q-ORA-SPFILE-001` (B1) se sustituye, porque su SQL cambió.

| Collector | Request | Evidencia | `query_sha256` | Resultado |
|---|---|---|---|---|
| `Q-PERF-WAIT-SYSTEM-001` | `REQ-a4546b1a1a7e` | `EVR-5f0bc48bed154fa933dc6e16` | `4dc8ca06b413…` | 25 eventos no idle, todos los nombres y clases reconocidos |
| `Q-PERF-WAIT-CLASS-001` | `REQ-e416d4ef28fa` | `EVR-9a531364b7ca1c471d023d95` | `e8e667b1176b…` | 9 clases; tercera pasada (`d7ded1d`) tras reescribirla sobre `V$SYSTEM_EVENT`, la vista registrada en el diccionario |
| `Q-PERF-IO-001` | `REQ-47f3849ea9e6` | `EVR-792cb4f5e8b59694c4501276` | `fbc7c98dc0db…` | 5 eventos |
| `Q-PERF-LIBCACHE-001` | `REQ-173528c85191` | `EVR-e7ebdc8e72f187fe056cc4fc` | `1779829e0348…` | 23 namespaces, todos reconocidos por `oracle_term` |
| `Q-PERF-PGA-001` | `REQ-b1f16ee40221` | `EVR-3b561d8595f384ba0ee24838` | `d8a59ba7d220…` | 1 fila |
| `Q-PERF-SGA-001` | `REQ-9f0dbb3d3e37` | `EVR-c04cfbca7dbf9cb800c4fb72` | `c528f078427a…` | 1 fila; sin java pool en el lab |
| `Q-PERF-SHAREDPOOL-001` | `REQ-50571e599c19` | `EVR-f217f59ca153b8744d631a7d` | `4540a69e6fe8…` | 1 fila |
| `Q-PERF-REDO-001` | `REQ-2142b715fe00` | `EVR-6d235d45e7ee8108879d569f` | `ee1505471083…` | 1 fila |
| `Q-PERF-HARDPARSE-001` | `REQ-f211bd7ed4e1` | `EVR-63ac8b78f783c3c3f9131777` | `714e1a62cc47…` | 1 fila (antes nunca se podía resolver) |
| `Q-PERF-BLOCKING-001` | `REQ-25822068614f` | `EVR-b989ade5761b359d52c0ff5e` | `7a03da91923c…` | 0 filas (sin bloqueos) |
| `Q-PERF-TEMP-001` | `REQ-446cab0d6c29` | `EVR-24e45dbafa67ba65a3c3e5a9` | `4af7ab292ea4…` | 0 filas (sin uso de TEMP) |
| `Q-PERF-PARALLEL-001` | `REQ-19616c825bc1` | `EVR-ade1ddb02384ff898e43515e` | `cdacf7be1f10…` | 0 filas; corre sin ORA-00904 |
| `Q-ORA-REDO-SWITCH-24H-001` | `REQ-6221b83d7d46` | `EVR-b6a198fd90c3b90f22954b55` | `e3be276a2424…` | 0 filas (sin switches en 24 h) |
| `Q-ORA-SPFILE-001` | `REQ-09d02e8c7b52` | `EVR-f728fb81f36f7af863fce608` | `122f705ba6e3…` | 1 fila con `spfile_params_count` 23 (antes, 0 filas) |
| `Q-PERF-DBTIME-CURRENT-001` | `REQ-80f1313e221e` | `EVR-bddc93035864a9586b7962fe` | `a98681aa6966…` | 1 fila, sin ORA-00937 |
| `Q-PERF-IO-FILESTAT-001` | `REQ-d28ac3e2306e` | `EVR-33f83e3a99fe574ef5cd63f4` | `d199dba36daf…` | 8 datafiles únicos (la primera pasada duplicaba cada uno); latencias en ms |
| `Q-PERF-TOPSQL-CURRENT-001` | `REQ-36ba18aabeaf` | `EVR-7bac31205766c410e28b189e` | `8e7fe849b694…` | 20 SQL con `con_id` (1 y 3); `sql_id` y métricas, sin texto |

**Collectors con 0 filas en el lab** (bloqueos, TEMP, paralelo, switches en 24 h): se validó que el SQL corre y su forma, no los valores; el lab no tiene esa actividad.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | `/diagnose` de rendimiento sólo tenía las queries de AWR/ASH (Diagnostics Pack) o ninguna recolección real; 4 queries de rendimiento tenían defectos que impedían resolverlas o ejecutarlas |
| PROPOSAL | Lote B2 de la fábrica, sin licencia; tipos `oracle_term` y `sql_id` ligados a nombres de campo; exención de identificadores legibles |
| IMPLEMENT | 3 queries nuevas, 7 corregidas (2 por la ejecución en LAB19S desde Windows), lote `lots/B2-performance.json`, 64 definiciones nuevas en la base de conocimiento, 16 collectors y fixtures generados, `mcp_gateway/catalog.py`, `mcp_gateway/evidence.py`, matriz de compatibilidad, registro de madurez |
| TEST | `tests/test_collector_factory.sh` (P18): 18/18 |
| SECURITY | 15/15 mutaciones detectadas (9 de B1 y 6 nuevas: `oracle_term` o `sql_id` en cualquier campo, cualquiera de los dos sin validar, exención de identificadores para todo o para nada) |
| REGRESSION | 971/971 en macOS con bash 5.3 (la primera corrida dio 969/971 por una vista no registrada en el diccionario; se reescribió la query y se revalidó en el lab) |
| LAB | 16/16 en real y `Q-ORA-SPFILE-001` revalidada (dos pasadas; ver arriba); `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` |
| HUMAN REVIEW | Pendiente |
