# Postura TDE en toda revisión

`/change skill|workflow|query|policy|security|documentation` — `CHG-ESTACK-TDE-POSTURE-001`. Rama `change/tde-posture` sobre `change/b7-security-coverage`; depende de `CHG-ESTACK-B7-SECURITY-COVERAGE-001`.

Origen: pedido del DBA de que toda revisión valide si hay algo de TDE configurado, sin necesidad de tenerlo licenciado, porque puede representar un riesgo, una mala configuración o una propuesta de mejora.

## Por qué

B7 expuso las lecturas de TDE, pero:
- solo se usaban si el alcance incluía seguridad;
- el skill `security/tde-awareness` declaraba la opción como requisito de licencia de la **lectura**;
- no clasificaba la postura: decía si el keystore estaba abierto o cerrado, pero no si eso era un riesgo, una mala configuración o una mejora.

Faltaban además datos para detectar los riesgos más comunes:
- si las llaves maestras están respaldadas y cuándo se rotaron;
- si el keystore es unido o aislado por PDB;
- cómo se ubica el keystore (`WALLET_ROOT`/`TDE_CONFIGURATION` o el método heredado de `sqlnet.ora`);
- si los tablespaces nuevos nacen cifrados.

## Cambios

**Paso fijo en `/assessment` y `/healthcheck`.**
- `security/tde-awareness` corre siempre, aunque no se pida seguridad y aunque la opción no esté licenciada: leer el estado no es usarla.
- El informe incluye siempre la sección **Postura de cifrado (TDE)**.
- Estas lecturas nunca se marcan `LICENSE_RESTRICTED`.

**Postura por contenedor:**

| Postura | Significado |
|---|---|
| `NOT_CONFIGURED` | Sin keystore, sin llaves y sin datos cifrados |
| `CONFIGURED_NOT_IN_USE` | Keystore o configuración presentes, sin datos cifrados |
| `IN_USE` | Al menos un tablespace o una columna cifrada |
| `UNDETERMINED` | Faltó evidencia; nunca se reporta `NOT_CONFIGURED` por falta de datos |
| `NOT_APPLICABLE` | 10.2–11.1 (sin `V$ENCRYPTION_WALLET`) |

**Hallazgos `TDE-01`..`TDE-13`** (tabla completa en `skills/security/tde-awareness/SKILL.md`):

| Categoría | Códigos |
|---|---|
| Riesgo | `TDE-01` datos cifrados con keystore cerrado o sin llave (CRITICAL); `TDE-02` keystore o llaves sin respaldo (HIGH); `TDE-03` keystore `PASSWORD` con datos cifrados (MEDIUM) |
| Mala configuración | `TDE-07` tablespaces sin cifrar con cifrado exigido (HIGH); `TDE-08` modo unido/aislado mixto o PDB en otro estado que el root (MEDIUM); `TDE-13` keystore sin uso (LOW) |
| Mejora | `TDE-04` `AUTOLOGIN` en vez de `LOCAL_AUTOLOGIN`; `TDE-05` llave sin rotar (8760 h por defecto); `TDE-06` `3DES168`/`AES128`; `TDE-09` `encrypt_new_tablespaces`; `TDE-10` keystore por `sqlnet.ora`; `TDE-11` TDE no configurado |
| Revisión de licencia | `TDE-12`: TDE en uso, `LICENSE_CHECK_REQUIRED`, sin afirmar cobertura |

**Evidencia:**
- **`Q-SEC-TDE-MASTER-KEYS-001` 1.0.0**, nueva (lote B8T): llaves maestras por contenedor, llaves sin respaldo y horas desde la activación más reciente. `key_id`, `tag`, creador y fechas nunca salen de la base.
- **`Q-SEC-TDE-WALLET-001` 2.1.0:** V3 (12.2+) con `keystore_mode`.
- **`Q-SEC-SECURITY-PARAMETERS-001` 2.1.0:** `encrypt_new_tablespaces`, `tde_configuration` (palabra clave cerrada) y `wallet_root`. Este último es una ruta: solo sale si está configurado o no (`isdefault`).

**No observable:** ubicación y permisos del keystore en el SO, su copia en un standby, el cifrado de los respaldos RMAN y `sqlnet.ora`. Se declaran como limitación, nunca se infieren.

**Licencias:** `policies/licensing-awareness-policy.md` agrega la regla "leer el estado de una opción no es usarla". `queries/REGISTRY.md` corrige la licencia de las lecturas de TDE a `none`, como sus contratos.

**Validaciones en campo retiradas** hasta revalidar en el lab, porque su SQL cambió: `Q-SEC-SECURITY-PARAMETERS-001`, `Q-SEC-TDE-WALLET-001` y las sondas `Q-DICT-VERIFY-001`..`004` (el registro pasa de 85 a 79).

## Validación en el lab

`lab-ol8-19c`, contexto `LAB-OL8-19C-CDBROOT-ASM`, 2026-10-27, evidencia REAL sanitizada:

| Query | Resultado | Evidencia |
|---|---|---|
| `Q-SEC-TDE-MASTER-KEYS-001` | 0 filas: sin llaves maestras | `EVR-11299e1e8a4c97a8d1b5e8a4` (`REQ-e7f2db62f594`) |
| `Q-SEC-TDE-WALLET-001` (V3) | root y PDB: `FILE`, `NOT_AVAILABLE`, `UNKNOWN`; `keystore_mode` `NONE` en el root y `UNITED` en el PDB | `EVR-c8090a3f0e303a40df49ed8f` (`REQ-a4f62dc7ceab`) |
| `Q-SEC-SECURITY-PARAMETERS-001` | 17 filas; `encrypt_new_tablespaces` `CLOUD_ONLY`, `tde_configuration` y `wallet_root` en default | `EVR-09475d2e9e3119da45f370aa` (`REQ-a1d0d935f53f`) |
| `Q-DICT-VERIFY-001` | `CHECKED` 110, sin columnas faltantes | `EVR-fb42362c879e6eadb0697a96` (`REQ-b69d545265b5`) |
| `Q-DICT-VERIFY-002` | `CHECKED` 110; `STATS$` `VIEW_NOT_FOUND` (Statspack no instalado, igual que en B7) | `EVR-94dc3ef9f326a7a7878b529e` (`REQ-000a96a1781d`) |
| `Q-DICT-VERIFY-003` | `CHECKED` 106, `keystore_mode` y `V$ENCRYPTION_KEYS` presentes | `EVR-501e52b03322ba63be3c2cdd` (`REQ-08c773eb9070`) |
| `Q-DICT-VERIFY-004` | `CHECKED` 109 | `EVR-977eb4ae4710a8c82cf9b82c` (`REQ-70c0215a93fa`) |

`Q-SEC-ENCRYPTED-TABLESPACES-001` (10 tablespaces `UNENCRYPTED`) y `Q-SEC-ENCRYPTED-COLUMNS-001` (0 filas) siguen `FIELD_VALIDATED` por B7.

**Revisión del especialista de seguridad:**
- Postura `NOT_CONFIGURED` en root y PDB (keystore `NOT_AVAILABLE`, sin llaves, sin datos cifrados, `wallet_root` y `tde_configuration` en default); global `NOT_CONFIGURED`. Hallazgo `TDE-11` IMPROVEMENT INFO; sin `TDE-12` porque no hay uso.
- En 19c el root reporta `keystore_mode` `NONE` siempre. `TDE-08` aclara que `NONE` en el root o en un non-CDB no es mezcla, y `tests/test_tde_posture.sh` lo verifica.
- Los casos `IN_USE` y `CONFIGURED_NOT_IN_USE` no se pueden observar en el lab sin usar la opción; quedan cubiertos por las pruebas sintéticas.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Pedido del DBA: validar TDE en toda revisión, sin depender de la licencia |
| CHANGE REQUEST | `CHG-ESTACK-TDE-POSTURE-001`, tipos `skill`, `workflow`, `query`, `policy`, `security` y `documentation` |
| GAP ANALYSIS | La lectura de TDE solo corría con alcance de seguridad; el skill no clasificaba la postura; faltaban llaves maestras, modo del keystore y parámetros |
| IMPACT ANALYSIS | Catálogo de 90 a 91 collectors; 2 queries cambian de SQL (revalidación en el lab); sin privilegios nuevos esperados (`V$ENCRYPTION_KEYS` con `SELECT_CATALOG_ROLE`); sin licencia; sin tools nuevas |
| PROPOSAL | Este documento |
| IMPLEMENT | Query nueva y lote B8T; 2 queries a 2.1.0; 4 campos y 8 palabras clave; diccionario (`V$ENCRYPTION_KEYS`, `keystore_mode`); matriz, registro de madurez (159 componentes), target de fixtures; skill 1.1.0; workflows `assessment` y `healthcheck`; agente de seguridad; política de licencias |
| TEST | P18 37/37 (caso nuevo de la postura); `tests/test_tde_posture.sh` 42/42 (incluye `TDE-08` con `NONE` en el root) |
| SECURITY | 12/12 mutaciones detectadas: severidad de `TDE-01` rebajada, `TDE-12` sin `LICENSE_CHECK_REQUIRED`, gate de licencia en el manifest, paso fijo quitado de `assessment`, collector quitado de `healthcheck`, `NOT_CONFIGURED` sin evidencia, `key_id` expuesto, licencia en la query nueva, valor crudo de parámetro, `wallet_root` fuera de la lista, V3 sin `keystore_mode`, regla "leer no es usar" quitada |
| REGRESSION | 974/974 en macOS (bash 5.3), con `tests/test_tde_posture.sh`; repetida tras el lab: 974/974 |
| LAB | `lab-ol8-19c` (19.32, CDB root, ASM): 3 collectors de TDE y 4 sondas del diccionario `FIELD_VALIDATED` con la cuenta de diagnóstico, sin privilegios nuevos; registro de 79 a 86. Postura del lab `NOT_CONFIGURED` → `TDE-11` |
| HUMAN REVIEW | Aprobado: `AUTH-TDE-POSTURE-001`, revisor `REV-DBAMANAGER`, `2026-10-28T00:16:08Z`, contra el digest `5d67f4cc…8f565f0b` (`STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`). PROMOTE: pendiente (push, PR y merge, acciones humanas) |
