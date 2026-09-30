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

## Cambios en las queries (aditivos)

Se agregan columnas calculadas en la base; ninguna columna existente se quita ni cambia:

| Query | Versión | Columnas nuevas |
|---|---|---|
| `Q-DISC-INSTANCE-001` | 1.1.0 | `uptime_hours` |
| `Q-ORA-INSTANCE-STATE-001` | 2.1.0 (V1 y V2) | `uptime_hours` |
| `Q-ORA-JOBS-SUMMARY-001` | 1.1.0 | `hours_since_last_start` (UTC, `TIMESTAMP WITH TIME ZONE`) |
| `Q-ORA-DIAGNOSTICS-ADR-001` | 1.1.0 | `hours_since_created` |
| `Q-ORA-ARCHIVE-001` | 1.2.0 | `hours_since_last_archived`, `dest_kind` (`FRA`/`LOCAL`/`SERVICE`/`NONE`), `has_error` |
| `Q-ORA-PARAMETERS-001`, `Q-ORA-SPFILE-001` | 1.1.0 | `value_number`, `value_flag`, `value_version`, `value_keyword` |

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

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Sólo 16 collectors reales en el lab; `/healthcheck` Oracle Core dependía de queries sin collector |
| PROPOSAL | Fábrica gobernada (base de conocimiento + lotes + control de deriva), columnas calculadas aditivas, tipo `parameter_name` |
| IMPLEMENT | `scripts/collector_factory/`, `config/collector-factory/`, `collectors.factory.json` y fixtures generados, carga combinada en `mcp_gateway/catalog.py`, tipo en `mcp_gateway/evidence.py`, alias en `mcp_gateway_lab/oracle_sql.py`, 7 queries, registro de madurez, `targets.fixture.json` |
| TEST | `tests/test_collector_factory.sh` (P18): 12/12 |
| SECURITY | 9/9 mutaciones detectadas: `parameter_name` en cualquier campo, `parameter_name` sin validar, ajuste que cambia tipo, enum ampliado, catálogo generado sin cargar, id duplicado, adaptador que deja pasar columnas crudas, sin tope de filas, alias ignorados en el lab |
| REGRESSION | Suite completa (ver PR) |
| LAB | Pendiente: ejecución real de los 18 collectors en `lab-ol8-19c` y registro en `config/field-validation-registry.json` |
| HUMAN REVIEW | Pendiente |
