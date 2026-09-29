# CHG-ESTACK-CDB-TEMP-USAGE-001 — Uso de TEMP por PDB sin `JOIN` por número de archivo

**Tipo:** `/change query|skill` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/cdb-temp-usage` (desde `change/lab-revalidate-007`, `bd39a30`)
**Origen:** `CHG-REQ-QUERY-CDB-TEMP-USAGE` (`CHG-ESTACK-ORA19C-LAB-003`)
**Estado:** propuesto. Pendiente: validación en el lab (§8) y HUMAN REVIEW.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

En el lab 19c, desde `CDB$ROOT`, `Q-CDB-TEMP-001` 1.0.0 devolvió `allocated_bytes` pero `bytes_used`/`bytes_free` `NULL` (`REQ-e33c5e987c1e`). Su `LEFT JOIN` entre `CDB_TEMP_FILES` y `GV$TEMP_SPACE_HEADER` por `FILE_ID` no encontró coincidencias. Por eso la query quedó fuera del adaptador lab, y un test de seguridad lo exigía.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `queries/multitenant/Q-CDB-TEMP-001.md` 2.0.0 (breaking) | Agrega ambos lados por `(CON_ID, TABLESPACE_NAME)` y une por eso, sin `FILE_ID`; usa `V$TEMP_SPACE_HEADER` (encabezados compartidos, sin duplicar en RAC) en lugar de `GV$`. Una fila por tablespace TEMP de cada PDB |
| `skills/multitenant/pdb-temp` 1.1.0 | Presión por PDB y tablespace; con uso nulo, `UNKNOWN` (nunca `LOW`) |
| `mcp_gateway_lab` 0.8.0 | Collector habilitado; el test que exigía rechazarlo se retira |
| Registros | Matriz, `queries/REGISTRY.md`, readiness (privilegios copiados de la query), diccionario (notas), `docs/PHASE_13_*` |
| Tests | P15 +1: la sentencia certificada se ejecuta textual, sin `gv$` ni `file_id` |

## 3. GAP ANALYSIS

- **No se adivina la numeración** (relativa frente a absoluta): se elimina la dependencia.
- **Plan B:** si en el lab el uso sigue nulo, `V$TEMP_SPACE_HEADER` no expone las PDB desde root, y se usará `GV$SORT_SEGMENT`, que requiere registrarla en el diccionario (otro cambio).
- La salida pasa de "por tempfile" a "por tablespace": breaking para quien contara archivos.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Query | 2.0.0; `CDB_ROOT_ONLY`, `R0`, `LOW` sin cambios |
| Skill | `multitenant/pdb-temp` 1.1.0 |
| Lab | 0.7.0 → 0.8.0; hay que agregar el collector al targets file privado |
| Privilegios | `SELECT_CATALOG_ROLE` + `CONTAINER_DATA` que ya tiene el usuario del lab |

## 5. TEST

P15 28/28 y 35/35. Mutación: con la query 1.0.0, el caso nuevo falla.

## 6. SECURITY VALIDATION

Sólo métricas agregadas y el nombre de tablespace enmascarado. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): **968/968**.

## 8. Validación en el lab (pendiente)

Desde `CDB$ROOT`: una fila por tablespace TEMP de `PRUEBAS` (`con_id` 3), con `allocated_bytes`, `bytes_used` y `bytes_free` **no nulos**. Si el uso llega nulo, se aplica el plan B (§3).

## 9–10. Registros relacionados

Cierra `CHG-REQ-QUERY-CDB-TEMP-USAGE`.

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)
