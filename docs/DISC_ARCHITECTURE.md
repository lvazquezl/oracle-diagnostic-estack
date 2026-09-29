# CHG-ESTACK-DISC-ARCHITECTURE-001 — Arquitectura observada (RAC, ASM, Data Guard, SO) frente a la declarada

**Tipo:** `/change query|compatibility|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/disc-architecture` (desde `change/dict-pseudo-columns`, `4cca5cb`, PR #20)
**Origen:** `CHG-REQ-LAB-DISC-STORAGE` (ampliado a RAC, Data Guard y SO)
**Estado:** aprobado por revisión humana (§11), validado en el lab (§8). Pendiente: `PROMOTE` (acción humana).

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

La arquitectura del target (RAC, ASM, Data Guard, rol, SO) sólo se **declaraba** en el targets file. En el lab estuvo mal declarada (`asm: false` con ASM en uso) sin que nada lo detectara, y la discovery de `ANA-20260922-002` la dejó `ENVIRONMENT_UNKNOWN`. Desde `CHG-ESTACK-VALIDATION-MATRIX-001` esas dimensiones deciden el nivel de validación en campo: una declaración errónea da un nivel equivocado.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `queries/oracle/discovery/Q-DISC-ARCHITECTURE-001.md` (nueva) | Una fila de hechos agregados: `instance_count`, `cluster_database`, `datafiles_total`/`datafiles_in_asm` (sólo conteo), `asm_diskgroups`, `database_role`, `standby_destinations`, `os_family` (calculada en la base a partir de `PLATFORM_NAME`). 11.2–23.0 |
| `mcp_gateway/architecture.py` (nuevo) | Deduce `rac`/`asm`/`dataguard`/`role`/`os_family`. Un hecho descartado queda desconocido, nunca `false` |
| `mcp_gateway/gateway.py` | Al recoger la query, agrega `architecture_check` (observado, declarado, diferencias) y la limitación `DECLARED_ARCHITECTURE_MISMATCH:<dim>`. Con datos **REAL**, lo observado reemplaza a lo declarado **para la validación en campo** en esa sesión. Los fixtures nunca reemplazan nada |
| Diccionario | `V$DATABASE.PLATFORM_NAME`, `V$DATAFILE.NAME`, `GV$INSTANCE.INST_ID` declaradas (las verifica `Q-DICT-VERIFY`, regeneradas: 490 tokens) |
| Catálogo, fixtures, registros | Collector con enums cerrados (`cluster_database`, `database_role`, `os_family`); fixtures `fixture-primary-19c`/`fixture-standby-19c`; matriz, `queries/REGISTRY.md`, readiness (86 componentes), docs |
| `mcp_gateway_lab` 0.6.0 | Collector habilitable en el lab |
| Tests | P15 +1 (flujo real con driver falso), P16 +2; enrutamiento del driver falso corregido (la identidad capturaba sentencias que mencionan `v$instance`); `test_query_variant_resolver_10g`: 10g sin variante |

## 3. GAP ANALYSIS

1. **Sin nombres:** ni instancias, ni disk groups, ni destinos, ni rutas. `V$DATAFILE.NAME` se usa sólo dentro de la base para contar `LIKE '+%'`.
2. **La distribución del SO** (OL/RHEL/SLES) no es observable por SQL: sólo la familia (`LINUX`, `AIX`…). Si la familia observada difiere de la declarada, se descartan distribución y versión declaradas.
3. **Límites:** un Data Guard sin destino `STANDBY` válido visto desde el primary se ve como `dataguard: false` (el standby lo reporta por rol). RAC One Node no se distingue.
4. **No se corrige el targets file:** la diferencia se reporta; el archivo lo corrige una persona.
5. **Verificación del diccionario:** vuelve a regenerarse, así que hay que revalidar en el lab.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries | +1 (`R0`, `LOW`, 1 fila, 2 KiB) |
| Privilegios | Cubiertos por `SELECT_CATALOG_ROLE` (ya otorgado en el lab) |
| Gateway | Campo nuevo `architecture_check` en `collect` de esa query; la validación en campo usa lo observado en la sesión |
| Lab | 0.5.0 → 0.6.0; hay que agregar el collector al targets file privado |

## 5. TEST

- P15: el flujo real con driver falso compara observado y declarado, marca `asm` como diferencia y la validación posterior usa lo observado.
- P16: deducción conservadora (lo desconocido queda desconocido), y los fixtures no alteran la validación.
- Mutaciones, 5/5 detectadas:
  - un fixture que reemplaza lo declarado (el caso se reforzó tras sobrevivir la primera vez);
  - un hecho descartado que pasa a `false`;
  - validación que ignora lo observado;
  - diferencia sin limitación;
  - RAC deducido sin `cluster_database`.

## 6. SECURITY VALIDATION

Una fila de conteos y enums; ningún identificador ni ruta sale de la base. `SELECT` certificado, hash verificado. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): 967/967 antes; después, con la revalidación registrada (§8), ver la cifra final en §12.

## 8. Validación en el lab

**Intento 1** (2026-09-29T01:34Z, commit `faf67e5`, `REQ-8bed90e4cb1b`, `EVR-50b00c558b1a39b2d0106c46`): `DEGRADED`, `INVALID_VALUES_DROPPED:1`. `platform_name` no estaba en la lista cerrada de nombres de plataforma, así que el enum lo descartó y nunca salió. Probablemente es la plataforma ARM (aarch64) de la VM del lab, no incluida en la lista. El resto coincidió con lo declarado: RAC no, ASM sí (8/8 datafiles, 1 disk group), PRIMARY, Data Guard no. **Corrección:** la base reduce `PLATFORM_NAME` a una familia (`CASE ... LIKE`) y sale sólo `os_family`, un enum cerrado de 7 valores. Así el resultado no depende de conocer cada nombre de plataforma. Las 5 `Q-DICT-VERIFY` del mismo intento sólo reportaron Statspack (490 tokens):

| Parte | `REQ` | `EVR` | `query_sha256` |
|---|---|---|---|
| 001 | `REQ-bab7cbd8b98c` | `EVR-2854f2a67a410c5e5d806f57` | `9611969a…bab4` |
| 002 | `REQ-499f23884fda` | `EVR-8bd80491c9b4bb1739c782c7` | `20db6b79…00c3` |
| 003 | `REQ-e29dd53ebaaf` | `EVR-20c3cbcf3aa29733a748e847` | `b494c890…389b` |
| 004 | `REQ-82da98693372` | `EVR-58f984a51b9cdc605313c9a7` | `62772eff…110c` |
| 005 | `REQ-5a4c0b2e3c6b` | `EVR-a893c21e979fb986549663d9` | `2f57ece7…50a4` |

La corrección del intento 2 no toca el diccionario, así que esos hashes siguen vigentes y se registran como validación en campo.

**Intento 2** (2026-09-29T01:41Z, commit `9a876c0`, `REQ-020de303d90b`, `EVR-e8d169ad1f2b8985f7088a21`, `query_sha256` `0940541b…d365`): `OK`, sin limitaciones.
- Observado: RAC no, ASM sí (8/8 datafiles, 1 disk group), PRIMARY, Data Guard no, `os_family: LINUX`.
- **Sin diferencias** con lo declarado (`applies_to_field_validation: true`).
- En la misma sesión, `Q-DISC-IDENTITY-001` (`REQ-58a71f207523`) sale `FIELD_VALIDATED` con el contexto observado.

Registro de validación en campo (`config/field-validation-registry.json`): se agrega `Q-DISC-ARCHITECTURE-001` (intento 2) y se actualizan `Q-DICT-VERIFY-001` … `-005` (intento 1).

## 9–10. Registros relacionados

- Cierra `CHG-REQ-LAB-DISC-STORAGE`.
- Base para `CHG-REQ-VALIDATION-RU` (el RU observado entra por la identidad).

## 11. HUMAN REVIEW — aprobado

`AUTH-DISC-ARCHITECTURE-001`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-29T02:06:54Z`, contra el digest `fadf6bf3…4f199a1e`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

Regresión final (macOS, bash 5.3.20): **968/968**. `advise --mode estack` (2026-09-29T01:58:56Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: fadf6bf3ff845186800e45a4c8d89f32e5521cd2501be8770b20dae44f199a1e`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-DISC-ARCHITECTURE-001/`.
