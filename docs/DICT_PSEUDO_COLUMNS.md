# CHG-ESTACK-DICT-PSEUDO-COLUMNS-001 — Valores de fila (`row_values`) en lugar de pseudo-columnas

**Tipo:** `/change compatibility|documentation` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/dict-pseudo-columns` (desde `main` `ca8a26b`, `v0.21.0-field-validation-matrix`)
**Origen:** `CHG-REQ-DICT-PSEUDO-COLUMNS` (3 hallazgos restantes de la verificación del diccionario, `CHG-ESTACK-ORA19C-LAB-007` §8)
**Estado:** propuesto. Pendiente: validación en el lab (§8) y HUMAN REVIEW.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

La verificación del diccionario contra el catálogo real de 19c reporta `COLUMN_NOT_FOUND` para 3 entradas que no son columnas:

| Entrada | Qué es en realidad |
|---|---|
| `V$DATAGUARD_STATS.TRANSPORT_LAG`, `.APPLY_LAG` | Valores de la columna `NAME` (`'transport lag'`, `'apply lag'`), que `Q-DG-STATS-001` filtra con `WHERE name IN (...)` |
| `V$PGASTAT.PGA_AGGREGATE_LIMIT_ROW` | Marcador documental: su propia nota dice que no existe como fila ni como columna |

El diccionario no tenía dónde registrar **valores** de una columna con su versión mínima, así que se modelaron como columnas.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `compatibility/oracle-dictionary/views.yaml` | Sección nueva `row_values:` (formato documentado en la cabecera). `V$DATAGUARD_STATS`: `name`/`value`/`unit` como columnas; `'transport lag'`/`'apply lag'` (11.0) como valores. `V$PGASTAT`: `name`/`value`/`unit` como columnas; los 5 nombres que usa `Q-PERF-PGA-001` como valores; sale `pga_aggregate_limit_row` (la nota pasa a la vista) |
| `tests/test_dictionary_row_values.sh` (nuevo) | Toda columna de `row_values` debe ser una columna declarada; ninguna `*_row` bajo `columns:`; todo literal que una query certificada use en `name IN (...)` o `DECODE(name, '...')` sobre esas vistas debe estar registrado |
| `Q-DICT-VERIFY-001` … `-005`, collectors, fixtures | Regeneradas (487 tokens): salen las 3 pseudo-columnas; entran `V$PGASTAT.NAME/VALUE/UNIT` |
| `config/field-validation-registry.json` | Las 5 entradas de `Q-DICT-VERIFY` se actualizan tras la revalidación en el lab (§8): su SQL cambió |

## 3. GAP ANALYSIS

- **Qué verifica cada mecanismo:** el validador estático y el generador de la verificación sólo leen `columns:`, así que `row_values:` no los afecta. Los valores de fila **no** los verifica el catálogo (no están en `DBA_TAB_COLUMNS`). `'transport lag'`/`'apply lag'` sólo tienen filas en un standby; en el lab (primary) siguen validados sólo por documentación.
- **Versión:** que un valor falte en una versión no es error: la fila no aparece (ver `docs/QUERY_VARIANTS.md`). El guard exige **registro**, no versión.
- **Validación en campo** (`CHG-ESTACK-VALIDATION-MATRIX-001`): regenerar `Q-DICT-VERIFY` cambia su `query_sha256`, y el registro exige revalidar o retirar. Es el mecanismo funcionando.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries certificadas | Ninguna cambia (`Q-DG-STATS-001` y `Q-PERF-PGA-001` intactas) |
| Diccionario | Estructura nueva opcional `row_values:` |
| Verificación del diccionario | 5 partes regeneradas; SQL nuevo → revalidación |
| Gateway, lab, licencia, costo | Sin cambios |

## 5. TEST

- Guard nuevo; 3 mutaciones detectadas: un valor no registrado en `Q-DG-STATS-001`, un valor con otro texto en `Q-PERF-PGA-001` y una pseudo-columna `*_row` bajo `columns:`.
- `test_field_validation` detecta que el SQL de `Q-DICT-VERIFY-*` cambió y exige revalidar (esperado hasta §8).

## 6. SECURITY VALIDATION

Sólo metadatos del diccionario del e-stack; sin cambios de acceso. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): antes 967/967. Después: 967/968, con `test_field_validation` en espera de la revalidación (§8).

## 8. Validación en el lab (pendiente)

Con esta rama en el workspace principal y el lab reconectado, las 5 partes deben reportar **sólo** `STATS$SNAPSHOT` y `STATS$SYSTEM_EVENT` (Statspack no instalado). Después se actualizan en el registro de validación en campo los `query_sha256`, `EVR` y la fecha de las 5 partes.

## 9–10. Registros relacionados

Cierra `CHG-REQ-DICT-PSEUDO-COLUMNS`.

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)
