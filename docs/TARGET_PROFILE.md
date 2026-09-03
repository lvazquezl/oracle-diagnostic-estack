# Target Profile — Phase 2 (Oracle Core)

Contrato estructurado producido por `oracle-discovery-analyst` y consumido por todo agente/skill/workflow posterior en el mismo análisis. Es la evolución, con schema fijo, del `findings`/`context.md` de discovery en Foundation — Foundation no se reescribe: este documento *extiende* `docs/CONTRACTS.md#agent-contract` (Output contract de `oracle-discovery-analyst`) con un schema versionado propio, porque el volumen de campos ya no cabe cómodamente en el Result Package genérico.

## Principio

Un Target Profile es la única fuente de verdad sobre "qué es este ambiente" dentro de un análisis. Ningún otro agente vuelve a determinar versión/arquitectura/rol por su cuenta — todos leen el Target Profile ya publicado (ver `docs/CONTRACTS.md#pipeline-de-activación-foundation-hardening`, paso CAPABILITY FILTER).

## Schema

```yaml
target_profile:
  schema_version: "2.0.0"
  target_id: string                    # referencia local (alias), nunca connection string con credenciales

  database:
    name: string                       # DB_NAME — MASK por defecto
    unique_name: string                # DB_UNIQUE_NAME — MASK por defecto
    dbid: string                       # numérico; KEEP (no identifica por sí solo sin acceso a la red del cliente)

  oracle_version:
    major: int
    minor: int
    release: int|null
    ru: string|null                    # ej. "19.21" si es determinable desde PATCH_LEVEL/REGISTRY$HISTORY
    raw: string                        # VERSION_FULL o VERSION tal como lo reportó la instancia

  architecture:
    cluster_mode: standalone|rac|rac_one_node
    multitenant_mode: non_cdb|cdb
    storage_mode: asm|filesystem

  database_role: primary|physical_standby|logical_standby|snapshot_standby|undetermined
  open_mode: string                    # ej. READ WRITE, READ ONLY, MOUNTED, READ ONLY WITH APPLY
  log_mode: archivelog|noarchivelog
  force_logging: bool|undetermined

  instance:
    name: string
    number: int
    host: string                      # MASK por defecto (ver sanitizers/data-classification-policy.md)

  cluster:
    detected: bool
    instance_count: int|null

  container:
    type: non_cdb|cdb_root|pdb|not_applicable
    con_id: int|null
    con_name: string|null              # MASK por defecto

  platform:
    database_platform: string          # V$DATABASE.PLATFORM_NAME

  capabilities:                        # ver docs/CONTRACTS.md#capability-status-model
    rac: SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED|ENVIRONMENT_UNKNOWN
    asm: SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED|ENVIRONMENT_UNKNOWN
    multitenant: SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED|ENVIRONMENT_UNKNOWN
    dataguard: SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED|ENVIRONMENT_UNKNOWN
    awr: LICENSE_RESTRICTED|UNSUPPORTED|ENVIRONMENT_UNKNOWN   # nunca SUPPORTED aquí — availability != entitlement (sección 18)
    ash: LICENSE_RESTRICTED|UNSUPPORTED|ENVIRONMENT_UNKNOWN

  discovery:
    timestamp: ISO-8601
    evidence_refs: [EVD-...]
    confidence: FACT|OBSERVATION|UNDETERMINED   # confianza GLOBAL del profile; cada campo individual puede degradar por separado (ver DEGRADATION en AGENT.md)
```

## Reglas

- **No incluir información sensible innecesaria.** `database.name`, `database.unique_name`, `container.con_name`, `instance.host` se enmascaran por defecto (`MASK`, ver `sanitizers/data-classification-policy.md`) salvo autorización explícita del DBA para la sesión — igual que en Foundation, no una regla nueva.
- **`capabilities.awr`/`capabilities.ash` nunca son `SUPPORTED`** en el Target Profile — sólo indican si la vista/estructura *existe* (`LICENSE_RESTRICTED` = existe pero requiere confirmación de licencia; `UNSUPPORTED` = no existe en esta versión). La distinción `availability != entitlement` (sección 18 del prompt de Fase 2) es estructural, no una nota aparte.
- **Cada campo puede degradar independientemente.** Si `database_role` no puede determinarse pero `oracle_version` sí, el Target Profile se publica igual, con `database_role: undetermined` y `discovery.confidence` reflejando el peor caso, más un `capability_status: ENVIRONMENT_UNKNOWN` reportado para lo que no se pudo determinar (ver `AGENT.md#degradation`).
- **Inmutable dentro de un análisis.** Un Target Profile publicado no se recalcula a mitad de análisis salvo que el TTL de cache expire (ver `policies/discovery-cache-policy.md`) o el DBA fuerce un re-discovery explícito.
- **`logical_standby`/`snapshot_standby`** se detectan cuando sea posible (`V$DATABASE.DATABASE_ROLE` los reporta directamente desde 11g) pero no se profundiza en ellos — Data Guard interno sigue fuera de alcance de Fase 2 (`oracle-dataguard-analyst` no se desarrolla en profundidad todavía).

## Versionado del schema

`schema_version` es independiente de la versión del agente/skill. Un cambio de schema (agregar/quitar/renombrar un campo) es `MAJOR` y sigue `/change compatibility`, igual que Query Contract v2 en Foundation Hardening.

## Consumidores

`oracle-dba-analyst` (Oracle Core), y — por diseño, aunque no se implementan en profundidad en esta fase — `oracle-performance-analyst`, `oracle-rac-analyst`, `oracle-asm-storage-analyst`, `oracle-dataguard-analyst`, `oracle-multitenant-analyst`, `oracle-backup-recovery-analyst` leerán este mismo Target Profile cuando se profundicen en fases posteriores, en vez de re-implementar discovery.
