# PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING

Baseline: `v0.7.0-backup-recovery-rman`. Branch: `phase/8-security-compliance` (sin tag `v0.8.0-security-compliance` aún — pendiente de este hardening).

**Nota (superado)**: cierra 3 defectos reales detectados en el build base de Phase 8
(`docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md`), no documentados hasta este hardening: un gap
sistémico del Static Validator para objetos `DBA_*`/`CDB_*`/etc., un boundary de patch-level
incorrecto en `DBA_USERS`, y una query certificando `SQLNET.*` desde una fuente de evidencia
estructuralmente incorrecta.

## Objetivo

Cerrar exclusivamente los 3 bloques de defecto identificados — no reconstruye ninguna parte de
Phase 8 (agente, 39 skills, password policy model, audit model, TDE model, compliance model,
licensing gates permanecen intactos salvo dependencia directa).

## Defecto 1 — Static Validator: gap sistémico para objetos sin `$`

### Causa raíz

`tests/test_sql_static_validator.sh#extract_aliases()` sólo reconocía un token FROM/JOIN como
"objeto de vista" si contenía literalmente `$` — todo objeto `DBA_*`/`CDB_*`/`ALL_*`/`USER_*`/
`ROLE_*`/`AUDIT_*`/`UNIFIED_*`/`REDACTION_*` nunca entraba en `alias_map`, así que **ni la
existencia de columna (Chequeo 2) ni el version-gating (Chequeo 3) se ejecutaban jamás** para
esos objetos, para NINGUNA query del catálogo completo (Oracle Core, Data Guard, Multitenant,
RMAN, Security) — un gap de todas las fases anteriores expuesto por primera vez por Security, el
primer dominio con un catálogo mayoritariamente `DBA_*`.

### Fix — dictionary-driven, no hardcoded prefixes

Se construye, al inicio del script (una sola vez, cacheado en un array asociativo bash para
O(1)), el conjunto completo de nombres de objeto de nivel superior registrados en
`compatibility/oracle-dictionary/views.yaml` (exhaustive o no — mismo criterio de inclusión que
ya existía para objetos `$`). `extract_aliases()` reconoce un token como candidato a vista si
contiene `$` (compat histórico, sin cambios) **o** si su forma en minúsculas coincide EXACTAMENTE
con un objeto registrado — nunca por substring (evita confundir `DBA_USERS` con
`DBA_USERS_WITH_DEFPWD`). El resto del mecanismo (resolución de alias, chequeo de existencia,
chequeo de version-gating) es exactamente el mismo para objetos `$` y no-`$` — ninguna lógica
paralela.

### Alcance de la corrección

Objetos ahora correctamente cubiertos: `DBA_*`, `CDB_*`, `ALL_*`, `USER_*`, `ROLE_*`, `AUDIT_*`,
`UNIFIED_*`, `REDACTION_*`, y cualquier otro objeto presente en el dictionary — sin necesidad de
listar prefixes explícitamente. `V$*`/`GV$*` no se tocó — su validación existente permanece
intacta (verificado por regresión completa).

## Defecto 2 — Q-SEC-DEFAULT-ACCOUNTS-001 y boundaries de patch-level en DBA_USERS

### Causa raíz

`Q-SEC-DEFAULT-ACCOUNTS-001` declaraba `min: "11.0"` (implicit_full_range) y seleccionaba
incondicionalmente `DBA_USERS.ORACLE_MAINTAINED` — sólo pasó certificación porque el Defecto 1
nunca ejecutó el chequeo de version-gating sobre `DBA_USERS`.

### Verificación de boundaries reales (WebSearch/WebFetch, múltiples fuentes independientes)

| Columna | Boundary registrado antes | Boundary real verificado | Fuente |
|---|---|---|---|
| `ORACLE_MAINTAINED` | `12.1` | `12.1.0.1` (sin cambio, ya correcto) | Blog datado 2013-07-17 (~3 semanas post-GA de 12.1.0.1, un año antes de que existiera 12.1.0.2) consultando la columna |
| `COMMON` | `12.1` | `12.1.0.1` (sin cambio, ya correcto) | Oracle 12.1.0.1 New Features Guide — "The multitenant architecture is new in Oracle Database 12c Release 1 (12.1)" |
| `LAST_LOGIN` | `12.1` | **`12.1.0.2`** (corregido) | My Oracle Support KM + múltiples fuentes independientes citando "12.1.0.2" explícitamente |

Una síntesis de WebFetch inicial afirmó que las 3 columnas requerían `12.1.0.2` — en ese momento
descartada por contradecir evidencia fechada independiente. **Nota (superado)**: esa síntesis
inicial resultó ser CORRECTA — `docs/PHASE_8_FINAL_DBA_USERS_12102_SOURCE_OF_TRUTH_CORRECTION.md`
verificó el HTML crudo (sin resumen de modelo) de la página oficial de `DBA_USERS` y confirmó un
footnote oficial explícito adjunto a las 3 columnas: "This column is available starting with
Oracle Database 12c Release 1 (12.1.0.2)." La tabla de arriba (`ORACLE_MAINTAINED`/`COMMON` en
`12.1.0.1`) y el resto de esta sección (variantes V1/V2 de ambas queries) quedan **obsoletos** —
ver el documento de corrección final para los boundaries y variantes reales. Se conserva este
texto histórico sin reescribir como registro de lo investigado en este hardening.

### Fix — Q-SEC-DEFAULT-ACCOUNTS-001 (histórico, superado — ver corrección final)

Dividida en 2 variantes: `V1` (`legacy_11g`, 11.0-11.2, sin `oracle_maintained`) y `V2`
(`modern_12plus`, 12.1-23.0, con `oracle_maintained`). Output normalization documentado:
`default_account: {username_token, account_status, oracle_maintained, source_variant}`, `V1`
publica `oracle_maintained: NOT_AVAILABLE`.

### Fix — Q-SEC-ACCOUNT-INVENTORY-001 (histórico, superado — ver corrección final)

Dividida de 2 a 3 variantes: `V1` (`legacy_pre12c`, 10.2-11.2, sin cambios), `V2`
(`multitenant_no_last_login`, 12.1-12.1.0.1, con `common`/`oracle_maintained`/
`authentication_type` pero SIN `last_login`), `V3` (`modern_12102plus`, 12.1.0.2-23.0, con
`last_login`). La `V2` original (min "12.1", con `last_login` incluido) habría certificado
incorrectamente la columna para 12.1.0.1, donde no existe — exactamente el defecto que el
Defecto 1 impedía detectar.

### Certificación columna-por-columna, nunca mecánica

`12.1.0.2` se aplicó ÚNICAMENTE a `LAST_LOGIN` — `COMMON`/`ORACLE_MAINTAINED` permanecen en
`12.1` (`12.1.0.1`) en el dictionary, sin degradar su certificación real. Los nombres de test
sugeridos por el prompt original de este hardening (`test_dba_users_oracle_maintained_12101_invalid`,
`test_dba_users_common_12101_invalid`) habrían codificado una aserción FALSA — se crearon en su
lugar `test_dba_users_oracle_maintained_12101_valid.sh`/`test_dba_users_common_12101_valid.sh`,
con la desviación documentada explícitamente en cada archivo.

## Defecto 3 — SQLNET.\* no es evidencia de V$PARAMETER

### Causa raíz

`Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` consultaba `V$PARAMETER` filtrando por
`sqlnet.encryption_client`/etc. — `SQLNET.*` es configuración de **Oracle Net** (`sqlnet.ora`),
estructuralmente fuera del alcance de `V$PARAMETER` (que refleja `init.ora`/`spfile`). Ninguna
versión certificaría correctamente esta query porque la fuente misma era incorrecta — nuevo
estado `INCORRECT_EVIDENCE_SOURCE` (`docs/QUERY_VARIANTS.md#estados-de-evaluación`), distinto de
`INCORRECT_VERSION_RANGE`.

### Fix

`Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` retirada (`status: not_certified`,
`not_certified_reason: INCORRECT_EVIDENCE_SOURCE`) — conservada como registro histórico del
defecto, removida de `config/query-compatibility-matrix.yaml` (no es una query activa con
variantes que certificar) y de `queries/REGISTRY.md` (fila marcada RETIRADA). Reemplazada por el
collector semántico `get_oracle_net_security_configuration`
(`skills/network/oracle-net-security/SKILL.md`, propiedad de `oracle-network-analyst`,
`# 27`/`# 31` del prompt de hardening: Security interpreta compliance/riesgo, Network obtiene el
evidence model read-only).

### Collector semántico — allowlist estricta

Únicamente `SQLNET.ENCRYPTION_SERVER/CLIENT`, `SQLNET.ENCRYPTION_TYPES_SERVER/CLIENT`,
`SQLNET.CRYPTO_CHECKSUM_SERVER/CLIENT`, `SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER/CLIENT`, más
metadata TCPS explícitamente permitida. Nunca un lector de archivo genérico
(`read_file(path)`/`cat_file(path)` con path arbitrario) ni shell arbitrario
(`execute_shell(command)`) — el path se resuelve por convención de plataforma, nunca recibido del
modelo (mismo canal que `net-config-collector`, ya certificado desde Fase 4).

### Fallback sin collector runtime

`capability_status: PARTIALLY_SUPPORTED`, `evidence_source:
MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION` — el DBA provee `sqlnet.ora` ya sanitizado (mismo
patrón de ingest que los parsers RMAN de Fase 7: texto ya producido manualmente, nunca ejecutado
por el e-stack). Nunca se finge `SUPPORTED` sin evidencia real.

### TLS/TCPS vs. Native Network Encryption

`security/tls-awareness` (TLS/TCPS) y `security/network-encryption` (Native Network Encryption)
permanecen skills separadas, consumiendo ambas el mismo collector — nunca mezclados como si
fueran el mismo mecanismo (`# 32` del prompt de hardening).

## Static Validator — cobertura extendida (verificación)

```text
V$/GV$ objects                            PASS (sin cambios, regresión completa)
DBA_* objects                             PASS (nuevo — Defecto 1)
CDB_* objects                             PASS (nuevo — Defecto 1)
ALL_/USER_ objects                        PASS (nuevo — Defecto 1, cobertura genérica)
Otros objetos del dictionary               PASS (nuevo — Defecto 1, cobertura genérica)
Alias-qualified columns (DBA_*)           PASS (nuevo — test_static_validator_checks_dba_alias_columns.sh)
Unknown DBA columns rechazadas            PASS (nuevo — test_static_validator_rejects_unknown_dba_column.sh)
Column min_version enforced (DBA_*)       PASS (nuevo — test_static_validator_checks_dba_column_min_version.sh)
Patch-level enforced (12.1.0.1/12.1.0.2)  PASS (nuevo — test_dba_users_*_121*.sh)
Multi-join validation                      PASS (sin cambios — ya soportado antes de este hardening)
```

## Tests

**14 tests nuevos**: `test_security_default_accounts.sh` (faltante desde la creación de la query,
detectado por `test_all_security_query_test_references_exist.sh`), `test_dba_users_last_login_12101_invalid.sh`,
`test_dba_users_last_login_12102_valid.sh`, `test_dba_users_oracle_maintained_12101_valid.sh`,
`test_dba_users_common_12101_valid.sh`, `test_static_validator_validates_non_v_dollar_dictionary_objects.sh`,
`test_static_validator_checks_dba_alias_columns.sh`, `test_static_validator_rejects_unknown_dba_column.sh`,
`test_static_validator_checks_dba_column_min_version.sh`, `test_sqlnet_parameters_not_sourced_from_v_parameter.sh`,
`test_network_encryption_uses_network_evidence.sh`, `test_oracle_net_collector_no_arbitrary_file_read.sh`,
`test_oracle_net_collector_no_arbitrary_shell.sh`, `test_network_encryption_partial_without_collector.sh`,
`test_all_security_query_test_references_exist.sh` (15 en total).

**Tests modificados**: `test_security_account_inventory.sh` (3 variantes en vez de 2),
`test_network_encryption_awareness.sh` (reescrito — ya no valida la query retirada como fuente
activa).

## Files created

`docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md` (este documento),
`skills/network/oracle-net-security/{SKILL.md,manifest.yaml}`, 15 archivos `tests/test_*.sh`
nuevos (listados arriba).

## Files modified

`tests/test_sql_static_validator.sh` (fix sistémico Defecto 1), `compatibility/oracle-dictionary/views.yaml`
(`LAST_LOGIN` → `12.1.0.2`), `queries/security/Q-SEC-DEFAULT-ACCOUNTS-001.md`,
`queries/security/Q-SEC-ACCOUNT-INVENTORY-001.md`, `queries/security/Q-SEC-NETWORK-ENCRYPTION-PARAMS-001.md`
(retirada), `config/query-compatibility-matrix.yaml`, `queries/REGISTRY.md`, `skills/security/network-encryption/{SKILL.md,manifest.yaml}`,
`skills/security/tls-awareness/SKILL.md`, `agents/oracle-network-analyst/{AGENT.md,manifest.yaml}`,
`collectors/README.md`, `docs/QUERY_VARIANTS.md` (nuevo estado `INCORRECT_EVIDENCE_SOURCE`),
`docs/CAPABILITY_MATRIX.md`, `skills/REGISTRY.md`, `tests/test_security_account_inventory.sh`,
`tests/test_network_encryption_awareness.sh`, `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md`,
`CHANGELOG.md`.

## Known limitations

- `network/oracle-net-security` permanece `CONTRACT_DEFINED / NOT_RUNTIME_CERTIFIED` — el
  Gateway MCP real es Fase 13 (roadmap vigente) para todo collector del e-stack, no específico de
  esta skill. Corregido en el micro-hardening posterior (`PHASE 8 — DBA_USERS 12.1.0.2 BOUNDARY
  CERTIFICATION MICRO-HARDENING`) desde la referencia obsoleta "Fase 7", que ya se completó
  (Backup & Recovery/RMAN) sin entregar el Gateway runtime.
- La certificación columna-por-columna de `DBA_USERS` se limita a las columnas efectivamente
  usadas por el catálogo Phase 8 (`# 11` del prompt de hardening) — no es una certificación
  exhaustiva de toda columna de `DBA_USERS` documentada por Oracle.
- El Static Validator sigue sin ser un parser SQL completo (deliberado, `# 8` del prompt de
  Compatibility Hardening original) — subqueries anidadas siguen resultando en abstención, nunca
  falso positivo.

## NOT_CERTIFIED

`Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` — `INCORRECT_EVIDENCE_SOURCE`, retirada permanentemente,
reemplazada por `network/oracle-net-security`.

## NOT_CERTIFIED COLLECTORS

`get_oracle_net_security_configuration` — especificación certificada, `NOT_RUNTIME_CERTIFIED`
(Gateway MCP real es Fase 13, roadmap vigente, para todos los collectors del e-stack).
