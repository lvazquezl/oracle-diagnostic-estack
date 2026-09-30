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
| `Q-PERF-IO-FILESTAT-001` | 1.2.0 | Exponía la ruta del datafile; la latencia llamada «ms» estaba en centésimas de segundo | `file_id` y tablespace (enmascarado) sustituyen a la ruta; `READTIM`/`WRITETIM` se multiplican por 10 |
| `Q-PERF-TEMP-001` | 1.2.0 | `session_addr` es `RAW`, que el adaptador real rechaza | Se retira; `serial#` sale como `serial_no` |
| `Q-ORA-SPFILE-001` | 1.2.0 | Sin parámetros `MODIFIED` no devolvía el conteo (hallazgo del lab en B1) | `FROM dual LEFT JOIN v$parameter`: siempre hay al menos una fila con el conteo |

`Q-ORA-REDO-SWITCH-24H-001` es la versión sin binds, con ventana fija de 24 h, de `Q-ORA-REDO-SWITCH-FREQ-001`. Esta última se conserva para ejecución humana con ventana arbitraria.

## Saneador: nombres largos de owner

B1 dejó un hallazgo del lab: un owner de 20 caracteres o más, como `REMOTE_SCHEDULER_AGENT`, se descartaba como posible secreto antes de enmascararlo.

Ahora un identificador legible en una sola caja, con inicial alfabética y a lo más 25 % de dígitos, no cuenta como token. Se sigue enmascarando igual. Se siguen descartando los secretos estructurados y las palabras con forma de token aleatorio. Un nombre con muchos dígitos, como `APEX_190200_PUBLIC_USR`, se sigue descartando: es el lado conservador.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | `/diagnose` de rendimiento sólo tenía las queries de AWR/ASH (Diagnostics Pack) o ninguna recolección real; 4 queries de rendimiento tenían defectos que impedían resolverlas o ejecutarlas |
| PROPOSAL | Lote B2 de la fábrica, sin licencia; tipos `oracle_term` y `sql_id` ligados a nombres de campo; exención de identificadores legibles |
| IMPLEMENT | 3 queries nuevas, 5 corregidas, lote `lots/B2-performance.json`, 64 definiciones nuevas en la base de conocimiento, 16 collectors y fixtures generados, `mcp_gateway/catalog.py`, `mcp_gateway/evidence.py`, matriz de compatibilidad, registro de madurez |
| TEST | `tests/test_collector_factory.sh` (P18): 18/18 |
| SECURITY | 15/15 mutaciones detectadas (9 de B1 y 6 nuevas: `oracle_term` o `sql_id` en cualquier campo, cualquiera de los dos sin validar, exención de identificadores para todo o para nada) |
| REGRESSION | Pendiente (suite completa) |
| LAB | Pendiente: ejecución real de los 16 collectors y revalidación de `Q-ORA-SPFILE-001` |
| HUMAN REVIEW | Pendiente |
