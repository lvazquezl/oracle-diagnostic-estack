# Fábrica de collectors — lote B1 (Oracle Core y tablespaces para `/healthcheck`)

`/change query|security|documentation` — `CHG-ESTACK-COLLECTOR-FACTORY-B1`. Rama `change/collector-factory-b1` sobre `main` (`9ba2a17`, `v0.22.0-observed-context`).

## Para qué sirve

Los agentes obtienen evidencia real **sin que el DBA ejecute nada**: el gateway corre el SELECT certificado con el usuario de diagnóstico de sólo lectura, sanea localmente y entrega `EVD-*`.

Antes de este cambio había 21 collectors, y cada uno se escribía a mano. La fábrica los genera desde las queries certificadas, por lotes, con las mismas reglas de saneamiento. Este lote agrega **18 collectors**, con lo que el catálogo llega a 39.

Lo único que le queda al DBA, una vez por base, es crear el usuario de diagnóstico y dar de alta el target.

## Cómo funciona

| Pieza | Qué es | Quién la cambia |
|---|---|---|
| `config/collector-factory/columns.json` | Base de conocimiento: una definición de campo por nombre de columna (tipo, política, enum, rango, prefijo de alias, ejemplo sintético) | `/change security` |
| `config/collector-factory/lots/*.json` | Lotes: qué queries certificadas se vuelven collectors, sus campos (allowlist), los alias de columna del driver y los ajustes que sólo **acotan** | `/change query` |
| `python3 -m scripts.collector_factory.generate --write` | Genera `mcp_gateway/catalog/collectors.factory.json` y un fixture sintético por collector | Nadie edita la salida a mano |
| `--check` | Control de deriva: lo versionado debe ser exactamente lo generado (`tests/test_collector_factory.sh`) | — |

Reglas que la fábrica y el catálogo hacen cumplir, y que el catálogo vuelve a aplicar al cargar:

- Sólo queries certificadas `active`, `R0` y `READ_ONLY`. `row_limit` no supera el `max_rows` certificado.
- Los campos son una allowlist: lo que no se declara se descarta en el adaptador del lab, antes de salir del driver.
- Un ajuste de lote no puede cambiar tipo ni política, sólo acotar: valores de enum como subconjunto y rangos dentro del rango base.
- Los identificadores (owner, objeto, tablespace, job, instancia, host) nunca son `KEEP`. El texto libre nunca se declara. No se exponen fechas absolutas: las edades se calculan en la base.
- Un `collector_id` presente en el catálogo manual y en el generado se rechaza.

## Cambios en las queries

**La query de un collector selecciona sólo lo que expone.** El adaptador real rechaza toda la respuesta si llega una fecha cruda, un LOB o un texto de más de 256 caracteres. Por eso las columnas calculadas en la base **sustituyen** a las crudas. La primera ejecución en el lab lo confirmó: el enfoque aditivo inicial fue rechazado con `E_RESULT_INVALID`.

| Query | Versión | Cambio |
|---|---|---|
| `Q-DISC-INSTANCE-001` | 1.1.0 | `uptime_hours` sustituye a `startup_time` |
| `Q-ORA-INSTANCE-STATE-001` | 2.1.0 (V1 y V2) | `uptime_hours` sustituye a `startup_time` |
| `Q-ORA-JOBS-SUMMARY-001` | 1.1.0 | `hours_since_last_start` (UTC) sustituye a `last_start_date` |
| `Q-ORA-DIAGNOSTICS-ADR-001` | 1.1.0 | `hours_since_created` sustituye a `creation_time`; se retiran `reason` y `suggested_action` (texto libre); se agrega `message_level` |
| `Q-ORA-ARCHIVE-001` | 1.2.0 | `hours_since_last_archived`, `dest_kind` (`FRA`/`LOCAL`/`SERVICE`/`NONE`) y `has_error` sustituyen a `last_archived`, `destination` y `error` |
| `Q-ORA-PARAMETERS-001`, `Q-ORA-SPFILE-001` | 1.1.0 | `value_number`, `value_flag`, `value_version` y `value_keyword` sustituyen a `value` |
| `Q-ORA-UNDO-001` | 1.0.1 | Se agrega `FROM dual`: la sentencia certificada no era válida (ORA-00923) |

El valor de un parámetro sale sólo en una de cuatro formas: número, `TRUE`/`FALSE`, versión o palabra clave de una lista cerrada. El `value` libre (rutas, servicios, hosts) nunca sale.

## Nuevo tipo de campo `parameter_name`

El nombre de un parámetro de inicialización es vocabulario de Oracle, no dato del cliente, así que se conserva (`KEEP`). Para que nadie lo use para exponer un owner o un host:

- el campo debe llamarse literalmente `parameter_name`;
- el valor debe cumplir `^_{0,2}[a-z][a-z0-9_]{0,79}$`;
- cualquier otro uso lo rechaza el catálogo.

## Collectors del lote B1

| Collector | Qué entrega |
|---|---|
| `Q-DISC-INSTANCE-001` | Instancias: estado, `uptime_hours`; nombre de instancia y host enmascarados |
| `Q-ORA-INSTANCE-STATE-001` | Estado, rol de instancia, shutdown pendiente, `uptime_hours` |
| `Q-ORA-DB-STATE-001` | Flashback, guard, modo y nivel de protección, archivado remoto, estado de switchover |
| `Q-ORA-COMPONENTS-001` | Componentes del registry: id, versión, estado |
| `Q-ORA-CONTROLFILE-001` | Copias del controlfile y uso por sección |
| `Q-ORA-REDO-001` | Grupos de redo: hilo, grupo, tamaño, estado, miembros |
| `Q-ORA-ARCHIVE-001` | Destinos de archivado: tipo, estado, error sí/no, horas desde el último archivado |
| `Q-ORA-PARAMETERS-001` | Parámetros no default, con el valor en forma segura |
| `Q-ORA-SPFILE-001` | Parámetros en SPFILE y modificados desde el arranque |
| `Q-ORA-UNDO-001` | Tablespace de undo (enmascarado), retención configurada y ajustada |
| `Q-ORA-TEMP-001` | Tempfiles: tamaño, autoextend, libre (sin nombres de archivo) |
| `Q-DBA-TBS-USAGE-001` | Uso de tablespaces en porcentaje del máximo |
| `Q-DBA-TBS-DATAFILES-001` | Datafiles: tamaño, autoextend, máximo, incremento (sin nombres de archivo) |
| `Q-ORA-SESSIONS-SUMMARY-001` | Sesiones por estado y tipo, bloqueadas y llamada activa más larga |
| `Q-ORA-INVALID-OBJECTS-001` | Objetos inválidos por owner y tipo, con nombres enmascarados |
| `Q-ORA-OBJECTS-INVENTORY-001` | Conteo de objetos por owner, tipo y estado |
| `Q-ORA-JOBS-SUMMARY-001` | Jobs rotos o fallidos, con fallos y horas desde el último inicio |
| `Q-ORA-DIAGNOSTICS-ADR-001` | Alertas pendientes del servidor por tipo y antigüedad, sin el texto |

**En un CDB conectado a `CDB$ROOT`**, las vistas `DBA_*`/`V$` de este lote describen el contenedor raíz. Para las PDB están `Q-CDB-TABLESPACES-001` y `Q-CDB-TEMP-001`.

Quedan fuera del lote y pasan a lotes siguientes:
- `Q-ORA-REDO-SWITCH-FREQ-001`, porque usa binds de ventana que el gateway aún no acepta;
- `Q-DISC-RAC-001` y `Q-ORA-PARAMETERS-RAC-DIFF-001`, que van en el lote RAC.

## Validación en el lab (`lab-ol8-19c`, contexto `LAB-OL8-19C-CDBROOT-ASM`: 19c RU 19.32, CDB_ROOT, PRIMARY, ASM, OL 8.10)

Ejecución real vía `oracle-estack-lab`, el 2026-09-30:

1. **Primera pasada (`26f1fe7`):**
   - 13 de 18 funcionaron.
   - Rechazados con `E_RESULT_INVALID`: `Q-DISC-INSTANCE-001`, `Q-ORA-INSTANCE-STATE-001` y `Q-ORA-ARCHIVE-001`. La query seguía seleccionando una fecha cruda, y el adaptador rechaza fechas, LOB y textos de más de 256 caracteres.
   - `Q-ORA-UNDO-001` falló con `E_ADAPTER_FAILED`: le faltaba `FROM dual`.
   - `Q-ORA-JOBS-SUMMARY-001`, `Q-ORA-DIAGNOSTICS-ADR-001` y `Q-ORA-PARAMETERS-001` tenían el mismo riesgo latente: fecha cruda o texto de hasta 4000 caracteres.
2. **Corrección (`fd69df5`):** las queries de collectors seleccionan sólo lo que exponen.
3. **Segunda pasada:** los 8 afectados funcionaron. Los otros 10 no cambiaron de SQL, así que vale su primera ejecución.

En los 18, el `query_sha256` observado coincide con el SQL versionado.

| Collector | Request | Evidencia | `query_sha256` | Resultado |
|---|---|---|---|---|
| `Q-DISC-INSTANCE-001` | `REQ-409a8c29ece0` | `EVR-f0af7fe9f99fcdd63b0a0f73` | `d503fb06b01d…` | 1 instancia OPEN; nombre y host enmascarados |
| `Q-ORA-INSTANCE-STATE-001` | `REQ-838d6f3cc2ac` | `EVR-68b1d60658d0062465063c76` | `e5c43b37f5c1…` | 1 instancia, PRIMARY_INSTANCE |
| `Q-ORA-DB-STATE-001` | `REQ-6ca24226f7dd` | `EVR-e5f8ea435d8b17b83b8655c3` | `cab3a527a5e2…` | 1 fila, todos los enums reconocidos |
| `Q-ORA-COMPONENTS-001` | `REQ-c34a6cdc1a40` | `EVR-32fe0e5a9e9598ebdce93e53` | `98c01028c313…` | 15 componentes, todos dentro del enum |
| `Q-ORA-CONTROLFILE-001` | `REQ-080e616be9c1` | `EVR-4e21880bfab48cd6edc6dc45` | `cb49c1ea5084…` | 42 secciones, todas dentro del enum |
| `Q-ORA-REDO-001` | `REQ-7cce3b99def3` | `EVR-75195472f7454f9539f4a0b8` | `8763a2a96df1…` | 3 grupos, 2 miembros cada uno |
| `Q-ORA-SESSIONS-SUMMARY-001` | `REQ-b7ef9e9ef606` | `EVR-dfe9cdc384153260a47c38f4` | `47b7b2512e8e…` | 3 combinaciones estado/tipo, 0 bloqueadas |
| `Q-ORA-UNDO-001` | `REQ-ca58dc0d8135` | `EVR-3d875fbe0b123e26b2a475df` | `9b52336b923e…` | 1 fila tras corregir `FROM dual` |
| `Q-DBA-TBS-USAGE-001` | `REQ-eb7df2862ee2` | `EVR-0e99b29bbcb01e51c1748862` | `689fdf0c30d6…` | 5 tablespaces de root |
| `Q-DBA-TBS-DATAFILES-001` | `REQ-281bc2be3414` | `EVR-8f304a4ae362701b431c9009` | `ba4a75ac76aa…` | 4 datafiles, sin nombres de archivo |
| `Q-ORA-TEMP-001` | `REQ-a1078855bbd4` | `EVR-dd54ef5aa32e812f3bd359bb` | `fd9a33d754ac…` | 1 tempfile |
| `Q-ORA-INVALID-OBJECTS-001` | `REQ-2ef699a3e039` | `EVR-a5c404e15f4041134a7fc5b9` | `de1d96f54323…` | 0 filas (sin objetos inválidos en root) |
| `Q-ORA-OBJECTS-INVENTORY-001` | `REQ-0961a724224b` | `EVR-ebcd0ee2873f575d97d35eb7` | `98770cd8a585…` | 100 filas (truncado al límite del lab); `INVALID_VALUES_DROPPED:1`: un owner de 20+ caracteres se descarta como posible secreto (ver límites) |
| `Q-ORA-JOBS-SUMMARY-001` | `REQ-e4af3b600d70` | `EVR-5d1d6c852251c79dc3c3383d` | `096db036d70a…` | 0 filas (sin jobs con fallas) |
| `Q-ORA-DIAGNOSTICS-ADR-001` | `REQ-a300dead5dca` | `EVR-600bbeea3a68d54d5cedc958` | `95a9791ff8dc…` | 0 filas (sin alertas pendientes) |
| `Q-ORA-ARCHIVE-001` | `REQ-596031747a44` | `EVR-d2a27dcfea18588f3283274d` | `7156d69a5d77…` | 1 destino FRA, VALID, sin error |
| `Q-ORA-PARAMETERS-001` | `REQ-a85d412dab62` | `EVR-76b0a819730699c32b90e4fb` | `8bdf5e4577e7…` | 22 parámetros; `compatible` como versión, 8 como número, 2 como palabra clave, 1 como flag; el resto sin forma segura (rutas, nombres) |
| `Q-ORA-SPFILE-001` | `REQ-cd4de8c684fe` | `EVR-e44cff33e813e26cc5e72a32` | `8aba5d9fe3a4…` | 0 filas (ningún parámetro `MODIFIED` desde el arranque) |

### Límites observados

- **Owners de 20 caracteres o más:** el gateway los descarta como posible secreto antes de enmascararlos (`INVALID_VALUES_DROPPED`). Es conservador: se pierde el alias, nunca se filtra el nombre. Afinarlo requiere un cambio en el saneador de identificadores (`CHG-REQ-IDENT-LONG-NAMES`).
- **`Q-ORA-SPFILE-001`:** sin parámetros `MODIFIED` no devuelve filas, y por eso tampoco el conteo `spfile_params_count`. Separar el conteo queda como `CHG-REQ-SPFILE-COUNT`.
- **Collectors con 0 filas en el lab** (objetos inválidos, jobs, alertas, SPFILE): se validó que el SQL corre y su forma, no los valores. El primer ambiente con datos lo confirmará.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Sólo 16 collectors reales en el lab; `/healthcheck` Oracle Core dependía de queries sin collector |
| PROPOSAL | Fábrica gobernada (base de conocimiento + lotes + control de deriva), columnas calculadas en la base que sustituyen a las crudas, tipo `parameter_name` |
| IMPLEMENT | `scripts/collector_factory/`, `config/collector-factory/`, `collectors.factory.json` y fixtures generados, carga combinada en `mcp_gateway/catalog.py`, tipo en `mcp_gateway/evidence.py`, alias en `mcp_gateway_lab/oracle_sql.py`, 7 queries, registro de madurez, `targets.fixture.json` |
| TEST | `tests/test_collector_factory.sh` (P18): 12/12 |
| SECURITY | 9/9 mutaciones detectadas: `parameter_name` en cualquier campo, `parameter_name` sin validar, ajuste que cambia tipo, enum ampliado, catálogo generado sin cargar, id duplicado, adaptador que deja pasar columnas crudas, sin tope de filas, alias ignorados en el lab |
| REGRESSION | Suite completa (ver PR) |
| LAB | 18/18 en real (dos pasadas; ver arriba), `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` (`config/field-validation-registry.json`) |
| HUMAN REVIEW | Pendiente |
