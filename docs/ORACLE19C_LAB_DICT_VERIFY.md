# CHG-ESTACK-ORA19C-LAB-006 — Verificación del diccionario contra el catálogo real (19c)

**Tipo:** `/change query|compatibility|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/lab-dict-verify` (desde `main` `ab6c90c`, `v0.18.0-portability`)
**Origen:** `CHG-REQ-LAB-DICT-VERIFY` (cubre `CHG-REQ-DICT-RMAN-AUDIT` para todos los dominios)
**Estado:** propuesto. Pendiente: grant y validación en el lab (§8), HUMAN REVIEW. `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

`compatibility/oracle-dictionary/views.yaml` es la base del validador estático. En `CHG-ESTACK-ORA19C-LAB-004` se descubrió en Oracle real que declaraba una columna inexistente (`V$BACKUP_REDOLOG.COMPLETION_TIME`) desde Fase 7, con marca `DOCUMENTATION_VALIDATED`. El validador no podía detectarlo porque compara contra ese mismo archivo. Hasta ahora sólo se verificaban contra una base real las columnas de las ~8 queries expuestas en el lab.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `scripts/dict_verify/generate.py` (nuevo) | Genera las queries y sus collectors **desde** `views.yaml`; `--check` detecta deriva |
| `queries/oracle/dictionary/Q-DICT-VERIFY-001` … `-005` (nuevas, generadas) | Cada una embebe una parte de la lista `VISTA.COLUMNA` declarada para 19c; la base compara contra `DBA_TAB_COLUMNS` y devuelve **sólo discrepancias** + una fila `CHECKED` |
| `compatibility/oracle-dictionary/views.yaml` | + `DBA_TAB_COLUMNS` (`owner`, `table_name`, `column_name`, exhaustiva) |
| `mcp_gateway/catalog/collectors.json` | 5 collectors (generados): campos `finding`/`view_name`/`column_name` como **enums** acotados a su parte del diccionario, `tokens` entero |
| `mcp_gateway_lab` `0.5.0` | Los 5 collectors en el adaptador lab |
| Registros | `config/query-compatibility-matrix.yaml`, `queries/REGISTRY.md`, `config/production-readiness-registry.json` (85 componentes), fixtures sintéticos en `fixture-primary-19c`, `docs/PHASE_13_*`, `docs/PRODUCTION_READINESS.md`, `docs/ORACLE19C_LAB_ADAPTER.md` |
| Tests | `tests/test_dict_verify_queries_match_dictionary.sh` (nuevo); P15 +1 caso adapter, +1 security; `test_query_variant_resolver_*` declaran las 5 como 19c-only |

## 3. GAP ANALYSIS

1. **Techo de SQL del lanzador (4000 caracteres, `mcp_gateway_lab/sqlsource.py`):** 477 tokens no caben en una sentencia. El techo **no se sube**: el generador reparte los tokens en 5 partes balanceadas (~3250 caracteres cada una, ~750 de margen). Si el diccionario crece, el generador crea una parte más y el guard de deriva obliga a registrarla.
2. **Techo de filas/bytes (200 / 64 KiB):** la base hace la comparación. La respuesta es sólo discrepancias (máx. 120 filas por parte, declaradas) + `CHECKED`. Un diccionario correcto devuelve 1 fila por parte.
3. **Guard de solo lectura:** prohíbe `sys.` (sin colecciones `SYS.ODCI*`) y palabras como `lock`. La lista viaja como **un literal** que la base parte con `REGEXP_SUBSTR … CONNECT BY LEVEL`. `V$LOCK` no se puede incluir sin esquivar el guard y **queda fuera**, documentado. El test exige que la lista de excluidos sea exactamente `['V$LOCK']`.
4. **Sanitización:** un campo `identifier` no admite KEEP, y enmascarar el nombre de una vista faltante destruiría el hallazgo. Se usan **enums**: sus valores permitidos son exactamente los nombres de esa parte del diccionario. Un nombre ajeno (p. ej. de una tabla de aplicación) se descarta y se reporta como `INVALID_VALUES_DROPPED`, sin salir nunca.
5. **Resolución de objetos:** `V$X`/`GV$X` son sinónimos públicos; se buscan como `V_$X`/`GV_$X`. Owners fijos: `SYS`, `AUDSYS` (auditoría unificada), `PERFSTAT` (Statspack). Si Statspack no está instalado, `STATS$*` salen como `VIEW_NOT_FOUND`, un hallazgo informativo. Lo mismo `DBA_DV_STATUS` sin Database Vault.
6. **Versión:** la lista depende de la versión (`min_version`). Se genera para **19c** (variante `19.0–19.0`). Las demás versiones quedan en `CHG-REQ-LAB-MULTIVERSION`.
7. **Dirección inversa:** columnas reales que faltan en listas `columns_exhaustive` no se detectan aquí (ese error se ve al desarrollar: el validador rechaza la query).

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries | +5 (`Q-DICT-VERIFY-001`…`-005`), 19c, `ANY_CONTAINER`, `R0`, `MEDIUM`, 30 s, 120 filas, 16 KiB |
| Diccionario | + `DBA_TAB_COLUMNS` |
| Gateway por defecto | 5 collectors con fixture sintético; `oracle_sql` `DISABLED` fuera del lab |
| Lab | `mcp_gateway_lab` 0.4.0 → 0.5.0; requiere grant (§8) y alta en el targets file privado |
| Privilegios | `SELECT_CATALOG_ROLE` (decisión del DBA, 2026-09-25: el proyecto usará el diccionario completo para análisis de eventos y assessments). El guard de sesión del lanzador revisa **privilegios de sistema** (`SESSION_PRIVS` ⊆ `CREATE SESSION`/`SELECT ANY DICTIONARY`); el rol da privilegios de objeto. Si trajera uno de sistema, el lanzador falla cerrado con `EXCESSIVE_SYSTEM_PRIVILEGES` |
| Licencia | Ninguna |

## 5. TEST

- `test_dict_verify_queries_match_dictionary`: las queries y los collectors coinciden con el diccionario. Además comprueba que cada sentencia pasa el guard y cabe en el techo, que las partes cubren cada token exactamente una vez, y que el regex y el techo del generador son los del gateway.
- P15: el bloque generado corre textual y sólo devuelve discrepancias (adapter). Un nombre fuera del enum nunca sale (security).
- Mutaciones, todas detectadas:
  - enum que admite un nombre ajeno;
  - collector fuera del adaptador lab;
  - owner extra en el generador;
  - query editada a mano;
  - techo de SQL relajado en el generador;
  - edición manual de una query, diccionario cambiado sin regenerar, archivo huérfano.

## 6. SECURITY VALIDATION

- Sólo `SELECT` sobre `DBA_TAB_COLUMNS`, con owners fijos en SQL certificado. La respuesta contiene nombres del diccionario del propio e-stack (enums), nunca datos ni nombres de aplicación.
- `SELECT_CATALOG_ROLE` amplía lo que el usuario **podría** leer. Lo que el e-stack **lee** sigue acotado por el SQL certificado y hash-verificado; no hay SQL arbitrario.
- Veredicto: **PASS**, sujeto a confirmar en el lab que `SESSION_PRIVS` no cambia (§8).

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): 962/962 antes y **963/963** después (+ guard de deriva). P15: adapter 23 → 24, security 34 → 35. `test_query_variant_resolver_*`: las 5 declaradas 19c-only.

## 8. Pasos humanos y validación en el lab (pendiente)

1. **DBA, en `CDB$ROOT`:**
   - `GRANT SELECT_CATALOG_ROLE TO C##ESTACK_DIAG CONTAINER=CURRENT;`
   - Verificar que el rol no trae privilegios de sistema: `SELECT privilege FROM dba_sys_privs WHERE grantee = 'SELECT_CATALOG_ROLE';` debe devolver 0 filas.
2. **Targets file privado** (`~/.config/oracle-diagnostic-estack/targets.lab.json`): agregar `Q-DICT-VERIFY-001` … `-005` a `allowed_collectors`. Reconectar el lanzador lab.
3. **Resultado esperado** (control positivo): `Q-DICT-VERIFY-003` debe reportar `COLUMN_NOT_FOUND` para `V$BACKUP_REDOLOG.COMPLETION_TIME`, el defecto conocido que corrige `CHG-ESTACK-ORA19C-LAB-005`, aún no integrado. Si no aparece, la verificación no funciona.
4. Cualquier otra discrepancia se registra y se corrige por `/change compatibility`, no en este cambio.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-LAB-DICT-VERIFY` y cubre `CHG-REQ-DICT-RMAN-AUDIT`.
- `CHG-ESTACK-ORA19C-LAB-005`: al integrarse, `--write` regenera las queries (la columna sale del diccionario) y el control positivo desaparece.
- `CHG-REQ-LAB-MULTIVERSION`: generación por versión.

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)
