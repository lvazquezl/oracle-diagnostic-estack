# PHASE 13 — MCP Diagnostic Gateway & Local Integration

Baseline: `v0.12.0-change-documentation-knowledge` (`c20c3ee`) · Rama: `phase/13-mcp-diagnostic-gateway` · Tag objetivo (NO creado por el agente): `v0.13.0-mcp-diagnostic-gateway`.

Este documento describe lo que Fase 13 **implementa y ejecuta**: un servidor MCP **local, real, por stdio** (`python -m mcp_gateway`) que ofrece a Claude Code cinco herramientas diagnósticas semánticas y estrictamente controladas, con datos **sintéticos de fixture** por defecto. Invariantes: READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY · EVIDENCE FIRST · AGENTS FOR DOMAINS, SKILLS FOR TASKS.

## 1. Estado real de las integraciones (sin sobrepromesas)

| Integración | Estado | Evidencia |
|---|---|---|
| Servidor MCP stdio (handshake, `tools/list`, `tools/call`, ciclo de vida, límites) | `VERIFIED_FIXTURE` | `tests/test_p13_mcp_protocol.sh` (subproceso real por stdin/stdout) |
| Adaptador `fixture` (datos sintéticos, único habilitado) | `VERIFIED_FIXTURE` | `tests/test_p13_tools_e2e.sh`, `..._sanitization.sh` |
| Adaptador `oracle_sql` (Oracle real vía SQL certificado) | `DISABLED` — no se importa ningún driver, no existe camino de conexión | `tests/test_p13_security.sh` |
| Adaptadores `oracle_diag_file`, `os_readonly` (alert log, OS/GI) | `CONTRACT_ONLY` | ídem |
| Puente Phase 11 (`rca_engine`) → Phase 12 (advisory, candidato KB) | `VERIFIED_FIXTURE` | `tests/test_p13_integration_phase11_12.sh` |
| Cualquier entorno real (Oracle/OS/red) | `NOT_INTEGRATION_TESTED` — no hay laboratorio aprobado ni credenciales dedicadas | §10 |
| Comandos `/healthcheck`, `/diagnose`, `/rca`, `/change`, `/document`, `/knowledge` con orquestación de agente vivo | `CONTRACT_ONLY` (Phase 13 no los habilita; las tools del gateway son insumo, no un runtime de agentes) | `mcp/tool-manifest.md` |

`producción` y `laboratorio` **no** se simulan: `collected_at_utc` es `null` y `provenance` es `{"kind":"FIXTURE","real_observation":false}` en toda respuesta de esta versión.

## 2. Matriz AS-IS → integración Phase 13

| Componente existente | Interfaz concreta | Reutilización en Phase 13 | Brecha cerrada | Prueba | Riesgo |
|---|---|---|---|---|---|
| `mcp/README.md`, `mcp/tool-manifest.md` | diseño Fase 1 (sin servidor) | se conserva como catálogo objetivo; se añade sección Fase 13 | no existía servidor MCP ejecutable | `test_p13_mcp_protocol` | bajo |
| `queries/**/Q-*.md` (Query Contract v2) | front matter + bloque SQL inmutable | el catálogo lee metadatos (R0, `READ_ONLY`, versiones, rol, licencia, límites) y `sha256` del SQL; nunca lo envía ni lo acepta de un cliente | ningún consumidor ejecutable de la metadata | `test_p13_security` (guard SQL) | medio: la ejecución real sigue `DISABLED` |
| `sanitizers/data-classification-policy.md` | KEEP/MASK/HASH/TOKENIZE/DROP | política por campo **ejecutable** (`mcp_gateway/evidence.py`), denegar por defecto | la política era declarativa | `test_p13_sanitization` | medio: heurística de secretos de Phase 11 |
| `rca_engine` (Phase 11) | `sanitize`, `tokenization`, `run_rca`, catálogo de reglas | firmas certificadas/tokens, tokens de target, RCA real | — | `test_p13_integration_phase11_12` | bajo |
| `change_documentation_knowledge` (Phase 12) | `adapt_rca_result`, `build_change_advisory`, `build_kb_candidate`, `safety.*` | advisory `NOT_EXECUTED_BY_ESTACK`, candidato KB sin publicar; lectura estricta y confinamiento de rutas | — | ídem | bajo |
| `config/allowed-targets.example.yaml`, política de identidad | alias sin credenciales | catálogo de destinos JSON por alias (`mcp_gateway/config/targets.fixture.json`) sin material de conexión | no había autorización por destino ejecutable | `test_p13_tools_e2e`, `..._security` | bajo |
| `config/capability-matrix.yaml` | dominios × versiones | nueva fila `mcp-gateway` (PARTIAL) | el gateway no figuraba | `test_capability_matrix_*` | bajo |
| Validador estático SQL (tests de Fase 3–8) | regex/AST sobre `queries/` | el catálogo re-aplica un guard de solo lectura sobre cada bloque cargado | defensa en profundidad | `test_p13_security` | bajo |
| Resolver de variantes (`docs/QUERY_VARIANTS.md`) | declarativo | **no** se reimplementa: el gateway usa `supported_oracle_versions` del front matter; la resolución por variante queda `CONTRACT_ONLY` | declarada como límite | — | medio (declarado) |

## 3. Arquitectura (`mcp_gateway/`, Python stdlib)

```text
stdin ─► server.py (framing, lifecycle, límites) ─► gateway.py (registry estático · schemas estrictos · autorización · presupuesto)
                                                        │
                    catalog.py (colectores certificados, destinos, capacidad) ─► adapters.py (fixture ✔ · reales ✘)
                                                        │ filas NO confiables
                                            evidence.py (validar → política por campo → minimizar → digest → ref opaca → auditoría final)
                                                        │
              bridge.py ─► rca_engine (Phase 11) ─► change_documentation_knowledge (Phase 12)      audit → stderr (sin argumentos)
```

| Módulo | Responsabilidad |
|---|---|
| `common.py` | límites, códigos de error con **mensaje fijo**, estados (`capability_status`, adaptador) |
| `schemas.py` | validador estricto (mismo esquema publicado en `tools/list` y aplicado en `tools/call`); rechaza objetos abiertos al registrar |
| `catalog.py` + `catalog/collectors.json` | allowlist de colectores con política por campo; metadatos y `sha256` de las queries certificadas; destinos; `evaluate_capability` |
| `adapters.py` | `fixture` (confinado, con tamaño y parseo estrictos), stubs `DISABLED/CONTRACT_ONLY`, plazo duro por operación |
| `evidence.py` | saneamiento por campo, sal por sesión, almacén de evidencia sólo saneada con TTL |
| `gateway.py` | tools estáticas, autorización por target/colector/versión/rol/licencia/adaptador/presupuesto, auditoría |
| `bridge.py` | evidencia saneada → RCA → advisory → estado del candidato KB |
| `server.py`, `cli.py`, `__main__.py` | MCP por stdio, entrypoint operador (`--targets`, `--fixtures-dir`, `--audit`) |

**Por qué una implementación de protocolo propia:** no hay SDK MCP instalado y esta fase no instala dependencias desde la red. El transporte es pequeño (JSON-RPC 2.0 por líneas), sin dependencias nuevas, y se prueba con un subproceso real. Versiones de protocolo soportadas: `2025-06-18` (preferida), `2025-03-26`, `2024-11-05`; un cliente con otra versión recibe `2025-06-18` y decide.

## 4. Transporte y protocolo

- `stdout` = sólo mensajes JSON-RPC (una línea, UTF-8 ASCII-escapado, `\n`); `stderr` = auditoría/log sanitizado. Sin listener TCP/HTTP, sin red, sin telemetría.
- Ciclo de vida: `initialize` → respuesta → `notifications/initialized` → `tools/*`. Antes de eso `tools/*` da `-32600`; `ping` funciona siempre; un segundo `initialize` se rechaza.
- Rechazados con texto fijo (sin reflejar la entrada): JSON inválido (`-32700`), lotes (arrays), tipos de `id` inválidos, claves duplicadas, `NaN/Infinity`, campos extra (única excepción: en `tools/call` se acepta la llave reservada MCP `_meta`, sólo como objeto; nunca se inspecciona, registra ni pasa al gateway — `CHG-ESTACK-MCP-META-001`), métodos desconocidos (`-32601`, incluidos `resources/*`, `prompts/*`), parámetros mal formados (`-32602`).
- Límites: 1 MiB por mensaje, profundidad 24, 2000 nodos, respuesta ≤ 256 KiB, ≤ 200 llamadas por sesión, ≤ 200 filas, plazo por operación (≤ 15 s; las llamadas a adaptadores corren con plazo duro y el bucle nunca se bloquea).
- Cierre limpio: EOF en stdin ⇒ exit 0; una línea parcial no cuelga el servidor.

## 5. Herramientas (catálogo v1)

Ninguna acepta SQL, comandos, rutas, URL ni parámetros de conexión; todos los objetos usan `additionalProperties: false`.

| Tool | Entrada | Devuelve |
|---|---|---|
| `diagnostics.list_capabilities` | ninguna | adaptadores y su estado, destinos (alias, habilitado, versión conocida/`UNKNOWN`, capacidad por colector), colectores |
| `diagnostics.describe_collector` | `collector_id` | metadatos certificados (riesgo, límites, versiones, rol/contenedor, licencia, privilegios mínimos, campos y su política) y `sha256` de la query; **nunca** el SQL |
| `diagnostics.collect` | `collector_id`, `target_alias`, `max_rows?` | evidencia saneada y minimizada + `evidence_refs` opacas |
| `diagnostics.get_evidence` | `evidence_ref`, `target_alias` | la misma evidencia saneada; misma sesión y target; nunca raw |
| `diagnostics.analyze_incident` | `target_alias`, `evidence_refs[≤10]` | RCA real (estado autoritativo), hipótesis con contradicciones, recomendaciones `NOT_EXECUTED`, advisory `NOT_EXECUTED_BY_ESTACK`, estado del candidato KB |

Sobre de respuesta común: `status` (`OK|DEGRADED|ERROR`), `tool_id`, `request_id` (aleatorio), `schema_version`, `collector_id`, `target_token` (`TGT-…`, por sesión), `collected_at_utc` (`null` en fixture), `capability_status`, `sanitization_status`, `evidence_refs`, `limitations`, `provenance`, `error{code,message}` fijo. `tools/call` devuelve `content` (texto JSON), `structuredContent` (igual) e `isError`.

### 5.1 Matriz herramienta → colector → capacidad → versión → licencia → permisos → sanitizador → pruebas

| Colector (`collector_id`) | Origen | Versiones (front matter) | Rol / licencia | Permisos mínimos | Campos y política | Estado adaptadores |
|---|---|---|---|---|---|---|
| `Q-DISC-IDENTITY-001` | query certificada | 10g–23ai | ANY / none | `SELECT` sobre `V$INSTANCE`, `V$DATABASE` | `instance_name`,`db_name` MASK; `version`,`database_role`,`cdb`,`open_mode` KEEP | fixture ✔ · oracle_sql DISABLED |
| `Q-ORA-RESOURCE-LIMITS-001` | query certificada | 10g–23ai | ANY / none | `SELECT` sobre `V$RESOURCE_LIMIT` | enum + enteros acotados KEEP | ídem |
| `Q-ORA-PROCESSES-SUMMARY-001` | query certificada | 10g–23ai | ANY / none | `SELECT` sobre `V$PROCESS`, `V$PARAMETER` | enteros KEEP | ídem |
| `Q-ORA-DIAGNOSTICS-ALERTLOG-001` | colector de archivo certificado | 10g–23ai | ANY / none | lectura vía colector certificado | `event_time` KEEP (UTC); `signature` SIGNATURE (certificada o token `SIG-`); `message` **DROP** | fixture ✔ · oracle_diag_file CONTRACT_ONLY |
| `Q-DG-STATS-001` | query certificada | 10g–23ai | **STANDBY** / none | `SELECT` sobre `V$DATAGUARD_STATS` | enum + intervalo KEEP | fixture ✔ · oracle_sql DISABLED |
| `os.get_process_limits` | colector semántico OS (`docs/OS_READONLY_COLLECTOR_MODEL.md`) | todas | ANY / none | lectura de límites del usuario de diagnóstico | número acotado, enum KEEP | fixture ✔ · os_readonly CONTRACT_ONLY |
| `os.get_oracle_process_summary` | colector semántico OS | todas | ANY / none | lectura de estado de procesos | booleano, entero KEEP | ídem |

Autorización por llamada (todas fallan cerradas): destino registrado y habilitado → colector permitido para ese destino → adaptador realmente ejecutable → **versión** (`ENVIRONMENT_UNKNOWN` si el destino no la declara; `UNSUPPORTED` si la query no la cubre) → **rol** (`NOT_APPLICABLE`/`ENVIRONMENT_UNKNOWN`) → **licencia** (`LICENSE_RESTRICTED` salvo `CONFIRMED` declarada) → presupuesto de llamadas/filas por destino y por sesión. Un alias registrado **no** es una autorización.

## 6. Modelo de amenazas y controles

**Activos:** integridad de los sistemas administrados (nada se escribe ni se ejecuta), confidencialidad de datos/identificadores, integridad de las conclusiones (RCA, advisory), disponibilidad del servidor local.
**Actores:** el modelo (puede ser manipulado por datos), datos no confiables (logs, filas, nombres, fixtures), un usuario local malicioso o un proceso hermano (stdio local **no** autentica a la persona), configuración alterada.
**Fronteras de confianza:** cliente MCP ⇄ servidor (JSON-RPC), servidor ⇄ adaptador (filas **no confiables**), servidor ⇄ archivos (catálogo/fixtures), servidor ⇄ motores Phase 11/12 (importación local).

| Amenaza | Control (y prueba) |
|---|---|
| SQL/shell/ruta/URL/DSN en `tools/call` | no existe parámetro que los admita; esquemas cerrados con patrones anclados y longitud máxima (`test_p13_tools_e2e`, `..._security`) |
| Colector/alias no registrado, traversal en ids | gramática estricta + allowlist + `confine()` (sin `..` ni enlaces) |
| Secretos en cualquier campo/subcampo/firma/clave | denegar por defecto por campo, tipos estrictos, `DROP` de texto libre, firmas certificadas o token, auditoría final estructurada (`test_p13_sanitization`) |
| Inyección de instrucciones en datos | los datos no cambian el catálogo ni la política; el texto libre no tiene camino al modelo; pruebas de inercia |
| Referencias adivinables/enumerables, cross-target/cross-sesión | `EVR-` + 96 bits aleatorios, atadas a (sesión, target), respuesta idéntica para «no existe/otro ámbito/expirado» |
| Adaptador lento/colgado, resultado malformado | plazo duro (`E_TIMEOUT`), forma validada (`E_RESULT_INVALID`), excepciones → código fijo |
| Mensajes enormes/profundos/anchos/basura, lifecycle roto | límites y rechazo sin procesar; el servidor sigue vivo |
| Habilitar un adaptador real por flag/env/archivo | no existe la opción; adaptadores reales sin código de conexión; `evaluate_capability` sólo admite `VERIFIED_FIXTURE/VERIFIED_LAB` |
| Filtración por errores, `stderr` o auditoría | mensajes fijos, sin trazas, auditoría con claves fijas y sin argumentos |
| Defensas desactivadas silenciosamente | 11 controles de mutation testing (`test_p13_mutation_controls`) |

**Riesgos residuales (no resueltos «mágicamente»):** stdio local no autentica a la persona; un equipo comprometido o credenciales externas quedan fuera de alcance; la sanitización de Phase 11 es heurística y sesgada a sobre-redactar; el SQL certificado no se ejecuta hoy (los adaptadores reales no existen); la resolución por variantes de query es `CONTRACT_ONLY`; una aprobación local de KB sigue siendo `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`.

## 7. Política de sanitización, privacidad y retención

- **Dato → modelo:** `filas no confiables → validación de forma → política por campo → minimización (filas) → digest → referencia opaca → auditoría estructurada final`. Un campo no declarado se descarta; sólo se informa un **conteo** (`FIELDS_DROPPED_BY_POLICY:N`), nunca su nombre ni valor.
- `MASK` → alias estable por sesión/destino (`inst-A1`); `HASH`/`TOKENIZE` → HMAC con **sal aleatoria por sesión** (no reversible, no correlaciona entre sesiones ni destinos); `SIGNATURE` → literal sólo si es un código certificado (gramática tipada o catálogo), si no `SIG-…`; identificadores con homoglifos o forma de secreto se descartan.
- Números/booleanos/fechas conservan tipo y valor dentro de rangos declarados; `NaN/Infinity`, booleanos como enteros, anidados y desbordes se descartan; las marcas de tiempo se normalizan a UTC.
- **Raw:** nunca se almacena ni se entrega por MCP (ni siquiera en fixture). **Retención:** sólo evidencia saneada, en memoria, TTL 1 h, máx. 300 entradas, se borra al cerrar la sesión; no hay persistencia en disco. Borrado temprano: cerrar el servidor.
- **Límite de inferencia:** «MCP local» **no** significa modelo local. La evidencia saneada que recibe Claude Code puede procesarse fuera del equipo según la configuración real del producto; por eso se minimiza antes de salir.

## 8. Ejemplos E2E (sintéticos y saneados)

```text
→ {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"demo","version":"0"}}}
← {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"oracle-diagnostic-estack-mcp-gateway","version":"1.0.1"},…}}
→ {"jsonrpc":"2.0","method":"notifications/initialized"}
→ {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"diagnostics.collect","arguments":{"collector_id":"Q-ORA-PROCESSES-SUMMARY-001","target_alias":"fixture-primary-19c"}}}
← …"structuredContent":{"status":"OK","capability_status":"SUPPORTED","collected_at_utc":null,"provenance":{"kind":"FIXTURE","real_observation":false},
   "evidence_refs":["EVR-<24 hex>"],"evidence":{"columns":["process_count","processes_limit"],"rows":[{"process_count":188,"processes_limit":200}],"row_count":1,"digest":"<sha256>"},…}
→ …"arguments":{"collector_id":"Q-DISC-IDENTITY-001","target_alias":"fixture-primary-19c","sql":"select 1 from dual"}
← …"isError":true,"structuredContent":{"status":"ERROR","error":{"code":"E_ARGS_INVALID","message":"arguments do not satisfy the tool schema"},…}   (la entrada no se refleja)
```

Cadena Phase 11/12: `collect` (`Q-ORA-DIAGNOSTICS-ALERTLOG-001`, `os.get_process_limits`, `os.get_oracle_process_summary`) → `analyze_incident` ⇒ `rca.completeness: CONFIRMED` (`rca_engine` decide), recomendación `execution_status: NOT_EXECUTED`, advisory `NOT_EXECUTED_BY_ESTACK` con `review_status: REVIEW_REQUIRED`, candidato KB `CANDIDATE` (no publicado). Con una sola fuente o con evidencia contradictoria el estado **no** llega a `CONFIRMED` y el candidato queda `REJECTED`.

## 9. Configuración de Claude Code, arranque/parada y diagnóstico

Ejemplo **sin credenciales** (`mcp/claude-code.mcp.example.json`, o `python -m mcp_gateway --print-claude-config`): comando `python -m mcp_gateway`, `cwd` = su checkout (marcador `<ABSOLUTE_PATH_TO_YOUR_CHECKOUT_OF_THE_REPOSITORY>`). **No se modifica ninguna configuración real**; cópielo usted mismo.

- Arranque manual de prueba: `python -m mcp_gateway --version` / `--print-claude-config`; el servidor real espera mensajes por stdin.
- Parada: cerrar stdin (el cliente lo hace al terminar) ⇒ exit 0.
- Diagnóstico: `stdout` sólo protocolo (si algo ilegible aparece, es un defecto); líneas `AUDIT {…}` y errores de arranque van a `stderr`; `--audit off` silencia la auditoría. Arranque rechazado ⇒ exit 2, `stdout` vacío y el texto fijo `startup refused` (revise `--targets`/`--fixtures-dir`).
- Plataformas: verificado en **Windows (Git Bash) con Python 3.13**; Linux/macOS **no probados** en este entorno (código sin dependencias de plataforma; codificación UTF-8 con salida ASCII-escapada y `\n`).

## 10. Habilitar un target real (procedimiento humano — NO ejecutado)

No hay laboratorio aprobado. Antes de cualquier integración real, un humano debe: (1) aprobar por escrito el destino y el alcance; (2) proveer una cuenta diagnóstica dedicada de mínimo privilegio y un mecanismo externo de secretos (nunca en `tools/call`, flags ni archivos del repo); (3) implementar y **revisar por `/change`** un adaptador que ejecute únicamente el SQL certificado inmutable con binds tipados, límites y timeout, verificando identidad/rol/CDB-PDB/versión de la sesión y abortando ante un contexto inesperado; (4) certificar el colector contra el resolver de variantes y las licencias; (5) probarlo en un laboratorio aprobado (`VERIFIED_LAB`) con evidencia; (6) sólo entonces cambiar el estado del adaptador por un cambio de código revisado. Hasta entonces: `NOT_INTEGRATION_TESTED`.

## 11. Rollback manual del gateway

No modifica sistemas administrados. Para retirarlo: quite la entrada `oracle-diagnostic-estack` de su configuración MCP de Claude Code; para revertir el código, revierta manualmente el merge de Phase 13 (o vuelva al tag `v0.12.0-change-documentation-knowledge`). No hay estado persistente que limpiar.

## 12. Pruebas

Siete suites `tests/test_p13_*.sh` (unit, protocolo MCP real, tools E2E, sanitización, seguridad, integración Phase 11/12, mutation controls) sobre fixtures sintéticos; sin Oracle, red ni acceso al host. Los conteos se toman del runner real (`tests/run-all.sh`) y se reportan en el informe de la fase.
