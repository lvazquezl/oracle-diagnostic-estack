# CHG-ESTACK-DICT-PSEUDO-COLUMNS-001 — Valores de fila (`row_values`) en lugar de pseudo-columnas

**Tipo:** `/change compatibility|documentation` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/dict-pseudo-columns` (desde `main` `ca8a26b`, `v0.21.0-field-validation-matrix`)
**Origen:** `CHG-REQ-DICT-PSEUDO-COLUMNS` (3 hallazgos restantes de la verificación del diccionario, `CHG-ESTACK-ORA19C-LAB-007` §8)
**Estado:** propuesto. Validado en el lab (§8). Pendiente: HUMAN REVIEW.

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

macOS (bash 5.3.20): antes 967/967. Después **968/968**, con la revalidación registrada (§8).

## 8. Validación en el lab

2026-09-29T00:32Z, `lab-ol8-19c` (19c RU 19.32, `CDB$ROOT`, ASM, OL 8.10), commit `251e4e0`. Las 5 partes corrieron `OK`/`REAL`, sin limitaciones: **487 tokens** (98 + 98 + 95 + 101 + 95). Sólo quedan `STATS$SNAPSHOT` y `STATS$SYSTEM_EVENT` (Statspack no instalado, esperado). Las 3 pseudo-columnas desaparecen; `V$PGASTAT.NAME/VALUE/UNIT` existen.

| Parte | `REQ` | `EVR` | `query_sha256` |
|---|---|---|---|
| 001 | `REQ-6011e9e3daec` | `EVR-8b4aeb1ffcb79c9f119f1b5d` | `498f1027…6ae58` |
| 002 | `REQ-aba58c385ae4` | `EVR-069627e9f2e6dd96da350356` | `aabf25d4…a8d16d` |
| 003 | `REQ-4552bb6aea4c` | `EVR-49406bf24da63b745102b082` | `b126c8a7…b6fd9` |
| 004 | `REQ-ba9dcdfcb616` | `EVR-ef0f999aa4107bdc055635e7` | `9314753d…42bca` |
| 005 | `REQ-7483a7067bd3` | `EVR-e2b876ad97d22987c8433abb` | `bdf25483…6c3ee` |

- **Validación en campo** (`CHG-ESTACK-VALIDATION-MATRIX-001`): antes de registrarse, el lanzador reportó `DOCUMENTATION_ONLY` / `SQL_CHANGED_SINCE_FIELD_VALIDATION` en las 5 partes, el comportamiento diseñado. Las 5 entradas de `config/field-validation-registry.json` se actualizaron con estos hashes, evidencias y este registro.
- **Alcance para Data Guard:** las 12 vistas de las 7 queries de `dataguard` y sus 64 columnas existen en el catálogo 19c. Los valores de fila (`'transport lag'`, `'apply lag'`) y el comportamiento en un standby **no** se validan en este lab (primary): las 7 queries siguen `DOCUMENTATION_ONLY` (`CHG-REQ-LAB-MULTIVERSION`, ampliado a Data Guard).

## 9–10. Registros relacionados

Cierra `CHG-REQ-DICT-PSEUDO-COLUMNS`.

## 11. HUMAN REVIEW (pendiente)

Revisor distinto del proponente, contra el `content_digest` del motor (§12).

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-29T00:35:42Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 6560fd0cd7f4ba5fbc66a376682a43809c28c351a5ac8c69b59ba70c0799e5ac`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-DICT-PSEUDO-COLUMNS-001/`.
