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

## Validación en el lab (`lab-ol8-19c`, `LAB-OL8-19C-CDBROOT-ASM`, 2026-10-08)

Los 13 collectors corrieron en real y su `query_sha256` coincide con el SQL versionado. 7 se validaron con `09c43f0` y 6 con `db71836`, porque redo y las sondas del diccionario se corrigieron después.

| Collector | Request | Evidencia | Resultado |
|---|---|---|---|
| `Q-DISC-CLOCK-001` | `REQ-7ac4a482fe88` | `EVR-da2711c875bb597926bcc15c` | `clock_check` con desfase de **0 s**: el salto de ~2.2 h de ayer fue transitorio |
| `Q-CDB-CONTAINER-DATA-001` | `REQ-d78a680c2e25` | `EVR-459f5df48f556059c8e63400` | La cuenta ve el root y una PDB (`all_containers` = N); por eso no aparece `PDB$SEED` (ahora FACT) |
| `Q-ASM-TOPOLOGY-001` | `REQ-9489e5cfeedc` | `EVR-22a488910cc647d6c3ce3960` | El diskgroup único contiene datafiles, redo, controlfile **y la FRA** (confirma la hipótesis de dos assessments). La fila sin diskgroup es `group_number` 0 |
| `Q-SEC-PROXY-AUTHENTICATION-001` | `REQ-19972f43c95b` | `EVR-ddd6e203a21df8f2622d9c19` | El proxy y sus 2 clientes son cuentas **propias** |
| `Q-SEC-DIRECTORIES-001` | `REQ-b14b4f82a2b9` | `EVR-c43730ed15031b50f3c523db` | Grants de directorio con `grantee_oracle_maintained` |
| `Q-ORA-UNDO-001` | `REQ-538d267aab50` | `EVR-7f9d553842bcb9432c25828c` | Retención por `con_id` (en la última hora solo hubo filas del root) |
| `Q-SEC-ADMIN-PRIVILEGES-001` | `REQ-0ca4f9f41507` | `EVR-29777785271cf9ca549136bb` | `con_id` 0: el usuario del password file es de nivel CDB |
| `Q-ORA-REDO-SWITCH-24H-001` | `REQ-4e992cc97cb9` | `EVR-4b832cd536355164160cb31b` | 1 switch en 24 h (antes 0) |
| `Q-DICT-VERIFY-001`..`005` | `REQ-7a60adfc8b42`, `REQ-d8e41e1ac935`, `REQ-26a8a62830e6`, `REQ-48d38866a418`, `REQ-6800d828668c` | `EVR-b0a856f8b3e29cf76f974e07`, `EVR-0e60e053315efdea4329c9b9`, `EVR-70f6e39297bfc9d1a38f8734`, `EVR-c53d0de9e46fa0861ec65685`, `EVR-37d0f3d5203d2ce59aef2186` | Todas las vistas y columnas declaradas existen, incluidas las 10 de `V$LOG_HISTORY`; solo faltan `STATS$*` (Statspack no instalado) |

**Primer intento fallido de redo:** la revisión por especialistas sugirió `NEXT_TIME`, que no existe en `V$LOG_HISTORY`. El collector falló con `E_ADAPTER_FAILED`, sin ejecutar nada indebido. Se confirmó con la Database Reference 19c y se corrigió en `db71836`. El validador estático no revisa columnas dentro de subconsultas (límite conocido); ahora lo cubre P18.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Revisión por especialistas de `ANA-20261008-001` |
| IMPLEMENT | 2 queries nuevas, 6 modificadas, `clock_check` en el gateway, corrección del resolver, lote B6, campos en la base de conocimiento, collectors base de proxy y ASM, matriz, diccionario, workflow, registro de madurez (74 collectors, 142 componentes) |
| TEST | P18 30/30 (3 casos nuevos: `clock_check`, correcciones de exactitud —incluido el rechazo de `NEXT_TIME`—, máximo inclusivo con su precisión); P15 actualizado a la variante V3 de proxy; columnas de `V$LOG_HISTORY` registradas como exhaustivas |
| SECURITY | 9/9 mutaciones detectadas: redo sin el log actual, redo con `NEXT_TIME`, undo sin `con_id`, ASM exponiendo el destino de la FRA, `CONTAINER_DATA` sin filtro de sesión, `clock_check` ignorando desfases negativos, resolver con relleno, proxy V3 desde 12.1 y directorios sin `oracle_maintained` |
| REGRESSION | 973/973 en macOS (bash 5.3); la fábrica y el generador del diccionario sin drift |
| LAB | 13/13 en real (arriba), `FIELD_VALIDATED`; allowlist del lab con 69 collectors |
| HUMAN REVIEW | Pendiente |
