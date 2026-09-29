# CHG-ESTACK-DISC-ARCHITECTURE-001 — Arquitectura observada (RAC, ASM, Data Guard, SO) frente a la declarada

**Tipo:** `/change query|compatibility|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/disc-architecture` (desde `change/dict-pseudo-columns`, `4cca5cb`, PR #20)
**Origen:** `CHG-REQ-LAB-DISC-STORAGE` (ampliado a RAC, Data Guard y SO)
**Estado:** propuesto. Pendiente: validación en el lab (§8) y HUMAN REVIEW.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

La arquitectura del target (RAC, ASM, Data Guard, rol, SO) sólo se **declaraba** en el targets file. En el lab estuvo mal declarada (`asm: false` con ASM en uso) sin que nada lo detectara, y la discovery de `ANA-20260922-002` la dejó `ENVIRONMENT_UNKNOWN`. Desde `CHG-ESTACK-VALIDATION-MATRIX-001` esas dimensiones deciden el nivel de validación en campo: una declaración errónea da un nivel equivocado.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `queries/oracle/discovery/Q-DISC-ARCHITECTURE-001.md` (nueva) | Una fila de hechos agregados: `instance_count`, `cluster_database`, `datafiles_total`/`datafiles_in_asm` (sólo conteo), `asm_diskgroups`, `database_role`, `standby_destinations`, `platform_name`. 11.2–23.0 |
| `mcp_gateway/architecture.py` (nuevo) | Deduce `rac`/`asm`/`dataguard`/`role`/`os_family`. Un hecho descartado queda desconocido, nunca `false` |
| `mcp_gateway/gateway.py` | Al recoger la query, agrega `architecture_check` (observado, declarado, diferencias) y la limitación `DECLARED_ARCHITECTURE_MISMATCH:<dim>`. Con datos **REAL**, lo observado reemplaza a lo declarado **para la validación en campo** en esa sesión. Los fixtures nunca reemplazan nada |
| Diccionario | `V$DATABASE.PLATFORM_NAME`, `V$DATAFILE.NAME`, `GV$INSTANCE.INST_ID` declaradas (las verifica `Q-DICT-VERIFY`, regeneradas: 490 tokens) |
| Catálogo, fixtures, registros | Collector con enums (`cluster_database`, `database_role`, `platform_name` con los nombres de plataforma de Oracle); fixtures `fixture-primary-19c`/`fixture-standby-19c`; matriz, `queries/REGISTRY.md`, readiness (86 componentes), docs |
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

macOS (bash 5.3.20): 967/968. El único fallo es `test_field_validation`, que exige revalidar en el lab las `Q-DICT-VERIFY` regeneradas (§8).

## 8. Validación en el lab (pendiente)

Con esta rama en el workspace principal, el collector agregado al targets file privado y el lab reconectado:
1. `Q-DISC-ARCHITECTURE-001` debe observar `asm: true`, `rac: false`, `dataguard: false`, `role: PRIMARY`, `os_family: LINUX`, sin diferencias con lo declarado (declaración corregida el 2026-09-25).
2. Las 5 `Q-DICT-VERIFY` sólo deben reportar Statspack. Después se registran sus hashes y evidencias nuevos, y la validación en campo de `Q-DISC-ARCHITECTURE-001`.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-LAB-DISC-STORAGE`.
- Base para `CHG-REQ-VALIDATION-RU` (el RU observado entra por la identidad).

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)
