# PHASE 8 — DBA_USERS 12.1.0.2 BOUNDARY CERTIFICATION MICRO-HARDENING

Baseline: `v0.7.0-backup-recovery-rman`. Branch: `phase/8-security-compliance`.

**Nota (superado)**: la conclusión de este documento para `COMMON`/`ORACLE_MAINTAINED` (12.1.0.1)
fue **corregida** en `PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION`
(`docs/PHASE_8_FINAL_DBA_USERS_12102_SOURCE_OF_TRUTH_CORRECTION.md`) tras verificar el HTML crudo
(sin resumen de modelo intermedio) de la página oficial de referencia de `DBA_USERS`: existe un
footnote oficial explícito ("This column is available starting with Oracle Database 12c Release 1
(12.1.0.2).") adjunto a `COMMON`, `ORACLE_MAINTAINED`, `LAST_LOGIN` y `PROXY_ONLY_CONNECT` — no
detectado por las dos verificaciones que sustentan este documento (el marcador de nota al pie se
pierde en un resumen de modelo intermedio sobre HTML→texto). El boundary real de las cuatro
columnas es `12.1.0.2`. El análisis de investigación de abajo se conserva íntegro como registro
histórico de lo investigado entonces — **no vigente**, ver el documento de corrección para el
estado actual.

## Resultado de la investigación — conflicto con la premisa del prompt (histórico, superado)

Este micro-hardening fue solicitado para forzar `DBA_USERS.COMMON`, `DBA_USERS.ORACLE_MAINTAINED`
y `DBA_USERS.LAST_LOGIN` a `min_version: "12.1.0.2"` los tres. La verificación obligatoria contra
documentación oficial Oracle (sección 3-4 del prompt de este micro-hardening: "confirma... antes
de modificar", "Official Oracle documentation has precedence over secondary sources") **no
confirma esa premisa para `COMMON` ni para `ORACLE_MAINTAINED`** — sólo la confirma para
`LAST_LOGIN`, que ya estaba correctamente certificada en `12.1.0.2` desde el hardening anterior
(`docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md`).

### Evidencia oficial recopilada en este micro-hardening

| Fuente (oficial Oracle salvo donde se indica) | Hallazgo |
|---|---|
| `docs.oracle.com/database/121/REFRN/GUID-309FCCB2...htm` (DBA_USERS Reference, columna por columna, texto verbatim solicitado explícitamente) | Ninguna de las tres columnas (`COMMON`, `ORACLE_MAINTAINED`, `LAST_LOGIN`) lleva un calificador de versión/patch en su descripción oficial — no hay una frase tipo "available starting with 12.1.0.2" en el texto de la columna. |
| `docs.oracle.com/database/121/DBSEG/release_changes.htm` (Oracle Database Security Guide — Changes in This Release, fuente MÁS autoritativa para features de seguridad por release) | Atribuye explícitamente a **12.1.0.1**: *"User, Privilege, and Role Support for the Oracle Multitenant Option"* → *"About Common Users and Local Users"* → *"In a multitenant environment, common users have access to the entire CDB and local users are specific to a PDB."* Esto es exactamente el concepto que `DBA_USERS.COMMON` refleja. |
| `docs.oracle.com/database/121/NEWFT/chapter12101.htm` (12.1.0.1 New Features) | Confirma Multitenant Architecture como GA de 12.1.0.1 (ya verificado en el hardening anterior). |
| `docs.oracle.com/database/121/NEWFT/chapter12102.htm` (12.1.0.2 New Features) | **No** lista `DBA_USERS`, `COMMON`, `ORACLE_MAINTAINED` ni `LAST_LOGIN` como feature nueva — las 21 features de este release son compresión, in-memory, JSON, PDB management, FIPS 140, zone maps. |
| `docs.oracle.com/database/121/READM/chapter12102.htm` (12.1.0.2 Readme) | **No** menciona `COMMON`/`ORACLE_MAINTAINED`/`LAST_LOGIN` como nuevas — la única mención de `DBA_USERS` es instructiva (troubleshooting de PDB clone), no documenta cambios de columna. |
| `docs.oracle.com/database/121/REFRN/GUID-509A6343...htm` ("Changes in This Release" del Database Reference — lista de vistas/parámetros NUEVOS por patch) | No incluye `DBA_USERS` en ningún lado (columnas añadidas a una vista ya existente no aparecen en esta lista, que sólo trackea vistas/parámetros enteramente nuevos) — no aporta evidencia en ningún sentido para columnas. |
| Blog datado 2013-07-17 (secundaria, ya usada en el hardening anterior sólo como corroboración cronológica, nunca como autoridad primaria) | Consulta `ORACLE_MAINTAINED` ~3 semanas después del GA de 12.1.0.1 (2013-06-25) — un año antes de que existiera 12.1.0.2 (julio 2014). Imposible que la columna requiriera 12.1.0.2 si ya se consultaba con éxito en 12.1.0.1. |
| My Oracle Support KM + múltiples fuentes independientes (ya usadas en el hardening anterior) | Citan específicamente "12.1.0.2" para `LAST_LOGIN` — **ningún** fuente equivalente cita 12.1.0.2 específicamente para `COMMON`/`ORACLE_MAINTAINED`. |

### Conclusión verificada

- `DBA_USERS.COMMON`: **`12.1.0.1`** — confirmado por la fuente más autoritativa posible (Oracle
  Database Security Guide, Changes in This Release, atribución explícita a 12.1.0.1). Sin cambio.
- `DBA_USERS.ORACLE_MAINTAINED`: **`12.1.0.1`** — ninguna fuente oficial ni secundaria contradice
  esto; ninguna fuente afirma 12.1.0.2 específicamente para esta columna. Sin cambio.
- `DBA_USERS.LAST_LOGIN`: **`12.1.0.2`** — confirmado, sin cambio (ya corregido en el hardening
  anterior).

**No se modificó `compatibility/oracle-dictionary/views.yaml`** para `COMMON`/`ORACLE_MAINTAINED`
— hacerlo habría introducido un boundary incorrecto (`# 1` no-negociable de este mismo prompt:
"COLUMN MIN_VERSION MUST MATCH THE EXACT CERTIFIED RELEASE/PATCH LEVEL"), habría re-particionado
incorrectamente `Q-SEC-DEFAULT-ACCOUNTS-001`/`Q-SEC-ACCOUNT-INVENTORY-001` (ya correctamente
certificadas desde el hardening anterior), y habría requerido codificar tests
`test_dba_users_{common,oracle_maintained}_12101_invalid` que habrían afirmado algo falso —
violando directamente el `# 1` no-negociable de este mismo prompt: "NO TEST MAY ENCODE A
KNOWN-INCORRECT COMPATIBILITY ASSUMPTION".

Esto es consistente con la causa raíz ya documentada en el hardening anterior: una síntesis de
WebFetch sobre la página oficial de referencia de `DBA_USERS` generalizó incorrectamente el
boundary genuino de `LAST_LOGIN` (`12.1.0.2`) a las tres columnas — el mismo patrón de error se
repite en la premisa de este micro-hardening prompt, y vuelve a quedar descartado por evidencia
fechada/atribuida independiente.

## Objetivos cerrados de este micro-hardening (independientes del boundary en disputa)

### Q-SEC-DEFAULT-ACCOUNTS-001 / Q-SEC-ACCOUNT-INVENTORY-001

Sin cambios — ya correctamente certificadas desde el hardening anterior (`legacy_11g`/
`modern_12plus` para Default Accounts; `legacy_pre12c`/`multitenant_no_last_login`/
`modern_12102plus` para Account Inventory, este último ya reflejando correctamente que sólo
`LAST_LOGIN` requiere `12.1.0.2`).

### Tests 12.1.0.1 existentes

`test_dba_users_oracle_maintained_12101_valid.sh`/`test_dba_users_common_12101_valid.sh` **no
fueron modificados** — codifican la aserción correcta (`CERTIFIED` en 12.1.0.1), verificada de
nuevo en este micro-hardening. Convertirlos a `_invalid` habría sido incorrecto.

### Tests 12.1.0.2 positivos (nuevos)

Agregados `test_dba_users_common_12102_valid.sh`/`test_dba_users_oracle_maintained_12102_valid.sh`
— complementarios, triviales (un patch level posterior nunca retira disponibilidad dentro de la
misma minor release), sin conflicto con ningún hallazgo. `test_dba_users_last_login_12102_valid.sh`
ya existía del hardening anterior.

### Static Validator / Shared Version Resolver

Sin cambios de implementación — confirmado que `scripts/lib/version.sh` distingue correctamente
`12.1.0.1`/`12.1.0.2` (usado por los tests de boundary, todos pasando) y que el Static Validator
permanece dictionary-driven (sin modificaciones desde el hardening anterior).

### MCP Roadmap documentation fix

Corregida la referencia obsoleta "el Gateway MCP real es Fase 7" (una promesa hecha durante
Fases 2/6, nunca cumplida — Fase 7 se completó como Backup & Recovery/RMAN sin construir el
Gateway runtime) a "Fase 13" (roadmap vigente) en los documentos operativos vivos:
`collectors/README.md`, `docs/QUERY_VARIANTS.md` (2 ocurrencias), `mcp/tool-manifest.md`,
`tests/README.md`, `docs/CAPABILITY_MATRIX.md`, `CHANGELOG.md` (entrada `[Unreleased]` actual),
`docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md`. Los reportes de cierre
históricos de Fases 2 y 6 (`docs/PHASE_2_COMPATIBILITY_HARDENING.md`,
`docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`,
`docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md`) se dejaron intactos
deliberadamente — son registros de cierre congelados en el tiempo, no documentación operativa
viva; reescribirlos sería revisionismo histórico, fuera del alcance de "corregir esa referencia
obsoleta" (`# 22` del prompt: "No modificar roadmap fuera de ese error").

## TEST_SCOPE

`TARGETED` — no se modificó Static Validator, Shared Version Resolver, Query Variant Resolver,
dictionary parser, query parser, test harness ni security scanner. Único cambio de contenido:
documentación (roadmap fix) + 2 tests nuevos aditivos. `compatibility/oracle-dictionary/views.yaml`
no se tocó en este micro-hardening (el boundary propuesto no se confirmó).

## Regresión dirigida ejecutada

`test_security_default_accounts.sh`, `test_security_account_inventory.sh`,
`test_dba_users_oracle_maintained_12101_valid.sh`, `test_dba_users_oracle_maintained_12102_valid.sh`,
`test_dba_users_common_12101_valid.sh`, `test_dba_users_common_12102_valid.sh`,
`test_dba_users_last_login_12101_invalid.sh`, `test_dba_users_last_login_12102_valid.sh`,
`test_static_validator_checks_dba_column_min_version.sh`,
`test_static_validator_rejects_unknown_dba_column.sh`,
`test_sqlnet_parameters_not_sourced_from_v_parameter.sh`,
`test_network_encryption_uses_network_evidence.sh` — todos verificados pasando.

## Known limitations

- El boundary de `COMMON`/`ORACLE_MAINTAINED` en `12.1.0.1` permanece, como todo hallazgo de este
  e-stack, sujeto a revisión si aparece evidencia oficial nueva y más específica que la ya
  recopilada — pero la evidencia actual (Oracle Database Security Guide, atribución explícita)
  es la fuente más autoritativa disponible y no deja margen razonable de duda.
- No se investigó de dónde provino la premisa del prompt de este micro-hardening (12.1.0.2 para
  las tres columnas) — se documenta el conflicto y la evidencia contraria, sin especular sobre su
  origen.
