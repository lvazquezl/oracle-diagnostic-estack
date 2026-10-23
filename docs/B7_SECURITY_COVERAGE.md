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
| `Q-SEC-DB-LINKS-001` | 2.0.0 | `host` y `username` se clasifican en la base (`target_kind`, `link_auth`) y nunca salen; nombre sin dominio |
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
| REGRESSION | 972/973 en macOS (bash 5.3). El único fallo fue un `grep -q` tras un pipe en `test_no_wallet_secret_exposure.sh` (modificado por este cambio; riesgo de SIGPIPE); se corrigió y ese test, `test_no_pipe_into_early_exit_grep.sh` y los de consistencia de documentos pasan |
| LAB | Pendiente |
| HUMAN REVIEW | Pendiente |
