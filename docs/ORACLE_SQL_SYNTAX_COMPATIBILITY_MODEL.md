# Oracle SQL Syntax Compatibility Model — PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING

## Por qué la sintaxis SQL está versionada

Oracle SQL no es un lenguaje estático: cada mayor release puede introducir cláusulas nuevas (ANSI SQL estándar o extensiones propietarias) que simplemente no existen en versiones anteriores. Hasta este hardening, el e-stack certificaba compatibilidad de query por dos ejes únicamente:

1. **Vistas/columnas** (`compatibility/oracle-dictionary/`) — ¿la vista existe en esa versión? ¿la columna existe en esa vista, en esa versión?
2. **Versión declarada** (`oracle_versions.min/max` de cada variante) — el rango que la variante afirma cubrir.

Ninguno de los dos ejes modela la **sintaxis del propio SQL** — un `SELECT` puede referenciar únicamente vistas/columnas válidas para 10g y aun así ser sintácticamente inválido en 10g si usa una cláusula introducida después. Este fue exactamente el defecto real detectado en 10 queries `queries/rman/Q-RMAN-*.md`: todas certificaban `min_version: "10.2"` mientras usaban `FETCH FIRST ... ROWS ONLY` en su SQL — una cláusula que requiere Oracle Database 12c Release 1 (12.1). Ningún chequeo existente (vistas, columnas, versión declarada) podía detectar esto, porque ninguno inspeccionaba la sintaxis del bloque SQL en sí.

Este documento introduce un **tercer eje independiente**: el **SQL Syntax Feature Compatibility Model**, en `compatibility/oracle-sql-syntax/features.yaml`.

## Separación deliberada de `compatibility/oracle-dictionary/`

`compatibility/oracle-sql-syntax/features.yaml` **nunca** se mezcla con `compatibility/oracle-dictionary/views.yaml` (`# 12` del prompt de este hardening) — son dos dimensiones de compatibilidad genuinamente distintas:

| Dimensión | Fuente | Pregunta que responde |
|---|---|---|
| Vista/columna | `compatibility/oracle-dictionary/views.yaml` | ¿Existe `V$RMAN_STATUS.SESSION_RECID` en Oracle 10g? |
| Sintaxis SQL | `compatibility/oracle-sql-syntax/features.yaml` | ¿Es válida la cláusula `FETCH FIRST ... ROWS ONLY` en Oracle 10g? |

Un query puede fallar en cualquiera de las dos dimensiones independientemente — nunca se colapsan en un solo chequeo.

## FETCH FIRST boundary

La row limiting clause (`FETCH FIRST n ROWS ONLY`, `FETCH FIRST n ROWS WITH TIES`, `FETCH NEXT n ROWS ONLY`) es sintaxis ANSI SQL:2008, introducida en **Oracle Database 12c Release 1 (12.1)**. No existe en 10g ni 11g — en esas versiones, row limiting se implementa exclusivamente con el pseudocolumn `ROWNUM` (o funciones analíticas como `ROW_NUMBER() OVER (...)`, no usadas en este catálogo). Registrada como feature `FETCH_FIRST`, `min_version: "12.1"`.

## OFFSET boundary

`OFFSET n ROWS` es la misma cláusula ANSI SQL:2008 (row limiting con desplazamiento), mismo boundary 12.1. Registrada preventivamente como feature `OFFSET_ROWS` aunque ningún query certificado de Fase 7 la usa todavía — el modelo queda listo para detectar la misma clase de incompatibilidad si una query futura la introduce sin certificación adecuada (`# 16` del prompt de este hardening).

## Cómo el validator detecta features

`tests/test_sql_static_validator.sh#check_syntax_features` (Chequeo 4, añadido en este hardening) recorre `compatibility/oracle-sql-syntax/features.yaml`, y para cada feature registrada:

1. Aplica cada `syntax_patterns` (regex POSIX, case-insensitive, tolerante a espacios múltiples/tabs — `# 15` del prompt: "no depender de una sola cadena exacta") contra el bloque SQL certificado (comentarios `--` ya removidos).
2. Si algún patrón coincide, compara `variant.min_version` (o `implicit_full_range`'s `precise_min`) contra `feature.min_version` usando `scripts/lib/version.sh#version_gte` — **nunca** un comparador local.
3. Regla: `variant.min_version < feature.min_version` → `[FAIL] ... NOT_CERTIFIED`.

No es un parser SQL completo — misma disciplina que los Chequeos 1-3 (view/column existence): detección por patrón de texto, nunca análisis sintáctico real, deliberadamente fuera de alcance (`# 13` del prompt de este hardening).

## Cómo interactúa con el Query Variant Resolver

El Query Variant Resolver (`docs/QUERY_VARIANTS.md#query-variant-resolver`) sigue seleccionando la primera variante cuyo `[min, max]` cubre el `oracle_version` del Target Profile — sin cambios en su algoritmo. Lo que cambia es la **certificación previa**: una variante cuyo SQL usa una feature por encima de su `min_version` declarado nunca debió certificarse en primer lugar — el Static Validator la bloquea en build/test time, antes de que el Resolver pueda siquiera seleccionarla en producción. El Resolver confía en que toda variante que ve ya pasó el Static Validator completo (los 4 chequeos), igual que confiaba en los 3 chequeos anteriores.

## Metadata de feature — contrato

```yaml
feature_id: string                    # ej. FETCH_FIRST
syntax_patterns: [regex, ...]         # POSIX ERE, case-insensitive por convención del validator
min_version: "12.1"                   # nunca "latest" (# 14 del prompt)
max_certified_version: string|null    # sólo si la feature deja de existir en alguna versión futura
validation:
  source_type: ORACLE_DOCUMENTATION
  status: DOCUMENTATION_VALIDATED
  validated_versions: [...]
```

## Ejemplos de validación (verificados, `docs/PHASE_7_RMAN_LEGACY_SQL_SYNTAX_HARDENING.md#negative--positive-fixtures`)

```text
FETCH FIRST + min 10.2   → FAIL / NOT_CERTIFIED
FETCH FIRST + min 11.2   → FAIL / NOT_CERTIFIED
FETCH FIRST + min 12.1   → PASS
ROWNUM + min 10.2        → PASS
OFFSET ... ROWS + min 10.2 → FAIL / NOT_CERTIFIED
```

## Legacy row limiting (10g/11g)

```sql
SELECT *
FROM (
    SELECT ...
    FROM ...
    ORDER BY ...
)
WHERE ROWNUM <= :limit;
```

El `ORDER BY` vive **dentro** del inline view, antes de aplicar `ROWNUM` — aplicar `ROWNUM` antes de ordenar (`WHERE ROWNUM <= n ... ORDER BY ...` sin inline view) produce un Top-N sobre un orden arbitrario (el orden físico de acceso, no el semántico), alterando el resultado (`# 7`, `# 30` del prompt de este hardening).

## Modern row limiting (12.1+)

```sql
ORDER BY ...
FETCH FIRST n ROWS ONLY
```

Sólo cuando está documentalmente certificado para esa variante — nunca usado en una variante 10g/11g (`# 8` del prompt).

## Query Variant Contract — extensión

`docs/QUERY_VARIANTS.md` declara ahora explícitamente que la certificación de una variante incluye 4 dimensiones, no 3: view compatibility, column compatibility, **SQL syntax compatibility**, version compatibility (`# 33` del prompt de este hardening).
