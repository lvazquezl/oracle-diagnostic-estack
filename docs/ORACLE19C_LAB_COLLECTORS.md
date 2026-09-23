# CHG-ESTACK-ORA19C-LAB-002 — `Q-ORA-RESOURCE-LIMITS-001` en el adaptador `oracle_sql` de laboratorio

**Tipo:** `/change security|compatibility` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `feature/oracle19c-readonly-lab` · **Depende de:** `CHG-ESTACK-ORA19C-LAB-001` (sin commit, también pendiente de HUMAN REVIEW)
**Estado:** `APPROVED_BY_HUMAN` (`AUTH-ORA19C-LAB-002`, `REV-DBAMANAGER`, `2026-09-23T15:16:57Z`; verificación estructural, no de identidad) e integrado a `main` vía PR #3 (`7eb585f`), versión `0.15.0`. El tag lo crea una persona.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Ninguna política cambia.

## 1. DETECT GAP

`ANA-20260922-002` (assessment del target `lab-ol8-19c`) terminó con 8 de 9 dominios en `INSUFFICIENT_EVIDENCE`. El gateway de laboratorio sólo autoriza `Q-DISC-IDENTITY-001`. Recomendaciones de origen: REC-0001, REC-0002, REC-0003 y REC-0005 (FND-0003, FND-0004).

## 2. CHANGE REQUEST

| Ítem | Origen | Decisión en este CHG |
|---|---|---|
| `Q-ORA-RESOURCE-LIMITS-001` en el lab | REC-0001 | **Implementado** |
| `Q-ORA-PROCESSES-SUMMARY-001` en el lab | REC-0001 | **Descartado por decisión del DBA** (mínimo privilegio, §7). El adaptador no lo implementa y el lanzador rechaza un targets file que lo pida |
| `Q-ORA-DIAGNOSTICS-ALERTLOG-001` en el lab | REC-0001 | **Diferido** → `CHG-REQ-LAB-ALERTLOG` |
| Tablespaces, parámetros, PDB, RMAN, seguridad | REC-0002 | **Diferido** → `CHG-REQ-LAB-DOMAINS` (lotes por dominio) |
| Contexto de contenedor visible en la evidencia | REC-0003 | **Diferido** → `CHG-REQ-LAB-CONTAINER` |
| `adapter_status` inconsistente en `describe_collector` | REC-0005 | **Implementado** |

## 3. GAP ANALYSIS

1. **El adaptador rechaza todo collector fuera de `SUPPORTED_COLLECTORS`** (`mcp_gateway_lab/oracle_sql.py`), y el lanzador rechaza un targets file que lo pida.
2. **Resolución de variante.** `sqlsource.resolve` exigía un bloque `variants:` explícito. `Q-ORA-RESOURCE-LIMITS-001` y `Q-ORA-PROCESSES-SUMMARY-001` no lo tienen: según `docs/QUERY_VARIANTS.md` tienen una **variante implícita**, certificada en `config/query-compatibility-matrix.yaml` como `implicit_full_range`, `10.2`–`latest`, `COMPATIBLE`. El lab no sabía resolverla y fallaba cerrado (`SQL_SOURCE_REFUSED`).
3. **Tipos.** `V$RESOURCE_LIMIT.LIMIT_VALUE` y `V$PARAMETER.VALUE` son `VARCHAR2`, con espacios a la izquierda (`'       320'`, `' UNLIMITED'`). El catálogo los declara `integer_or_unlimited`/`integer`, y el sanitizer descarta un string. Sin conversión, el campo clave se perdía sin avisar.
4. **Privilegios.** El usuario diagnóstico sólo tiene `SELECT` sobre `V_$INSTANCE`/`V_$DATABASE`. Faltan `V_$RESOURCE_LIMIT`, `V_$PROCESS` y `V_$PARAMETER`, y otorgarlos es acción humana del DBA.
5. **Alert log.** Es `kind: alert_log_excerpt` (lectura de archivo, adapter `oracle_diag_file` = `CONTRACT_ONLY`) y no tiene SQL certificado. No se puede servir con `oracle_sql` sin un adapter de archivos (acceso al host) o una query nueva sobre `V$DIAG_ALERT_EXT` (`sensitivity: HIGH`). Las dos opciones son un `/change query`/`/change security` propio.
6. **REC-0005.** `Collector.public_view()` publicaba el `adapters` estático de `collectors.json` (`oracle_sql: DISABLED`), aunque el registro vivo del lab dijera `LAB_ENABLED`.
7. **IDs canónicos.** No se crean queries, skills ni IDs nuevos. Los 3 IDs usados ya existen, son únicos y están domain-qualified.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Runtime por defecto (`python -m mcp_gateway`) | Ninguno funcional. `describe_collector` informa lo mismo que antes (`oracle_sql: DISABLED`), verificado por prueba |
| Lanzador lab | 2 collectors nuevos, disponibles **sólo** si el targets file privado los lista **y** el DBA otorgó los grants |
| Contrato de tools / esquemas MCP | Sin cambios (mismas 5 tools, mismas llaves) |
| Queries certificadas | Sin cambios: los archivos `Q-*.md` y sus SHA-256 son idénticos |
| `config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md` | Sin cambio de cobertura dominio×versión: el lab es 19c de un target, y la fila "MCP Diagnostic Gateway" sigue `PARTIAL` |
| Versión | Sólo 19c (el lanzador exige `oracle_version_family: 19c`). La matriz certifica 10.2–latest |
| Arquitectura | Standalone certificado por la query. RAC no aplica al lab. **Contenedor: ver §6** |
| Licencia | `license_requirements: none` (vistas `V$` estándar) |
| Costo | `cost_class: LOW` en ambas, `timeout 10 s`. Filas efectivas = min(perfil 5, query, collector) |
| Consumidores | `oracle-dba-analyst`, `oracle-performance-analyst` y `capacity-analyst` (por referencia) pasan de `INSUFFICIENT_EVIDENCE` a evidencia REAL de sesiones/procesos |
| Versiones | `mcp_gateway_lab` `0.1.0` → `0.2.0` (MINOR). Gateway `1.0.1` sin cambio (el ajuste de `describe_collector` es PATCH de metadatos y queda dentro del CHG) |

## 5. PROPOSAL / IMPLEMENT

- `mcp_gateway_lab/sqlsource.py`: resuelve la **variante implícita** sólo si: (a) el archivo no declara `variants:`; (b) tiene exactamente un bloque SQL; (c) la matriz tiene **una** entrada para ese `query_id`, con el **mismo archivo**, `implicit_full_range` y `validation_status: COMPATIBLE`; (d) el rango cubre la versión. Cualquier otra combinación falla cerrado. `variant_id` = `<QID>-IMPLICIT`.
- `mcp_gateway_lab/oracle_sql.py`: `SUPPORTED_COLLECTORS` += `Q-ORA-RESOURCE-LIMITS-001` (sólo ese; `Q-ORA-PROCESSES-SUMMARY-001` se descartó en revisión). Hay conversión tipada sólo para campos del catálogo `integer`/`integer_or_unlimited`: dígitos estrictos (`^[0-9]{1,15}$` tras `strip`) → `int`; `UNLIMITED` (sin distinguir mayúsculas) → `"UNLIMITED"`. Todo lo demás llega sin tocar al sanitizer, que lo descarta. Se agrega `implemented_collectors`.
- El orden no cambia: `SET TRANSACTION READ ONLY` → guardas de sesión/privilegios → **identidad** → query pedida → `rollback` + `close`.
- `mcp_gateway/adapters.py` + `gateway.py`: `describe_collector` informa, por adapter, el estado del **registro vivo**. Si el adapter declara `implemented_collectors` y no incluye el collector, informa `UNSUPPORTED`.
- `mcp_gateway_lab/cli.py` `LAB_VERSION 0.2.0`; comentarios en `profile.py` y `__init__.py`.

## 6. Compatibilidad y bloqueo abierto

| Check (`ESTACK_COMPAT_CHECKS`) | Resultado | Base |
|---|---|---|
| `version_coverage` | PASS | matriz `10.2`–`latest` ⊇ 19c; el lanzador sólo admite 19c |
| `query_contract` | PASS | queries sin cambios, Query Contract v2 completo (scope, role, cost, license, límites) |
| `dictionary_columns` | PASS | `V$RESOURCE_LIMIT`, `V$PROCESS`, `V$PARAMETER` = `min_version: all` en `compatibility/oracle-dictionary/views.yaml` |
| `architecture` | **PASS para `NON_CDB`/`CDB_ROOT`**, **FAIL para `PDB`** | Validado en el lab (§6): desde la PDB, 0 filas; desde `CDB$ROOT` con `C##ESTACK_DIAG`, 4 filas de instancia. El target lab queda en `CDB_ROOT` (decisión del DBA, opción C) |
| `cost_and_license` | PASS | LOW / none |
| `test_coverage` | PASS | 7 casos nuevos P15, 5 mutaciones detectadas |

### Resultado de la validación en el lab (2026-09-23T05:20:21Z)

El DBA otorgó `SELECT` sobre `V_$RESOURCE_LIMIT` en la PDB `PRUEBAS`. `diagnostics.collect` de `Q-ORA-RESOURCE-LIMITS-001` (`REQ-48228621beeb`, `EVR-d7d83e7da04503c44130cb06`, provenance **REAL**) pasó todas las guardas y devolvió **0 filas**, con `limitations: []`:

- **No es un problema de privilegio:** sin el grant habría `ORA-00942` → `MISSING_OBJECT_PRIVILEGE`.
- **No es el sanitizer:** no hay `INVALID_VALUES_DROPPED`.
- **Conclusión:** una sesión en PDB no ve las filas de instancia de `V$RESOURCE_LIMIT`. `architecture` pasa de `UNKNOWN` a **FAIL para `container: PDB`**.

**Decisión del DBA: opción C.** El target lab se registra en `CDB$ROOT` con un usuario común de mínimo privilegio, para tener los datos de instancia que necesita la evaluación de eventos. El código ya soportaba `CDB_ROOT` y usuarios `C##`; se agregaron 2 pruebas (funcional: evidencia desde root con `C##ESTACK_DIAG`; negativa: un perfil `CDB_ROOT` rechaza una sesión que cae en una PDB). `architecture` queda PASS **sólo** cuando una colección REAL desde `CDB$ROOT` devuelva filas, registrada aquí.

Defectos detectados, propuestos como seguimiento (sin implementar):
- `CHG-REQ-LAB-EMPTY-EVIDENCE`: un collector de instancia con 0 filas debería informar `INSUFFICIENT_EVIDENCE`, no `OK`. Además, una fila toda en NULL se descarta sin contarla.
- `CHG-REQ-LAB-PDB-SCOPE`: con perfil `PDB`, marcar `NOT_APPLICABLE` los collectors `container_scope: NOT_APPLICABLE` (instancia).

### Validación en `CDB$ROOT` (2026-09-23T05:47Z) — cierra `architecture`

Perfil privado actualizado por el DBA: `container: CDB_ROOT`, usuario `C##ESTACK_DIAG`, **nueva autorización humana** (`approved_by: DBA Manager`, `change_ref: CHG-ESTACK-ORA19C-LAB-002`, `approved_at_utc: 2026-09-23T05:46:29Z`). Servidor lab reiniciado (23:47:08 local).

| Colección | Referencia | Resultado |
|---|---|---|
| `Q-DISC-IDENTITY-001` | `REQ-21d837574b9e` / `EVR-5fb2d37951c4037aace2a67b` | REAL. Guardas de sesión OK: `CON_NAME = CDB$ROOT`, usuario no privilegiado. 19.32.0.0.0, PRIMARY, CDB, READ WRITE; mismo digest que antes (`6e43cf72…`) |
| `Q-ORA-RESOURCE-LIMITS-001` | `REQ-392c5feb2771` / `EVR-a9651bd369ec76fdcf482e32` | REAL, 4 filas, `limitations: []`, digest `a13ab349…`. processes 80/85/480, sessions 105/114/744, enqueue_locks 37/56/8860, dml_locks 0/18/UNLIMITED |

La conversión tipada funcionó sobre datos reales (`limit_value` `VARCHAR2` → entero / `UNLIMITED`). `open_cursors` no aparece: en 19c no es fila de `V$RESOURCE_LIMIT` (el filtro `IN` de la query certificada lo tolera).

Por la regla de Fase 12, un `UNKNOWN` no cuenta como soportado y bloquea `PENDING_HUMAN_REVIEW`. Con esta validación, ningún check queda en `UNKNOWN`. **Cómo se cierra** (acción humana, elegir una):

1. **Validación en el lab:** el DBA ejecuta `python -m mcp_gateway_lab check`, y un `collect` de cada collector, con la sesión en el contenedor real. Luego compara a mano (SQL*Plus, fuera del e-stack) contra los mismos valores leídos desde `CDB$ROOT`. Si coinciden, o la diferencia se documenta como semántica esperada, `architecture` = PASS.
2. **Restricción fail-closed:** limitar estos collectors a `container: NON_CDB|CDB_ROOT` y refusarlos con `NOT_APPLICABLE` cuando el perfil es `PDB`. Cierra el check por construcción, pero deja sin evidencia a un lab conectado a `PRUEBAS`.

## 7. SECURITY VALIDATION (revisión `oracle-security-analyst`)

| Control | Resultado |
|---|---|
| Superficie de tools / argumentos | Sin cambios; `tool_arguments_cannot_carry_sql_connection_or_paths` pasa |
| Origen del SQL | Sólo bloques certificados con SHA-256 fijado al arranque; la variante implícita exige entrada `COMPATIBLE` de la matriz para el mismo archivo (6 manipulaciones + matriz ausente → rechazo) |
| Escritura / PL/SQL | Ninguna; escaneo estático del paquete lab sin cambios y en verde; nunca `commit` |
| Orden de guardas | La query nueva nunca corre antes de probar la identidad (prueba + mutación) |
| Datos al modelo | Sólo enteros y enums `KEEP`; sin identificadores ni texto libre. La conversión no acepta signos, exponentes ni > 15 dígitos (prueba + mutación) |
| Privilegios de sistema | Techo sin cambios (`CREATE SESSION` / `SELECT ANY DICTIONARY`) |
| Privilegios de objeto nuevos (DBA) | Sólo `SELECT` sobre `V_$RESOURCE_LIMIT` (vista de límites de instancia, sin identificadores ni texto). Se evitaron `V_$PROCESS` y `V_$PARAMETER`, que habrían expuesto metadatos de procesos y todos los parámetros a la cuenta |
| Falta de grant | `ORA-00942` → `E_ADAPTER_FAILED` / `MISSING_OBJECT_PRIVILEGE`, sin evidencia parcial, `rollback` + `close` |

**Decisión de mínimo privilegio (DBA, 2026-09-22):** habilitar sólo `Q-ORA-RESOURCE-LIMITS-001`. Su fila `processes` ya trae procesos actuales, pico y límite, así que no hacen falta grants sobre `V_$PROCESS` ni `V_$PARAMETER`. `Q-ORA-PROCESSES-SUMMARY-001` se retiró también del código: el adaptador no lo implementa y el lanzador lo rechaza (prueba de seguridad). El único grant nuevo es `V_$RESOURCE_LIMIT`.

Veredicto: **PASS**. No introduce operaciones prohibidas, tools no certificadas ni fugas de datos.

## 8. REGRESSION VALIDATION

| Corrida | Resultado |
|---|---|
| Baseline (snapshot del árbol antes de IMPLEMENT) | 949/962 |
| Después del cambio | 949/962: la **misma** lista de 13 fallos preexistentes y ajenos (`*_no_delegation_loop` ×5, `test_collectors_are_allowlisted`, `Q-PDB-*` columnas ×2, `Q-RMAN-*` variantes ×5) |

Casos P15: adapter 14 → 17, security 22 → 26 (tras acotar a RESOURCE-LIMITS). Se ajustaron 2 casos existentes que usaban `Q-ORA-RESOURCE-LIMITS-001` como ejemplo de "collector no implementado"; ahora usan `Q-DG-STATS-001`. Es un cambio de contrato esperado, no una relajación.

## 9. Pasos humanos para usarlo en el lab (no los ejecuta el e-stack)

```text
-- DBA, SQL*Plus/SQLcl, SÓLO en el laboratorio, en el mismo contenedor donde conecta ESTACK_DIAG
GRANT SELECT ON SYS.V_$RESOURCE_LIMIT TO ESTACK_DIAG;
```

Después, en `~/.config/oracle-diagnostic-estack/targets.lab.json` (privado, fuera del repo), agregar el ID a `allowed_collectors` (hecho el 2026-09-22 a pedido del DBA; `validate-config` OK, sin conexión). Luego ejecutar `validate-config` y reiniciar la sesión de Claude Code para que el servidor MCP recargue. Rollback: quitar los IDs del targets file y hacer `REVOKE` de los grants.

## 9b. Pasos humanos para la opción C (target en `CDB$ROOT`)

```text
-- DBA, SQL*Plus/SQLcl como administrador, conectado a CDB$ROOT, SÓLO en el laboratorio
ACCEPT diag_pw CHAR PROMPT 'Password para C##ESTACK_DIAG: ' HIDE
CREATE PROFILE C##ESTACK_DIAG_PROF LIMIT
  SESSIONS_PER_USER 2  IDLE_TIME 15  CONNECT_TIME 60
  FAILED_LOGIN_ATTEMPTS 5  PASSWORD_LOCK_TIME 1  PASSWORD_LIFE_TIME 90
  CONTAINER=ALL;
CREATE USER C##ESTACK_DIAG IDENTIFIED BY "&&diag_pw"
  PROFILE C##ESTACK_DIAG_PROF CONTAINER=ALL;
-- CONTAINER=CURRENT: sólo puede conectarse y leer en CDB$ROOT, no en las PDBs
GRANT CREATE SESSION              TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$INSTANCE       TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$DATABASE       TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$RESOURCE_LIMIT TO C##ESTACK_DIAG CONTAINER=CURRENT;
UNDEFINE diag_pw
-- Verificación como C##ESTACK_DIAG en CDB$ROOT:
--   SELECT privilege FROM session_privs;                      -> sólo CREATE SESSION
--   SELECT SYS_CONTEXT('USERENV','SERVICE_NAME'), SYS_CONTEXT('USERENV','CON_NAME') FROM dual;   -> servicio del CDB, CDB$ROOT
--   SELECT i.version_full, d.name FROM v$instance i, v$database d;  -> db_name del CDB
-- El usuario ESTACK_DIAG de PRUEBAS queda sin uso: ALTER USER ESTACK_DIAG ACCOUNT LOCK; (en PRUEBAS)
```

Configuración privada (fuera del repo, la edita el DBA):

1. **Keychain:** guardar el password del usuario común en el mismo ítem (`security add-generic-password -U -s oracle-estack-lab -a lab-ol8-19c -w`).
2. **`lab-profile.json`:**
   - `connection.service_name` = servicio del CDB.
   - `connection.username` = `C##ESTACK_DIAG`.
   - `expected.container` = `CDB_ROOT`; quitar `expected.con_name`.
   - `expected.db_name` = nombre del CDB (el mismo `V$DATABASE.NAME`).
   - `expected.service_name` si el servicio observado lleva dominio.
   - `authorization`: **nueva** autorización humana (`approved_by`, `change_ref: CHG-ESTACK-ORA19C-LAB-002`, ventana ≤ 90 días).
3. **`targets.lab.json`:** `"container": "CDB_ROOT"`.
4. Correr `validate-config` y luego `check` (smoke test real), y reconectar `oracle-estack-lab` en `/mcp`.

Alcance: desde root, `Q-DISC-IDENTITY-001` y `Q-ORA-RESOURCE-LIMITS-001` leen datos de **instancia**. Los collectors futuros de nivel PDB (tablespaces de `PRUEBAS`, etc.) necesitarán vistas `CDB_*` con `CON_ID` y `CONTAINER_DATA` explícito para el usuario común (`CHG-REQ-LAB-DOMAINS`), evaluado en su propio cambio.

## 10. Registros diferidos (CHG-REQ propuestos, sin implementar)

- **`CHG-REQ-LAB-ALERTLOG`**: evidencia de disponibilidad. Opción A: query nueva `Q-ORA-DIAGNOSTICS-ALERTLOG-SQL-001` sobre `V$DIAG_ALERT_EXT` (12.2+, `sensitivity: HIGH`, sólo `originating_timestamp` + firma `ORA-nnnnn`, `message_text` DROP). Opción B: adapter `oracle_diag_file`, que requiere acceso al host y es un cambio de modelo de amenazas. Recomendada: A.
- **`CHG-REQ-LAB-DOMAINS`**: por lotes. Cada query de tablespaces/parámetros/PDB/`Q-RMAN-*`/`Q-SEC-*` necesita una entrada en `collectors.json` con política por campo, fixtures, alias de columnas en el lab, grants mínimos y pruebas. Orden sugerido: tablespaces/FRA → RMAN → PDB → seguridad (esta última con revisión de sensibilidad).
- **`CHG-REQ-LAB-CONTAINER`**: exponer `CON_NAME`/`CON_ID` (el adaptador ya los valida) como evidencia certificada, con una query `Q-DISC-CONTAINER-001` o un campo derivado declarado. Ayuda a cerrar el `UNKNOWN` de §6.

## 11. HUMAN REVIEW (aprobado)

Motor de gobernanza (`advise --mode estack`, 2026-09-23T05:48:22Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 22cb98cb5eccde2a47c2d48d0a7c2f3d83bb08a6d3dbf64c2c3b9ba1cabc39d6`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-ORA19C-LAB-002/`. La aprobación del revisor se registra contra ese digest.

Revisor: una persona distinta del proponente (`E_AUTH_SELF_APPROVAL`). Decisiones que le corresponden:

1. ~~Cerrar `architecture`~~: resuelto. PDB = FAIL; `CDB$ROOT` = PASS con evidencia REAL (§6).
3b. ~~Nueva autorización humana~~: hecha por el DBA Manager (`2026-09-23T05:46:29Z`, `CHG-ESTACK-ORA19C-LAB-002`). Queda en el perfil privado, no en el repo. No es un registro externo verificable por el e-stack.
2. ~~Elegir collectors~~: resuelto, sólo `Q-ORA-RESOURCE-LIMITS-001`.
3. Revisar este CHG junto con `CHG-ESTACK-ORA19C-LAB-001`, que es su base y tampoco tiene commit.
4. `PROMOTE` / commit / merge: acción humana.
