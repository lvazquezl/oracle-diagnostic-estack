# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING

Baseline: `phase/7-backup-recovery-rman` posterior a `PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN`. Objetivo: cerrar el defecto de compatibilidad SQL detectado antes de aprobar `v0.7.0-backup-recovery-rman`.

## Root cause

`tests/test_sql_static_validator.sh` certificaba SQL por dos ejes: (1) vistas/columnas version-gated (`compatibility/oracle-dictionary/views.yaml`), (2) existencia de columna en la vista. **Ningún chequeo inspeccionaba la sintaxis SQL del bloque en sí** — el modelo de compatibilidad del repositorio nunca había cubierto la dimensión "¿esta cláusula del lenguaje SQL existe en esta versión de Oracle?". Como resultado, 10 queries `queries/rman/Q-RMAN-*.md` certificaron `min_version: "10.2"` mientras usaban `FETCH FIRST ... ROWS ONLY` — row limiting clause ANSI SQL:2008, introducida en Oracle Database 12.1 (verificado vía WebFetch contra docs.oracle.com). Ver `docs/ORACLE_SQL_SYNTAX_COMPATIBILITY_MODEL.md` para el análisis completo.

## Affected queries

Las 10 queries que el prompt de este hardening listó explícitamente, confirmadas por auditoría directa (whitespace-tolerant) de sus bloques SQL reales — el primer intento de auditoría con una cadena literal `"FETCH FIRST"` (espacio simple) no detectó nada porque el SQL certificado usa `FETCH  FIRST` (doble espacio, alineación visual), confirmando en la práctica la advertencia del prompt sección 15 ("no depender de una sola cadena exacta"):

```text
Q-RMAN-ARCHIVED-LOG-COVERAGE-001    (implicit_full_range min 10.2 -> split)
Q-RMAN-ARCHIVELOG-BACKUP-001        (implicit_full_range min 10.2 -> split)
Q-RMAN-BACKUP-DATAFILE-001          (implicit_full_range min 10.2 -> split)
Q-RMAN-BACKUP-JOB-001               (implicit_full_range min 10.2 -> split)
Q-RMAN-BACKUP-PIECE-001             (implicit_full_range min 10.2 -> split)
Q-RMAN-BACKUP-SET-001               (ya tenía 2 variantes — sólo V1 legacy corregida in-place)
Q-RMAN-CONTROLFILE-BACKUP-001       (implicit_full_range min 10.2 -> split)
Q-RMAN-OUTPUT-001                   (implicit_full_range min 10.2 -> split, preserva bind :session_recid)
Q-RMAN-SPFILE-BACKUP-001            (implicit_full_range min 10.2 -> split)
Q-RMAN-STATUS-001                   (implicit_full_range min 10.2 -> split)
```

Sin `OFFSET` en ningún query certificado. Las 4 queries RMAN restantes (`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-DEVICE-001`, `Q-RMAN-CONTROLFILE-RECORD-SECTION-001`, `Q-RMAN-FRA-USAGE-001`) nunca usaron row limiting — result sets inherentemente pequeños, sin cambios.

## Legacy variants

Las 9 queries `implicit_full_range` se dividieron en `-V1` (`legacy_10g_11g`, `min: "10.2", max: "11.2"`) y `-V2` (`modern_12plus`, `min: "12.1", max: "23.0"`). `Q-RMAN-BACKUP-SET-001` mantuvo su split preexistente por `CON_ID` (`legacy_pre_multitenant`/`multitenant_aware`) sin rehacerlo — sólo se corrigió la sintaxis Top-N de su variante V1.

Patrón legacy aplicado uniformemente:

```sql
SELECT *
FROM (
  SELECT <mismas columnas ya certificadas>
  FROM   <misma vista ya certificada>
  WHERE  <mismo filtro, si existía>
  ORDER  BY <mismo ORDER BY ya certificado>
)
WHERE  ROWNUM <= <mismo límite ya certificado>;
```

`ORDER BY` siempre dentro del inline view, antes de `ROWNUM` — preserva exactamente el mismo Top-N semántico que la variante moderna (`# 30` del prompt: nunca `ROWNUM` aplicado antes de ordenar).

## Modern variants

Sin cambios de contenido — el bloque `FETCH FIRST` ya certificado se conserva tal cual, sólo con su `min_version` corregido a `12.1` (antes `10.2`, incorrecto).

## SQL syntax feature model

`compatibility/oracle-sql-syntax/features.yaml` (nuevo, separado deliberadamente del dictionary de vistas/columnas) — 2 features: `FETCH_FIRST` (min 12.1), `OFFSET_ROWS` (min 12.1, registrada preventivamente sin uso actual). Ver `docs/ORACLE_SQL_SYNTAX_COMPATIBILITY_MODEL.md`.

## Static validator extension

`tests/test_sql_static_validator.sh` — Chequeo 4 nuevo (`check_syntax_features`), aplicado en ambos loops existentes (variantes explícitas e `implicit_full_range`), usando `scripts/lib/version.sh#version_gte` exclusivamente — ningún comparador local nuevo. Regla: `variant.min_version < feature.min_version → NOT_CERTIFIED`. Verificado unitariamente contra los 5 casos del prompt (`# 18`) antes de tocar ningún query real:

```text
FETCH FIRST + min 10.2   → FAIL / NOT_CERTIFIED   (verificado)
FETCH FIRST + min 11.2   → FAIL / NOT_CERTIFIED   (verificado)
FETCH FIRST + min 12.1   → PASS                   (verificado)
ROWNUM + min 10.2        → PASS                   (verificado)
```

## Tests

14 tests nuevos: `test_sql_syntax_feature_matrix_exists`, `test_fetch_first_min_version_121`, `test_offset_min_version_121`, `test_static_validator_rejects_fetch_first_pre12c` (fixture negativo embebido, `# 21` del prompt), `test_static_validator_accepts_fetch_first_12c` (fixture positivo, `# 22`), `test_static_validator_accepts_rownum_10g` (fixture positivo legacy, `# 23`), `test_no_fetch_first_in_pre12c_queries` (regresión global, todo `queries/**`), `test_no_offset_in_pre12c_queries` (ídem), `test_rman_legacy_variant_10g`, `test_rman_legacy_variant_11g`, `test_rman_modern_variant_12c`, `test_rman_modern_variant_19c`, `test_rman_modern_variant_23ai` (resolución de variante RMAN-scoped por versión).

## No reconstruido

Agente `oracle-backup-recovery-analyst`, 30 skills `rman/*`, 6 parsers, readiness (restore/recovery), workflows, FRA/channels/SBT logic, RMAN safety model, y las 7 vistas listadas en `# 28` del prompt (`V$RMAN_BACKUP_JOB_DETAILS`, `V$BACKUP_SET`, `V$BACKUP_PIECE`, `V$BACKUP_DATAFILE`, `V$BACKUP_REDOLOG`, `V$BACKUP_SPFILE`, `V$RMAN_CONFIGURATION`) — sin cambios, el único defecto era sintaxis Top-N.

## Known limitations

Ninguna respecto al alcance de este hardening. `OFFSET_ROWS` registrada sin ningún uso real todavía (preventivo, `# 16` del prompt) — no es una limitación, es el diseño pedido explícitamente.
