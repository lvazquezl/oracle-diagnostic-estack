# Target Profile — Phase 2 (Oracle Core)

Contrato estructurado producido por `oracle-discovery-analyst` y consumido por todo agente/skill/workflow posterior en el mismo análisis. Es la evolución, con schema fijo, del `findings`/`context.md` de discovery en Foundation — Foundation no se reescribe: este documento *extiende* `docs/CONTRACTS.md#agent-contract` (Output contract de `oracle-discovery-analyst`) con un schema versionado propio, porque el volumen de campos ya no cabe cómodamente en el Result Package genérico.

## Principio

Un Target Profile es la única fuente de verdad sobre "qué es este ambiente" dentro de un análisis. Ningún otro agente vuelve a determinar versión/arquitectura/rol por su cuenta — todos leen el Target Profile ya publicado (ver `docs/CONTRACTS.md#pipeline-de-activación-foundation-hardening`, paso CAPABILITY FILTER).

## Schema

```yaml
target_profile:
  schema_version: "2.2.0"
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

  # --- Fase 4 (RAC/GI/ASM/Network) — aditivo, schema_version 2.1.0, ningún campo 2.0.0 removido/renombrado ---

  rac:
    enabled: bool
    node_count: int|null
    instances: [string]|null       # nombres de instancia — MASK por defecto

  gi:
    version: string|null           # activeversion de crsctl query crs
    home: string|null              # MASK por defecto — puede revelar convención de filesystem interna
    cluster_name: string|null      # MASK por defecto

  asm:
    enabled: bool
    instance_count: int|null

  network:
    scan_name: string|null         # MASK por defecto
    scan_ips: [string]|null        # MASK por defecto
    listener_ports: [int]|null     # KEEP — puerto en sí no identifica, sólo junto con host

  # --- Fase 5 (Data Guard) — aditivo, schema_version 2.2.0, ningún campo previo removido/renombrado ---

  dataguard:
    enabled: bool
    role: primary|physical_standby|logical_standby|snapshot_standby|undetermined   # espejo de database_role, explícito en este bloque para consumo directo por oracle-dataguard-analyst
    db_unique_name: string|null            # MASK por defecto
    protection_mode: MAXIMUM_PROTECTION|MAXIMUM_AVAILABILITY|MAXIMUM_PERFORMANCE|null
    broker_enabled: bool
    fsfo_enabled: bool
    primary: string|null                   # db_unique_name del primary — MASK por defecto
    standbys: [string]|null                # db_unique_name de cada standby conocido — MASK por defecto

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
- **Bloques `rac`/`gi`/`asm`/`network` (Fase 4) son aditivos y se publican en `null`/`false` cuando no aplican** — nunca se omiten del schema. Un target standalone sin ASM publica `rac.enabled: false`, `asm.enabled: false`, con el resto de campos de esos bloques en `null` — nunca se activa `oracle-rac-analyst`/`oracle-asm-storage-analyst` sobre ese Target Profile (Capability Filter).
- **`gi.version`/`gi.home`/`network.scan_name`/`network.scan_ips` nunca se determinan por adivinanza.** Si `oracle-discovery-analyst` no pudo obtener evidencia (ej. `INSUFFICIENT_PRIVILEGES` en el collector `get_cluster_version`/`get_scan_configuration`), el campo queda `null` y el consumidor (`oracle-rac-analyst`/`oracle-network-analyst`) re-consulta el skill correspondiente en vez de asumir un valor.
- **`dataguard.role` es un espejo directo de `database_role` (Fase 5), nunca una segunda fuente de verdad.** `dataguard.enabled` es `true` cuando `database_role != primary` o cuando el primary tiene al menos un standby conocido — un target `primary` sin standby conocido publica `dataguard.enabled: false` y `oracle-dataguard-analyst` no se activa (Capability Filter). `dataguard.primary`/`dataguard.standbys` nunca se infieren de `OPEN_MODE` (`# 9` del prompt de Fase 5) — provienen siempre de `DATABASE_ROLE`/Broker cuando esté disponible.

## Versionado del schema

`schema_version` es independiente de la versión del agente/skill. Un cambio de schema (agregar/quitar/renombrar un campo) es `MAJOR` y sigue `/change compatibility`, igual que Query Contract v2 en Foundation Hardening.

## Consumidores

`oracle-dba-analyst` (Oracle Core), `oracle-performance-analyst` (Fase 3), `oracle-rac-analyst`/`oracle-asm-storage-analyst`/`oracle-network-analyst` (Fase 4 — consumen los bloques `rac`/`gi`/`asm`/`network` respectivamente, nunca vuelven a determinar `cluster_mode`/`storage_mode`/SCAN por su cuenta), `oracle-dataguard-analyst` (Fase 5 — consume el bloque `dataguard`, nunca vuelve a determinar `database_role`/`protection_mode` por su cuenta) — y, por diseño, aunque no se implementan en profundidad todavía, `oracle-multitenant-analyst`, `oracle-backup-recovery-analyst` leerán este mismo Target Profile cuando se profundicen en fases posteriores, en vez de re-implementar discovery.
