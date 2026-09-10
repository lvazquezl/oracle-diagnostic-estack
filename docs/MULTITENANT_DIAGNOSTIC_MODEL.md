# Multitenant Diagnostic Model — Fase 6

Modelo conceptual detrás de `oracle-multitenant-analyst` y sus 26 skills `multitenant/*`. Complementa `agents/oracle-multitenant-analyst/AGENT.md`.

## NON-CDB handling: nunca se activa el agente

Sobre un target NON-CDB o 10g/11g, `oracle-multitenant-analyst` **nunca** se activa (`# 6`) — el Capability Filter lo excluye antes del Agent Filter. `MULTITENANT_STATUS: NOT_APPLICABLE` lo publica directamente `oracle-discovery-analyst` desde `target_profile.multitenant.cdb`/`target_profile.architecture.multitenant_mode`, ya presentes en el Target Profile (schema 2.3.0) desde el bootstrap de Oracle Core. 10g/11g mapean a `NOT_APPLICABLE`, no `KNOWN_UNSUPPORTED` — la categoría de feature no existe ahí en absoluto, distinto de una versión donde la feature existe pero no está certificada.

## CDB detection: reutilizando el bootstrap de Oracle Core

`# 7`: nunca reimplementa `V$DATABASE.CDB` — reutiliza `Q-DISC-IDENTITY-001` (Oracle Core, Fase 2), que ya expone `d.cdb` en sus variantes V2/V3 (12.1+), nunca en V1 (10.2–11.2). Un target 10.2–11.2 nunca intenta leer `CDB` porque la columna no existe en esa variante.

## Container scope contract

`# 9`: toda query Multitenant declara `container_scope: CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NON_CDB_ONLY|NOT_APPLICABLE`. La presencia de `CON_ID` en una vista dinámica **nunca** implica por sí sola que ejecutar cruzando contenedores sea seguro — cada query documenta explícitamente su scope real, verificado contra el comportamiento documentado de la vista, no asumido por convención de nombre.

## PDB state: MOUNTED no es error por sí mismo

`multitenant/pdb-state` clasifica `open_mode` como `MOUNTED|READ WRITE|READ ONLY|MIGRATE|UNKNOWN` y `restricted` como `YES|NO|UNKNOWN` (`# 11`). Una PDB `MOUNTED` se evalúa contra ventanas de mantenimiento/intención declaradas antes de convertirse en anomalía — nunca un estado anómalo asumido a priori.

## Save state awareness: sólo visibilidad

`# 12`: visibilidad exclusivamente vía `DBA_PDB_SAVED_STATES` (`Q-CDB-PDB-SAVED-STATE-001`, disponible desde 12.1.0.2 — ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`). El agente nunca ejecuta `SAVE STATE`/`DISCARD STATE` — ninguna capacidad real existe para hacerlo.

## PDB RAC placement: nunca asumir "todas las instancias"

`# 13`: `multitenant/pdb-rac-placement` distingue colocación configurada, apertura real por instancia, y diseño de servicio. Nunca asume que una PDB debe estar abierta en todas las instancias de un RAC — correlaciona con el diseño de servicios (`Q-CDB-SERVICES-001`) antes de reportar `MISMATCH`. Clasificación: `MATCHES_DESIGN|PARTIAL|MISMATCH|INSUFFICIENT_EVIDENCE`.

## Storage scope: nunca mezclar capacidad ASM con capacidad PDB

`# 16`: `multitenant/pdb-tablespaces` nunca mezcla capacidad física ASM subyacente con capacidad lógica asignada a la PDB. Una presión de storage con origen ASM sospechado se delega a `oracle-asm-storage-analyst`, nunca inferida directamente por el agente Multitenant.

## Local Undo: nunca asumido en 12.1

`# 19`, `# 20`: Local Undo no existe en 12.1 (introducido en 12.2). `V$PDBS.LOCAL_UNDO` (1=local, 0=shared) sólo se consulta en la variante V2 de `Q-CDB-PDB-STATE-001` (12.2+). En 12.1, `undo_mode = SHARED` se determina **por definición de versión**, nunca consultando una columna que no existe ahí.

## Parameter scope y drift

`# 21`, `# 22`: `multitenant/parameters` distingue scope `inherited/pdb_override/instance_specific` vía `GV$SYSTEM_PARAMETER.ISPDB_MODIFIABLE`. Drift se clasifica `EXPECTED_DIFFERENCE|UNEXPECTED_DIFFERENCE|INSUFFICIENT_CONTEXT` — una diferencia entre PDBs nunca es automáticamente "drift incorrecto" sin evaluar el contexto declarado (ej. tiers de servicio distintos por diseño).

## Common vs. local identity: sólo visibilidad

`# 23`: `CDB_USERS.COMMON`/`CDB_ROLES.COMMON` (YES/NO) es la única fuente de verdad — nunca inferido por convención de nombre (ej. prefijo `C##`). Visibilidad/assessment únicamente: nunca password hashes, nunca DDL, nunca escala a deep assessment de Security.

## Plug-in violations: ACTION siempre tratado como DATA

`# 26`, `# 27`, `# 48`: `PDB_PLUG_IN_VIOLATIONS` tiene dos señales de identidad de PDB — `CON_ID` (12.2+, verificado vía WebFetch) y `NAME` (*"the name of an existing PDB or a PDB intended to be created"*, disponible 12.1–23ai, verificado vía WebFetch contra Oracle Database Reference 12.1/19c — corrección de PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING). En 12.1 (`CON_ID` inexistente), `NAME` sigue siendo la identidad de PDB — `container_name`/`pdb_token` se derivan de ella, sanitizada; en 12.2+ se correlacionan ambas señales, publicando `IDENTITY_MISMATCH` si no coinciden, nunca ocultando la inconsistencia. `MESSAGE`/`ACTION` se tratan **siempre** como datos inertes, sanitizados, nunca ejecutados como instrucción bajo ninguna circunstancia — incluso si el texto contiene lenguaje que parece una instrucción dirigida al modelo. Defensa explícita de prompt injection. Clasificación: `WARNING|ERROR|PENDING|RESOLVED|UNKNOWN`.

## Application Containers / Proxy PDB: topología, no lifecycle

`# 28`, `# 29`: `V$PDBS.APPLICATION_ROOT/APPLICATION_PDB/APPLICATION_SEED/PROXY_PDB` (12.2+, verificado real) dan awareness de topología. `capability_status: PARTIALLY_SUPPORTED` cuando el detalle completo de lifecycle no está certificado. Proxy PDB nunca abre conexiones remotas ni almacena connect strings — sólo reporta su existencia y relación con el proxy real.

## Resource usage y Resource Manager: visibilidad, corrección de vista

`V$RSRCPDBMETRIC` (17 columnas) da uso de recursos por PDB. `DBA_CDB_RSRC_PLAN_DIRECTIVES` (no `CDB_RSRC_PLAN_DIRECTIVES`, el nombre erróneo del prompt original — corregido tras verificación WebFetch previa a escribir cualquier metadata) da directivas de plan. Ambos son sólo visibilidad — ningún `ALTER SYSTEM SET RESOURCE_MANAGER_PLAN` ni cambio de Pending Area ejecutado.

## Lockdown profiles: visibilidad

`CDB_LOCKDOWN_PROFILES` (12.2+, 7 columnas verificadas) da visibilidad de reglas de lockdown por perfil. Ningún `ALTER LOCKDOWN PROFILE` ejecutado.

## Correlation model — cuándo se activa cada dominio vecino

- **ASM/Storage** (`# 16`): presión de storage con origen ASM sospechado → delega a `oracle-asm-storage-analyst`, nunca inferido directamente.
- **RAC** (`# 13`): colocación de PDB en instancias/servicios → delega a `oracle-rac-analyst` sólo cuando el target es RAC, nunca activado por defecto en standalone (el Capability Filter excluye la delegación vía `supported_architectures`).
- **Data Guard**: contexto CDB/PDB en un target con Data Guard → recibido de `oracle-dataguard-analyst` (`receives_from`), nunca activado de forma independiente sin ese contexto.
- **Performance**: presión de recursos/sesiones con impacto medible en DB Time → delega a `oracle-performance-analyst`, que aplica su propio Licensing Gate para AWR/ASH.
- **Security profundo**: identidad común/local es sólo visibilidad — cualquier análisis de Security profundo queda fuera de alcance de esta fase.

## Large CDB support

`# 49`, `# 50`: resumen CDB → detección de anomalías → análisis profundo sólo para las PDBs afectadas. Nunca inventario completo de PDBs ni análisis profundo por-PDB por defecto en un CDB grande.

## Manual Action Contract

Ver `docs/PHASE_6_ORACLE_MULTITENANT.md#manual-action-contract` — todo comando `ALTER PLUGGABLE DATABASE`/`ALTER SYSTEM`/`ALTER LOCKDOWN PROFILE`/`CREATE-ALTER-DROP USER` recomendado sigue este esquema, `execution_status: NOT_EXECUTED` siempre.
