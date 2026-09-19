# Target Profile — Phase 2 (Oracle Core)

Contrato estructurado producido por `oracle-discovery-analyst` y consumido por todo agente/skill/workflow posterior en el mismo análisis. Es la evolución, con schema fijo, del `findings`/`context.md` de discovery en Foundation — Foundation no se reescribe: este documento *extiende* `docs/CONTRACTS.md#agent-contract` (Output contract de `oracle-discovery-analyst`) con un schema versionado propio, porque el volumen de campos ya no cabe cómodamente en el Result Package genérico.

## Principio

Un Target Profile es la única fuente de verdad sobre "qué es este ambiente" dentro de un análisis. Ningún otro agente vuelve a determinar versión/arquitectura/rol por su cuenta — todos leen el Target Profile ya publicado (ver `docs/CONTRACTS.md#pipeline-de-activación-foundation-hardening`, paso CAPABILITY FILTER).

## Schema

```yaml
target_profile:
  schema_version: "2.8.0"
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

  # --- Fase 6 (Multitenant / CDB / PDB) — aditivo, schema_version 2.3.0, ningún campo previo removido/renombrado ---

  multitenant:
    cdb: bool                              # espejo de architecture.multitenant_mode == cdb, explícito aquí para consumo directo por oracle-multitenant-analyst
    cdb_name: string|null                  # MASK por defecto
    root_container: string|null            # MASK por defecto
    pdb_count: int|null
    local_undo_enabled: bool|null          # null si la versión es 12.1 (Local Undo no existe ahí) o no determinable
    application_containers: bool|null

  # --- Fase 7 (Backup & Recovery / RMAN) — aditivo, schema_version 2.4.0, ningún campo previo removido/renombrado ---

  backup_recovery:
    repository: controlfile_repository|recovery_catalog|both|unknown
    recovery_catalog: bool
    controlfile_repository: bool
    default_device_type: disk|sbt_tape|unknown|null
    fra_enabled: bool
    sbt_enabled: bool
    media_manager: string|null           # MASK por defecto — token de vendor, ej. Commvault/Simpana
    retention_policy: string|null
    rpo_minutes: int|null                # recovery_objectives opcional — INSUFFICIENT_REQUIREMENTS si null
    rto_minutes: int|null

  # --- Fase 8 (Security & Compliance) — aditivo, schema_version 2.5.0, ningún campo previo removido/renombrado ---

  security:
    compliance_frameworks: [string]|null       # ej. ["INTERNAL"], ["CIS"] — nunca copia benchmarks propietarios completos
    account_inactivity_policy_days: int|null   # sin definir -> security/stale-accounts publica INSUFFICIENT_POLICY, nunca inventa un umbral
    password_policy:                            # ejemplo de policy TARGET configurable, nunca defaults universales — null -> POLICY_NOT_DEFINED
      minimum_length: int|null
      complexity:
        uppercase_min: int|null
        lowercase_min: int|null
        digits_min: int|null
        special_characters_min: int|null
      password_life_time_days: int|null
      failed_login_attempts: int|null
      password_lock_time_minutes: int|null
      password_grace_time_days: int|null
      password_reuse:
        minimum_days: int|null
        minimum_changes: int|null
    encryption_required: bool|null              # null -> security/tablespace-encryption/tde-awareness nunca declaran incumplimiento sin este target
    audit_requirements: string|null
    tls_required: bool|null
    licensing_profile: [string]|null            # features explícitamente confirmadas licenciadas por el DBA — sin esto, security/licensing-gates nunca reporta INCLUDED

  # --- Fase 9 (OS Platform Diagnostics & Hardening) — aditivo, schema_version 2.6.0, ningún campo previo removido/renombrado ---

  os_platform:
    family: linux|solaris|windows|undetermined
    distribution: string|null              # ej. "Oracle Linux", "RHEL", "SUSE", "Windows Server" — MASK/TOKENIZE si revela convención interna
    version: string|null                   # ej. "8.9", "2022" — versión mayor/menor, nunca patch-level completo si es sensible
    kernel: string|null                    # release de kernel/build — KEEP, no identifica por sí solo
    architecture: string|null              # ej. x86_64, ppc64le (LinuxONE/s390x cuando aplique)
    virtualization: bare_metal|vm|container|undetermined
    oracle_home_owner: string|null         # TOKENIZE por defecto — nunca UID/GID crudo sin contexto
    grid_home_owner: string|null           # TOKENIZE por defecto
    oracle_groups: [string]|null           # nombres de grupo (oinstall/dba/asmadmin/...), nunca membresía completa aquí (ver os/oracle-groups)
    expected_hugepages_policy: string|null       # policy declarada por el DBA (ej. "enabled, sin margen fijo") — null -> os/hugepages nunca inventa una policy
    expected_thp_policy: string|null             # ej. "never", "madvise" — null -> os/transparent-hugepages cita sólo el estado real, sin comparar contra una recomendación no declarada
    expected_time_sync: string|null              # ej. "chrony contra NTP corporativo" — null -> os/time-sync reporta sólo el estado, sin asumir la fuente esperada
    expected_network_model: string|null          # ej. "bonded active-backup + VLAN dedicada interconnect" — null -> os/bonding, os/vlan reportan sin comparar contra un diseño no declarado

  # --- Fase 10 (Capacity Management & Forecasting) — aditivo, schema_version 2.7.0, ningún campo previo removido/renombrado ---

  capacity:
    assessment_frequency: quarterly|semiannual|null   # null -> capacity-analyst opera bajo demanda, sin cadencia impuesta
    horizons: [1, 3, 6]                                # meses — fijo salvo ampliación futura vía /change
    thresholds:                                        # policy TARGET configurable por recurso, nunca defaults universales — null -> capacity/threshold-crossing publica INSUFFICIENT_POLICY
      cpu:
        warning_percent: int|null
        critical_percent: int|null
        emergency_percent: int|null
      memory:
        warning_percent: int|null
        critical_percent: int|null
        emergency_percent: int|null
      storage:
        warning_percent: int|null
        critical_percent: int|null
        emergency_percent: int|null
    forecasting:
      minimum_samples: int|null
      minimum_history_days: int|null       # ej. 30 — ejemplo recomendado, no universal (ver docs/CAPACITY_DATA_QUALITY_MODEL.md)
      preferred_history_days: int|null     # ej. 90+
      target_headroom_percent: int|null    # usado por capacity/manual-capacity-plan para dimensionar recomendaciones — null -> el cálculo se declara REQUIRES_REVIEW
    source_priority:                       # reconciliación cuando la misma métrica existe en varias fuentes (ver docs/CAPACITY_DATA_SOURCE_MODEL.md) — nunca promediado automático
      cpu: [string]|null                   # ej. ["OracleEvidence", "OSEvidence", "Site24x7"]
      memory: [string]|null
      storage: [string]|null

  # --- Fase 11 (Incident Analysis & Root Cause Automation) — aditivo, schema_version 2.8.0, ningún campo previo removido/renombrado ---

  incident:
    severity_model: string|null            # ej. "SEV1-SEV4 corporativo" — null -> incident/severity-awareness usa únicamente el modelo por defecto documentado en docs/INCIDENT_INTAKE_MODEL.md, nunca inventa una escala corporativa no declarada
    evidence_window:
      before_minutes: int|null             # ventana de evidencia previa al inicio reportado del incidente — null -> incident/evidence-plan usa el default documentado, nunca una ventana arbitraria sin trazabilidad
      after_minutes: int|null
    change_correlation:
      before_minutes: int|null             # ver incident/change-correlation — null -> NO_CORRELATION por defecto, nunca una ventana universal asumida
      after_minutes: int|null
    max_hypotheses: int|null               # límite de hipótesis activas simultáneas — null -> incident/hypothesis-generation no impone límite artificial, pero documenta cuántas generó
    confidence_thresholds:                 # policy TARGET configurable, nunca defaults universales — null -> el Root Cause Model usa únicamente sus reglas estructurales (2 evidencias independientes / prueba temporal inequívoca), nunca un umbral numérico inventado
      minimum_evidence_sources: int|null
    recurrence_window_days: int|null       # ventana para incident/recurrence-awareness — null -> UNKNOWN explícito si no hay declaración, nunca asumida
    timeline_granularity: string|null      # ej. "1 minute", "1 second" — null -> incident/timeline reporta con la granularidad real de cada fuente, nunca normaliza a una resolución no declarada
    required_domains: [string]|null        # dominios que el DBA exige incluir siempre en incident/scope-identification (ej. ["performance", "rac"]) — null -> el agente determina el scope únicamente por síntoma reportado

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
- **`multitenant.cdb` es un espejo directo de `architecture.multitenant_mode == cdb` (Fase 6), nunca una segunda fuente de verdad.** Un target NON-CDB o 10g/11g publica `multitenant.cdb: false` con el resto del bloque en `null` — `oracle-multitenant-analyst` no se activa (Capability Filter); la respuesta `MULTITENANT_STATUS: NOT_APPLICABLE` la produce `oracle-discovery-analyst` directamente desde este campo, sin activar el agente (`# 6` del prompt de Fase 6). `multitenant.local_undo_enabled` nunca se determina por adivinanza en 12.1 (Local Undo no existe en ese release) — queda `null` ahí por diseño de versión, no por falta de evidencia.
- **`backup_recovery.repository` nunca se asume `recovery_catalog` por defecto (Fase 7, `# 7` del prompt).** Sin confirmación de acceso de lectura al Recovery Catalog, `repository: controlfile_repository`, `recovery_catalog: false` — `oracle-backup-recovery-analyst` opera exclusivamente sobre metadata de controlfile. `backup_recovery.rpo_minutes`/`rto_minutes` quedan `null` sin declaración explícita del DBA — `rman/retention-policy`/`rman/recovery-readiness` publican `INSUFFICIENT_REQUIREMENTS` en ese caso, nunca un RPO/RTO inventado (`# 31` del prompt de Fase 7).
- **`security.password_policy`/`security.account_inactivity_policy_days`/`security.encryption_required`/`security.tls_required`/`security.licensing_profile` nunca se inventan sin declaración explícita del DBA (Fase 8, `# 15`, `# 43` del prompt).** Sin `password_policy` definido, todo `security/password-policy-strength` publica `POLICY_NOT_DEFINED` por control, nunca un target inventado. Sin `licensing_profile` confirmando una feature específica, `security/licensing-gates` nunca reporta `status: INCLUDED` — la disponibilidad técnica (`V$OPTION`) nunca implica derecho de uso. `security.password_policy` en el ejemplo de `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md` es un baseline corporativo de EJEMPLO, no un default universal del e-stack.
- **`os_platform.expected_hugepages_policy`/`expected_thp_policy`/`expected_time_sync`/`expected_network_model` nunca se inventan sin declaración explícita del DBA (Fase 9).** Sin esos campos, `os/hugepages`/`os/transparent-hugepages`/`os/time-sync`/`os/bonding`/`os/vlan` reportan el estado real leído directamente, nunca lo comparan contra un diseño esperado no declarado — evita falsos positivos por asumir un diseño estándar que el host real no sigue. `os_platform.family`/`distribution`/`version` nunca se determinan por adivinanza: si `os/discovery` no puede leerlos con evidencia, quedan `undetermined`/`null` y el consumidor (`os-platform-analyst`) reporta `COMPATIBILITY_VALIDATION_REQUIRED`, nunca asume Linux/Oracle Linux por defecto. `os_platform.oracle_home_owner`/`grid_home_owner`/`oracle_groups` nunca contienen membresía completa de usuarios — eso vive en la evidencia de `os/oracle-groups`, tokenizada por defecto.
- **`capacity.thresholds`/`capacity.forecasting.target_headroom_percent`/`capacity.source_priority` nunca se inventan sin declaración explícita del DBA (Fase 10).** Sin `thresholds` definidos, `capacity/threshold-crossing` publica `INSUFFICIENT_POLICY` por recurso, nunca `80/90/95` como default universal (esos números sólo aparecen como ejemplo en `docs/CAPACITY_THRESHOLD_MODEL.md`). Sin `target_headroom_percent`, `capacity/manual-capacity-plan` marca el dimensionamiento recomendado como `REQUIRES_REVIEW`. Sin `source_priority` para un recurso con múltiples fuentes, `capacity/data-source-inventory` nunca promedia automáticamente — publica `SOURCE_CONFLICT` cuando los valores difieren fuera de tolerancia. `capacity.horizons` es fijo (`[1, 3, 6]` meses) salvo ampliación futura vía `/change`.
- **`incident.severity_model`/`incident.change_correlation`/`incident.confidence_thresholds`/`incident.recurrence_window_days`/`incident.timeline_granularity` nunca se inventan sin declaración explícita del DBA (Fase 11).** Sin `change_correlation.before_minutes`/`after_minutes` definidos, `incident/change-correlation` publica `NO_CORRELATION` por defecto — nunca asume una ventana universal. Sin `recurrence_window_days`, `incident/recurrence-awareness` publica `unknown` en vez de asumir `first_occurrence`. `incident.confidence_thresholds.minimum_evidence_sources` es un refinamiento opcional del Root Cause Model — su ausencia nunca relaja la regla estructural ya fija (2 fuentes independientes o prueba temporal inequívoca) definida en `docs/CONTRACTS.md#rca-model`. `incident.required_domains` nunca reduce el scope mínimo de seguridad determinado por `incident/scope-identification` — sólo puede ampliarlo.

## Versionado del schema

`schema_version` es independiente de la versión del agente/skill. Un cambio de schema (agregar/quitar/renombrar un campo) es `MAJOR` y sigue `/change compatibility`, igual que Query Contract v2 en Foundation Hardening.

## Consumidores

`oracle-dba-analyst` (Oracle Core), `oracle-performance-analyst` (Fase 3), `oracle-rac-analyst`/`oracle-asm-storage-analyst`/`oracle-network-analyst` (Fase 4 — consumen los bloques `rac`/`gi`/`asm`/`network` respectivamente, nunca vuelven a determinar `cluster_mode`/`storage_mode`/SCAN por su cuenta), `oracle-dataguard-analyst` (Fase 5 — consume el bloque `dataguard`, nunca vuelve a determinar `database_role`/`protection_mode` por su cuenta), `oracle-multitenant-analyst` (Fase 6 — consume el bloque `multitenant`, nunca vuelve a determinar `multitenant_mode`/`pdb_count` por su cuenta), `oracle-backup-recovery-analyst` (Fase 7 — consume el bloque `backup_recovery`, nunca vuelve a determinar `repository`/`default_device_type` por su cuenta; consume también `dataguard`/`multitenant` para `rman/dataguard-awareness`/`rman/multitenant-awareness`, nunca re-implementa esos dominios); `oracle-security-analyst` (Fase 8 — consume el bloque `security`, nunca inventa `password_policy`/`account_inactivity_policy_days`/`licensing_profile` por su cuenta; consume también `multitenant`/`dataguard`/`backup_recovery` para `security/common-local-users`/integración con Data Guard y Backup/Recovery, nunca re-implementa esos dominios); `os-platform-analyst` (Fase 9 — consume el bloque `os_platform`, nunca vuelve a determinar `family`/`distribution`/`version` por adivinanza; consume también `rac`/`dataguard`/`backup_recovery`/`security` para `os/rac-interconnect-awareness`/`os/dataguard-network-awareness`/`os/rman-media-manager-awareness`/`os/security-filesystem-awareness`, nunca re-implementa esos dominios); `capacity-analyst` (Fase 10 — consume el bloque `capacity` para umbrales/horizontes/prioridad de fuentes, nunca inventa thresholds sin declaración; consume también `os_platform`/`rac`/`asm`/`multitenant`/`backup_recovery` para reutilizar evidencia de CPU/memoria/storage/ASM/tablespaces/FRA por referencia, nunca duplica collectors de Fase 2/4/7/9); `incident-root-cause-analyst` (Fase 11 — consume el bloque `incident` para ventanas de evidencia/correlación de cambios/granularidad de timeline, nunca inventa una escala de severidad o ventana no declarada; consume también los 10 bloques previos (`rac`/`asm`/`dataguard`/`multitenant`/`backup_recovery`/`security`/`os_platform`/`capacity`/`network`) por referencia a través de los 9 skills de correlación cross-domain, nunca duplica collectors de ninguna fase previa).
