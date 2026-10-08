# Exactitud del assessment: reloj, redo, alcance multitenant y revisión por especialistas

`/change query|security|compatibility|documentation` — `CHG-ESTACK-ASSESSMENT-ACCURACY-001`. Rama `change/assessment-accuracy` sobre `main` (`230ae4b`, `v0.28.0-pdb-coverage`). Origen: la revisión por especialistas de `ANA-20261008-001`.

## Por qué

La revisión encontró errores que no venían de la base, sino del propio e-stack:

| Problema | Efecto en el informe |
|---|---|
| El reloj del host de la base y el del gateway diferían ~2.2 h, y nada lo detectaba | Uptime, edad del backup y apertura de PDB inconsistentes; se llegó a sospechar un reinicio que no ocurrió (FND-0003/FND-0027) |
| `Q-ORA-REDO-SWITCH-24H-001` filtraba por `FIRST_TIME` | Reportaba 0 switches cuando hubo al menos uno (FND-0017/FND-0028) |
| `V$UNDOSTAT`, `V$PWFILE_USERS` sin `con_id` | Retención y usuarios administrativos de la PDB mezclados con los del root |
| Proxy y directorios sin `oracle_maintained` | No se podía saber si un proxy amplio o un grant de directorio involucraba cuentas propias |
| ASM sin la ubicación de los archivos | "La FRA comparte el diskgroup" quedaba como hipótesis en dos assessments |
| El alcance de `CONTAINER_DATA` se tomaba de la documentación | `PDB$SEED` no aparecía y no había cómo verificarlo desde la base |
| La revisión por especialistas no era parte del workflow | En los dos assessments encontró errores reales en el informe consolidado |

Al implementar apareció un bug del gateway que no se conocía. Si el máximo de una variante tenía 4 componentes (por ejemplo `12.1.0.1`), el resolver le agregaba `.99.99.99` y superaba el límite del parser de versiones. La variante no aplicaba nunca y el gateway fallaba cerrado: `Q-SEC-DEFAULT-ACCOUNTS-001` no resolvía en 11g.

## Cambios

| Artefacto | Versión | Cambio |
|---|---|---|
| `Q-DISC-CLOCK-001` | 1.0.0 (nueva) | Hora UTC de la base (segundos desde 1970) y desfase de zona horaria; lee `V$INSTANCE` |
| Gateway: `clock_check` | — | Compara `db_utc_epoch` con su hora UTC de recolección; limitación `CLOCK_SKEW` si el desfase supera 300 s. La evidencia de fixture nunca se compara |
| `Q-CDB-CONTAINER-DATA-001` | 1.0.0 (nueva) | Contenedores que ve la cuenta de diagnóstico (`DBA_CONTAINER_DATA`, filtrado por `SESSION_USER`); nombres de PDB enmascarados |
| `Q-ORA-REDO-SWITCH-24H-001` | 2.0.0 | Suma el `FIRST_TIME` del log actual (`V$LOG`, `CURRENT`) a la historia y descarta horas futuras. `NEXT_TIME`, sugerido en la revisión, no existe en `V$LOG_HISTORY`: un primer intento falló en el lab |
| `Q-ORA-UNDO-001` | 2.0.0 | V2 (12.1+): retención ajustada por `con_id` |
| `Q-SEC-ADMIN-PRIVILEGES-001` | 2.0.0 | V3 (12.1+): `con_id` |
| `Q-SEC-PROXY-AUTHENTICATION-001` | 3.0.0 | V3 (12.1.0.2+, donde existe `DBA_USERS.ORACLE_MAINTAINED`): `oracle_maintained` del proxy y del cliente |
| `Q-SEC-DIRECTORIES-001` | 4.0.0 | V2: `grantee_oracle_maintained` |
| `Q-ASM-TOPOLOGY-001` | 3.0.0 | `group_number` y, por diskgroup, `holds_datafiles`, `holds_redo`, `holds_controlfile` y `holds_fra` (`YES`/`NO`). Se calcula en la base comparando el prefijo `+DG/`; ninguna ruta sale de la base |
| Resolver de variantes (`mcp_gateway_lab/sqlsource.py`) | — | El máximo es inclusivo con su propia precisión: se compara la versión de la base truncada a esa precisión |
| `workflows/assessment.md` | — | Revisión por especialistas como paso fijo (roles en el mismo contexto, sin sesiones de modelo aparte); `Q-DISC-CLOCK-001` y `Q-CDB-CONTAINER-DATA-001` en el discovery |

**`Q-ORA-TEMP-001` no se modificó:** el TEMP de la PDB ya lo cubre `Q-CDB-TEMP-001`, validado en campo, y su variante `CDB_*` necesitaría `CDB_TEMP_FREE_SPACE`, que no se verificó en el lab.

**Catálogo:** lote B6 en la fábrica. Pasa de 72 a **74 collectors**.

**Registro del diccionario:**
- `DBA_CONTAINER_DATA` (12.1);
- `V$PWFILE_USERS.CON_ID` (12.1), según la Database Reference 19c.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Revisión por especialistas de `ANA-20261008-001` |
| IMPLEMENT | 2 queries nuevas, 6 modificadas, `clock_check` en el gateway, corrección del resolver, lote B6, campos en la base de conocimiento, collectors base de proxy y ASM, matriz, diccionario, workflow, registro de madurez (74 collectors, 142 componentes) |
| TEST | P18 30/30 (3 casos nuevos: `clock_check`, correcciones de exactitud, máximo inclusivo con su precisión); P15 actualizado a la variante V3 de proxy |
| SECURITY | 8/8 mutaciones detectadas: redo con `first_time`, undo sin `con_id`, ASM exponiendo el destino de la FRA, `CONTAINER_DATA` sin filtro de sesión, `clock_check` ignorando desfases negativos, resolver con relleno, proxy V3 desde 12.1 y directorios sin `oracle_maintained` |
| REGRESSION | 973/973 en macOS (bash 5.3); la fábrica y el generador del diccionario sin drift |
| LAB | **Pendiente:** allowlist de los 2 collectors nuevos y validación en campo de 8 collectors y de las sondas `Q-DICT-VERIFY` regeneradas (10 validaciones retiradas del registro por cambio de SQL) |
| HUMAN REVIEW | Pendiente |
