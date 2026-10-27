# Lote B7: cobertura de seguridad del assessment

`/change query|security|compatibility|documentation` — `CHG-ESTACK-B7-SECURITY-COVERAGE-001`. Rama `change/b7-security-coverage` sobre `change/field-validation-freshness` (`13e58b2`); depende de `CHG-ESTACK-FIELD-VALIDATION-FRESHNESS-001`. Origen: la cobertura por dominio de `ANA-20261020-001`, donde Seguridad (O) quedó PARTIAL y TDE (Q) NOT_ASSESSED.

## Por qué

Había 19 queries de seguridad **certificadas pero no expuestas** por el gateway. Tal como estaban, no se podían exponer:

| Problema | Ejemplo |
|---|---|
| Rutas y destinos crudos | `wrl_parameter` (ruta del keystore), `host` y `username` de los DB links |
| Fechas absolutas | `created`, `lock_date`, `expiry_date`, `last_login` |
| Listas enormes con nombres de objetos | `DBA_TAB_PRIVS` tiene decenas de miles de filas de esquemas de Oracle |
| Solo el root | `DBA_*` desde `CDB$ROOT` no ve la PDB |
| Licencia mal asignada | DV, OLS y Data Redaction marcaban la **lectura de su estado** como uso de la opción |

## Cambios

**16 queries reescritas y expuestas** (lote B7 de la fábrica):

| Query | Versión | Cómo queda |
|---|---|---|
| `Q-SEC-ACCOUNT-INVENTORY-001` | 2.0.0 | `CDB_USERS` por contenedor; fechas como horas; desde 12.1.0.2, solo cuentas propias o abiertas |
| `Q-SEC-DATA-REDACTION-POLICIES-001` | 4.0.0 | Conteo por estado y función; sin dueños, objetos ni nombres de política |
| `Q-SEC-DATABASE-VAULT-STATUS-001` | 2.1.0 | Sin cambio de SQL; `license_requirements: none` |
| `Q-SEC-OLS-STATUS-001` | 2.0.0 | Columna `ols_option`; `license_requirements: none` |
| `Q-SEC-DB-LINKS-001` | 2.0.0 | `host` y `username` se clasifican en la base (`target_kind`, `link_auth`) y nunca salen; nombre sin dominio; `link_scope` dice si es público |
| `Q-SEC-ENCRYPTED-COLUMNS-001` | 2.0.0 | Conteo por dueño y algoritmo |
| `Q-SEC-ENCRYPTED-TABLESPACES-001` | 2.0.0 | `CDB_TABLESPACES`; join de `TS#` dentro del mismo `con_id`; algoritmo como enum |
| `Q-SEC-OBJECT-PRIVILEGES-001` | 2.0.0 | Conteo por grantee y privilegio; grantees de Oracle excluidos desde 12.1.0.2 |
| `Q-SEC-PASSWORD-VERSIONS-001` | 2.0.0 | Conteo por combinación de verificadores; sin usuarios |
| `Q-SEC-PUBLIC-OBJECT-GRANTS-001` | 2.0.0 | Conteo por dueño y privilegio; esquemas de Oracle agregados |
| `Q-SEC-PUBLIC-SYSTEM-GRANTS-001` | 2.0.0 | `CDB_SYS_PRIVS` y `admin_option` |
| `Q-SEC-ROLE-GRANTS-001` | 2.0.0 | Grantees propios; `oracle_role` nombra solo roles de Oracle (`CUSTOM` para los propios) |
| `Q-SEC-ROLES-001` | 2.0.0 | Conteo por contenedor, `common` y `oracle_maintained` |
| `Q-SEC-SECURITY-PARAMETERS-001` | 2.0.0 | 15 parámetros; valor solo como número, `TRUE`/`FALSE` o palabra clave |
| `Q-SEC-SYSTEM-PRIVILEGES-001` | 2.0.0 | Grantees propios; tipo de grantee |
| `Q-SEC-TDE-WALLET-001` | 2.0.0 | Sin `wrl_parameter`; tipo, estado, orden y respaldo del keystore por contenedor |

**No se exponen:**

| Query | Motivo |
|---|---|
| `Q-SEC-PASSWORD-VERIFY-SOURCE-001` | Devuelve código fuente y necesita binds |
| `Q-SEC-ROLE-OBJECT-PRIVILEGES-001` | `ROLE_TAB_PRIVS` depende de los roles de la sesión, no de la base |
| `Q-SEC-COMMON-LOCAL-USERS-001` | La cubre `Q-SEC-ACCOUNT-INVENTORY-001` 2.0.0 |
| `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` | Sigue `not_certified` |

**Fronteras de versión:**
- **V1:** `DBA_*` (10.2–11.2).
- **V2:** `CDB_*` (12.1–12.1.0.1).
- **V3:** desde 12.1.0.2, porque ahí aparecen `ORACLE_MAINTAINED`, `COMMON` y `LAST_LOGIN`.
- Las queries sin esas columnas usan V2 desde 12.1.

**Licencias:** leer el estado de DV, OLS y Data Redaction en el diccionario no usa la opción. Crear o aplicar políticas, sí. Por eso las 3 queries pasan a `license_requirements: none`. Los skills `database-vault-awareness` y `ols-awareness` siguen declarando la **opción** como `SEPARATELY_LICENSED`. **Decisión para la revisión humana.**

**Gateway y fábrica:**
- `oracle_role` se agrega a `ORACLE_TERM_FIELDS`;
- 30 campos nuevos en la base de campos (enums cerrados, identificadores `MASK` y números acotados);
- `TRACE`, `LOG` y `ALERT` se agregan a `value_keyword`;
- el catálogo pasa de 74 a **90 collectors**.

**Diccionario:**
- `CDB_DB_LINKS` y `CDB_ENCRYPTED_COLUMNS` (12.1);
- en `V$ENCRYPTION_WALLET`, las columnas `wrl_type`, `wallet_order`, `fully_backed_up` y `con_id`;
- `con_id` en `V$ENCRYPTED_TABLESPACES`;
- corrección: `wallet_type` existe desde 12.1, no desde 11.2;
- las 5 sondas `Q-DICT-VERIFY` se regeneran, y sus validaciones en campo se retiran hasta revalidarlas en el lab.

**Errores encontrados al implementar:**
- **El resolver del lab acepta etiquetas de variante de hasta 120 caracteres.** La V3 de `Q-SEC-ACCOUNT-INVENTORY-001` tenía 123, así que 19c quedaba sin variante y el gateway fallaba cerrado. Se acortó, y P18 ahora exige que toda variante declarada de todo collector se interprete y resuelva en su versión mínima y máxima.
- **El validador estático tomaba `SUBSTR`, `INSTR`, `TRIM`, `UPPER`, `IS` y `EXISTS` como columnas.** Se agregaron a su lista de palabras de SQL.

## Escenario de prueba del lab (ejecución humana, solo lab)

Para que los collectors devuelvan filas representativas, el DBA ejecuta en la PDB de aplicación un escenario mínimo, con su reverso:
- una cuenta propia sin contraseña (`NO AUTHENTICATION`);
- un rol propio y un rol de Oracle concedido (`RESOURCE`);
- privilegios de sistema y de objeto;
- un grant a `PUBLIC` desde un esquema propio;
- un DB link público hacia un nombre de servicio inexistente, que nunca se abre.

No usa opciones licenciadas: TDE, Data Redaction, DV y OLS se validan en su estado real (no configuradas). Los scripts son texto; el e-stack no puede ejecutarlos.

```sql
-- setup: sqlplus / as sysdba @b7_lab_setup.sql <PDB>
CREATE USER ESTACK_B7_APP NO AUTHENTICATION DEFAULT TABLESPACE USERS QUOTA 1M ON USERS;
CREATE ROLE ESTACK_B7_ROLE;
GRANT CREATE SESSION TO ESTACK_B7_ROLE;
GRANT RESOURCE TO ESTACK_B7_APP;
GRANT ESTACK_B7_ROLE TO ESTACK_B7_APP;
GRANT CREATE VIEW TO ESTACK_B7_APP;
CREATE TABLE ESTACK_B7_APP.ESTACK_B7_T (ID NUMBER);
GRANT SELECT ON ESTACK_B7_APP.ESTACK_B7_T TO ESTACK_B7_ROLE;
GRANT SELECT ON ESTACK_B7_APP.ESTACK_B7_T TO PUBLIC;
CREATE PUBLIC DATABASE LINK ESTACK_B7_LINK USING 'ESTACK_B7_NOWHERE';

-- teardown: sqlplus / as sysdba @b7_lab_teardown.sql <PDB>
DROP PUBLIC DATABASE LINK ESTACK_B7_LINK;
DROP USER ESTACK_B7_APP CASCADE;
DROP ROLE ESTACK_B7_ROLE;
```

## Validación en el lab

`lab-ol8-19c` (contexto `LAB-OL8-19C-CDBROOT-ASM`, 19.32, `CDB$ROOT`), cuenta de diagnóstico con `SELECT_CATALOG_ROLE` y `CONTAINER_DATA`: **no hizo falta ningún privilegio nuevo**. Escenario de prueba aplicado por el DBA en la PDB de aplicación. Todas las respuestas, `REAL` y `SANITIZED`.

| Collector | Filas | Lo que confirma | Evidencia |
|---|---|---|---|
| `Q-SEC-ACCOUNT-INVENTORY-001` | 16 | Root y PDB; la cuenta del escenario sale `NONE` (sin contraseña), sin fechas absolutas; desde 12.1.0.2 se omiten las cuentas de Oracle bloqueadas | `EVR-7913efac7a8015a5a9d37eb9` / `REQ-a588293b222f` |
| `Q-SEC-DATA-REDACTION-POLICIES-001` | 0 | Sin políticas (opción no usada) | `EVR-879a1018fd3de9d943c7a011` / `REQ-aaf989477cb3` |
| `Q-SEC-DATABASE-VAULT-STATUS-001` | 1 | `dv_option` `FALSE` | `EVR-4b30b69f3047e458636367b9` / `REQ-6a1d69d769a9` |
| `Q-SEC-OLS-STATUS-001` | 1 | `ols_option` `FALSE` | `EVR-452c6a5ee6ba2fa7de2bc72f` / `REQ-a7ae32b426d8` |
| `Q-SEC-DB-LINKS-001` | 1 | El link público del escenario: `link_scope` `PUBLIC`, `CONNECTED_USER`, `NET_SERVICE_NAME`, sin host. Ver hallazgo 1 | `EVR-c6dd082e93dfadab279d99ae` / `REQ-df4f8f0ab502` (antes de `link_scope`: `EVR-17faa8cce0ac6407a4092460` / `REQ-0241856e6ffc`) |
| `Q-SEC-ENCRYPTED-COLUMNS-001` | 0 | Sin columnas TDE | `EVR-787bc2ed1f6cf75b92a3bd03` / `REQ-de700b4c4896` |
| `Q-SEC-ENCRYPTED-TABLESPACES-001` | 10 | 5 tablespaces por contenedor, todos `UNENCRYPTED` | `EVR-3d7225a05faecba4007674f4` / `REQ-fb29d2881a0a` |
| `Q-SEC-OBJECT-PRIVILEGES-001` | 4 | El rol propio con `SELECT` sobre 1 objeto; `PUBLIC` y grantees de Oracle excluidos | `EVR-adab8a16a56ae601f6bc6daa` / `REQ-e83427622419` |
| `Q-SEC-PASSWORD-VERSIONS-001` | 5 | Conteos por verificador (`11G 12C`, `11G`) | `EVR-249093af9bf5c98b91381047` / `REQ-48ffd5781343` |
| `Q-SEC-PUBLIC-OBJECT-GRANTS-001` | 19 | El grant a `PUBLIC` del escenario (dueño propio, 1 objeto); esquemas de Oracle agregados | `EVR-8d8fc837594e91c82d77a257` / `REQ-d638cface484` |
| `Q-SEC-PUBLIC-SYSTEM-GRANTS-001` | 0 | Sin privilegios de sistema a `PUBLIC` | `EVR-60b34f49e89b5c2a72742749` / `REQ-3da5e72fad67` |
| `Q-SEC-ROLE-GRANTS-001` | 8 | `RESOURCE` y `PDB_DBA` por nombre; el rol propio como `CUSTOM` enmascarado | `EVR-c5465ebf6078e835d2a98b74` / `REQ-48d834be5484` |
| `Q-SEC-ROLES-001` | 5 | 93 roles de Oracle por contenedor; el rol local del escenario (`common` `NO`) | `EVR-084314b0633b256cb50c97d6` / `REQ-29aae4a93a3f` |
| `Q-SEC-SECURITY-PARAMETERS-001` | 14 | 14 de 15: `o7_dictionary_accessibility` ya no existe en 19c. `os_authent_prefix` sin valor (no es palabra clave) | `EVR-3815e177f8b5041a97d3a6d6` / `REQ-d7310537c4dc` |
| `Q-SEC-SYSTEM-PRIVILEGES-001` | 11 | `CREATE VIEW` directo y `CREATE SESSION` del rol propio | `EVR-2c346ef6fe48f05ed5afddd6` / `REQ-3cb766540a1b` |
| `Q-SEC-TDE-WALLET-001` | 2 | Keystore `FILE` `NOT_AVAILABLE` por contenedor, sin ruta | `EVR-5f9a33abe65af5e5eeb1c1d2` / `REQ-9968ba747f8c` |

**Sondas del diccionario** (regeneradas por este cambio): las 5 confirman todas las vistas y columnas declaradas. La única diferencia es `STATS$SNAPSHOT` y `STATS$SYSTEM_EVENT` como `VIEW_NOT_FOUND`, porque Statspack no está instalado (hallazgo informativo, igual que antes).

| Sonda | Evidencia |
|---|---|
| `Q-DICT-VERIFY-001` | `EVR-1dd2c23aad0132ea3bb72570` / `REQ-51bbcf35cc35` |
| `Q-DICT-VERIFY-002` | `EVR-1924b34402cb5c6e55490e43` / `REQ-af01e8d1cc45` |
| `Q-DICT-VERIFY-003` | `EVR-ab34e13b2ff7d616fb4c4dfc` / `REQ-ac09efbcb69b` |
| `Q-DICT-VERIFY-004` | `EVR-59ed25c7da1bf63b6227b6aa` / `REQ-30e97eb98d55` |
| `Q-DICT-VERIFY-005` | `EVR-c0f33b04fcf411b5bc09575a` / `REQ-ff79749fb753` |

**Hallazgos de la revisión de especialistas:**
1. **`security-analyst`: el dueño `PUBLIC` de un DB link salía enmascarado**, así que no se sabía que el link es público, que es el dato de riesgo. Se agrega `link_scope` (`PUBLIC`/`PRIVATE`), calculado en la base; P18 lo exige. Revalidado en el lab: el link del escenario sale `PUBLIC`.
2. **`oracle-dba-analyst`:** la ausencia de `o7_dictionary_accessibility` y de `STATS$*` es correcta para 19c sin Statspack. No requiere cambio.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Cobertura de `ANA-20261020-001`: O PARTIAL, Q NOT_ASSESSED |
| CHANGE REQUEST | `CHG-ESTACK-B7-SECURITY-COVERAGE-001`, tipos `query`, `security`, `compatibility` y `documentation` |
| GAP ANALYSIS | 19 queries certificadas sin exponer: 16 rediseñables y 4 descartadas con motivo (arriba) |
| IMPACT ANALYSIS | Catálogo de 74 a 90 collectors. Sin privilegio nuevo esperado (`SELECT_CATALOG_ROLE` + `CONTAINER_DATA`; se confirma en el lab). Licencia: 3 queries pasan a `none` (decisión humana). Sin tools nuevas. Los escenarios de `tests/fixtures` conservan sus columnas |
| PROPOSAL | Este documento |
| IMPLEMENT | 16 contratos; matriz de compatibilidad; diccionario; 30 campos y lote B7; `ORACLE_TERM_FIELDS`; target de fixtures; registro de madurez (90 collectors, 158 componentes); 5 sondas del diccionario regeneradas |
| TEST | P18 36/36, con 6 casos nuevos: lote B7 sin campos sensibles; ni `host`, ni `wrl_parameter`, ni fechas, ni credenciales en 10.2–19c; fronteras `CDB_*`/`ORACLE_MAINTAINED`; `oracle_role` acotado; licencias; toda variante del catálogo resuelve en sus bordes |
| SECURITY | 12/12 mutaciones detectadas: `host` crudo, ruta del keystore, `oracle_role` sin guarda, grantees de Oracle incluidos, fecha cruda, licencia reintroducida, `oracle_role` fuera de `ORACLE_TERM_FIELDS`, `db_link` en `KEEP`, join de `TS#` entre contenedores, valor de parámetro crudo, `PUBLIC` no excluido y etiqueta de variante demasiado larga |
| REGRESSION | 972/973 en macOS (bash 5.3). El único fallo fue un `grep -q` tras un pipe en `test_no_wallet_secret_exposure.sh` (modificado por este cambio; riesgo de SIGPIPE); se corrigió y ese test, `test_no_pipe_into_early_exit_grep.sh` y los de consistencia de documentos pasan. Tras `link_scope`: una corrida dio 972/973 por `a_fixture_replaced_by_a_link_after_startup_is_denied_at_read_time` (P14), que no toca nada de este cambio; pasó 10 de 10 veces aislado y la corrida siguiente dio **973/973**. Queda anotado como intermitente |
| LAB | Los 16 collectors y las 5 sondas, `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` (21 registros nuevos; el registro pasa de 64 a 85). Sin privilegios nuevos. `Q-SEC-DB-LINKS-001` revalidado tras agregar `link_scope`. El registro recargado por el gateway sin reconectar (`CHG-ESTACK-FIELD-VALIDATION-FRESHNESS-001`): `Q-SEC-ROLES-001` respondió `FIELD_VALIDATED` (`REQ-8ae30541c633`) |
| HUMAN REVIEW | Pendiente |
