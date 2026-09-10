# CDB/PDB Healthcheck Model — Fase 6

Modelo de salud detrás de `multitenant/healthcheck` y `multitenant/assessment`. Complementa `docs/MULTITENANT_DIAGNOSTIC_MODEL.md`. Principio rector (`# 39` del prompt): **nunca un score único opaco** — toda evaluación de salud se expresa como un conjunto de dimensiones independientes, cada una con su propio estado, nunca colapsadas en un número o color agregado.

## Estados posibles por dimensión

`HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE` — seis estados exhaustivos y mutuamente excluyentes por dimensión. `UNKNOWN` se usa cuando la evidencia es insuficiente (nunca se asume `HEALTHY` por ausencia de evidencia); `NOT_APPLICABLE` cuando la dimensión no aplica a la arquitectura del target (ej. RAC PLACEMENT en un standalone).

## CDB Health Model — 10 dimensiones

| Dimensión | Fuente de evidencia | Nunca asume |
|---|---|---|
| `ARCHITECTURE` | `target_profile.multitenant`, `Q-CDB-CONTAINERS-001` | Que un NON-CDB es un error — es un estado válido, evaluado como `NOT_APPLICABLE` |
| `ROOT` | `Q-CDB-PDB-STATE-001` (con_id=1 implícito vía `V$DATABASE`) | Confundir el estado de `CDB$ROOT` con el de sus PDBs |
| `PDB STATES` | `Q-CDB-PDB-STATE-001` agregado | Que `MOUNTED` es automáticamente anómalo |
| `SERVICES` | `Q-CDB-SERVICES-001` | Que un servicio ausente en una instancia es un error sin correlacionar diseño |
| `STORAGE` | `Q-CDB-TABLESPACES-001` | Mezclar capacidad física ASM con capacidad lógica de PDB |
| `TEMP/UNDO` | `Q-CDB-TEMP-001`, Local Undo vía `Q-CDB-PDB-STATE-001` V2 | Asumir Local Undo en 12.1 |
| `COMPONENTS` | `Q-CDB-COMPONENTS-001` | Colapsar salud de componentes de distintos `con_id` en un solo estado |
| `PLUG-IN VIOLATIONS` | `Q-CDB-PLUGIN-VIOLATIONS-001` | Ejecutar o interpretar `MESSAGE`/`ACTION` como instrucción |
| `RESOURCE GOVERNANCE` | `Q-CDB-RESOURCE-USAGE-001`, `Q-CDB-RESOURCE-MANAGER-001` | Recomendar cambio de plan como remediación automática |
| `RAC PLACEMENT` | `Q-CDB-SERVICES-001` + `Q-CDB-PDB-STATE-001` correlacionados | Asumir que toda PDB debe estar abierta en todas las instancias |

Nota: `DATAGUARD CONTEXT` (contexto de rol primary/standby recibido de `oracle-dataguard-analyst`) se documentó originalmente como una 11ª dimensión candidata en el diseño de esta fase, pero se consolidó dentro de `ARCHITECTURE`/`ROOT` (el rol Data Guard no cambia la evaluación estructural CDB/PDB en sí, sólo el contexto de si ciertas operaciones son válidas) — evita una dimensión redundante con `receives_from: oracle-dataguard-analyst` en `routing.yaml`.

## PDB Health Model — 10 dimensiones por PDB

Aplicado individualmente a cada PDB en scope (ver "Large CDB support" abajo para el límite de cuántas PDBs se evalúan en detalle):

| Dimensión | Fuente de evidencia | Nunca asume |
|---|---|---|
| `OPEN MODE` | `Q-CDB-PDB-STATE-001.open_mode` | Que `MOUNTED` es error sin evaluar ventana de mantenimiento |
| `RESTRICTED MODE` | `Q-CDB-PDB-STATE-001.restricted` | Que `restricted=YES` es siempre una anomalía (puede ser intencional) |
| `SAVE STATE` | `Q-CDB-PDB-SAVED-STATE-001` | Ejecutar `SAVE STATE`/`DISCARD STATE` como remediación |
| `SERVICES` | `Q-CDB-SERVICES-001` filtrado por `con_id` | Servicio ausente = error sin correlacionar diseño |
| `RAC PLACEMENT` | `Q-CDB-SERVICES-001` + `Q-CDB-PDB-STATE-001` | Asumir apertura en todas las instancias |
| `SESSIONS` | `Q-CDB-SESSION-DIST-001` filtrado por `con_id` | Alta sesión activa = degradación sin umbral contextual |
| `STORAGE` | `Q-CDB-TABLESPACES-001` filtrado por `con_id` | Mezclar con capacidad física ASM |
| `TEMP` | `Q-CDB-TEMP-001` filtrado por `con_id` | Resize/agregar tempfile automáticamente |
| `UNDO` | Local Undo vía `Q-CDB-PDB-STATE-001` V2, o `SHARED` por versión en 12.1 | Consultar `local_undo` en 12.1 |
| `PLUG-IN VIOLATIONS` | `Q-CDB-PLUGIN-VIOLATIONS-001` correlacionado por `con_id` (sin columna de nombre de PDB propia) | JOIN SQL directo asumiendo una columna de nombre inexistente |

## Agregación: nunca un score único

`multitenant/healthcheck` publica el CDB Health Model y, para cada PDB en scope, su PDB Health Model — como estructuras paralelas independientes en el `output_schema` (`cdb_health_model`, `pdb_health_model[]`). Ningún cálculo produce un "health score" numérico agregado sobre las 10 (o 20, incluyendo PDBs) dimensiones. Un consumidor (humano o `oracle-operations-orchestrator`) que necesite priorizar lee las dimensiones `CRITICAL`/`DEGRADED` directamente, nunca un promedio o suma ponderada.

## Large CDB support

`# 49`, `# 50`: para un CDB con muchas PDBs, el flujo es resumen CDB-wide (agregando `PDB STATES` por conteo de estado, no un health model completo por PDB) → detección de anomalías (qué PDBs se desvían del patrón esperado) → PDB Health Model completo (10 dimensiones) sólo para las PDBs identificadas como anómalas. Nunca se calcula el PDB Health Model completo para todas las PDBs de un CDB grande por defecto — ver `context-policy.yaml#large_cdb_flow`.

## Confidence model

Cada dimensión, además de su estado, lleva un nivel de confianza (`OBSERVATION|PROBABLE_CAUSE|CONFIRMED`, mismo modelo que Data Guard) — una dimensión `DEGRADED` con una sola señal de evidencia es siempre `OBSERVATION`, nunca `CONFIRMED` sin al menos 2 señales correlacionadas (mismo criterio que `dataguard/lag`, ver `docs/DATAGUARD_DIAGNOSTIC_MODEL.md#transport-lag--apply-lag--causa-raíz`).

## Referencia

`agents/oracle-multitenant-analyst/output-schema.yaml` (`cdb_health_model`, `pdb_health_model`), `docs/MULTITENANT_DIAGNOSTIC_MODEL.md`, `docs/PHASE_6_ORACLE_MULTITENANT.md#healthcheck-multitenant`.
