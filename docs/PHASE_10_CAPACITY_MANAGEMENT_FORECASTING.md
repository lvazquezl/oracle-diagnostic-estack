# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING

Baseline: `v0.9.0-os-platform`. Rama: `phase/10-capacity-forecasting`.

Construye una capacidad transversal de capacity management/assessment/trend analysis/forecasting/
threshold forecasting/horizontal-vertical analysis/risk classification/recommendation/executive
reporting sobre Windows OS, Linux OS, Oracle Database, SQL Server Database y VMware Hypervisor —
con integración prioritaria a la evidencia ya certificada del e-stack (Fase 2/4/7/9), un único
agente transversal (`capacity-analyst`), un Common Metric Model y forecasts reproducibles,
confidence-aware, nunca presentados como certeza.

Mantiene READ-ONLY ALWAYS, HUMAN-EXECUTED REMEDIATION ONLY. No reconstruye fases anteriores, no
avanza a Incident/RCA/Change/Knowledge/MCP Gateway/Production Readiness, no implementa
auto-remediation ni Execution Plane.

## Objetivo

```text
capacity management
capacity assessment
capacity trend analysis
capacity forecasting
threshold forecasting
horizontal capacity analysis
vertical capacity analysis
capacity risk classification
capacity recommendation
executive reporting
```

sobre `Windows OS, Linux OS, Oracle Database, SQL Server Database, VMware Hypervisor`. Horizontes
obligatorios: `1/3/6 meses`. Periodicidad de reporting: `quarterly/semiannual`. Métricas base
obligatorias: `CPU, Memory, Disk/Storage`.

## Agente principal

`agents/capacity-analyst/` — `AGENT.md`, `manifest.yaml` (v2.0.0, `supersedes` el manifest plano
real de Foundation v1.0.0), `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`,
`output-schema.yaml`, `tests/README.md`, `CHANGELOG.md`. Único agente del dominio `capacity` — no
existen agentes separados para `cpu-capacity`/`memory-capacity`/`disk-capacity`/`forecasting`/
`vmware-capacity`/`oracle-capacity`/`sqlserver-capacity` (AGENTS FOR DOMAINS, SKILLS FOR TASKS).
`security_mode: READ_ONLY_ALWAYS`; `forbidden_capabilities` explícitas (SQL/shell arbitrario,
resize VM, add CPU/memoria, extender filesystem/ASM/tablespace, ALTER TABLESPACE/CREATE DATAFILE,
modificar asignación VMware, cambiar parámetros DB/OS resource controls, modificar herramientas de
monitoreo, inspección de business data, duplicar collectors certificados).

## Skills

28 skills `capacity/<name>/{SKILL.md,manifest.yaml}` — `data-source-inventory`, `data-quality`,
`normalization`, `cpu`, `memory`, `storage`, `oracle`, `asm`, `tablespace`, `os`, `windows`,
`linux`, `sqlserver`, `vmware`, `horizontal`, `vertical`, `trend-analysis`, `forecasting`,
`threshold-crossing`, `anomaly-awareness`, `seasonality-awareness`, `growth-rate`, `confidence`,
`risk-classification`, `capacity-healthcheck`, `capacity-assessment`, `manual-capacity-plan`,
`executive-summary`. Reemplaza el modelo de 16 skill_ids `registered`-only de Foundation (1 activo
previo, `capacity/forecast.md`, cuya lógica de regresión lineal + umbrales de riesgo por headroom
se funde íntegramente como base MVP de `capacity/forecasting` v2.0.0).

## Common Metric Model

`docs/CAPACITY_COMMON_METRIC_MODEL.md` — `capacity_metric` (`target_id, technology, resource_type,
metric_name, timestamp, total_capacity, used_capacity, available_capacity, utilization_percent,
unit, source_id, evidence_id, quality`). `available = total - used`; `utilization_percent = used /
total * 100`; `total <= 0` → `INVALID_CAPACITY_INPUT`, nunca división silenciosa. Unidades
normalizadas antes de calcular (`CPU` cores/percentage, `Memory` bytes/GiB, `Storage`
bytes/GiB/TiB) — nunca mezcla GB decimal con GiB binario sin conversión explícita.

## Source Adapter Model

`docs/CAPACITY_DATA_SOURCE_MODEL.md` — contract `{source_id, type, scope, technology,
metric_mapping, timestamp_semantics, sampling_interval, timezone, aggregation_level,
missing_data_behavior, units, validation_status, read_only: true}` para Site24x7, Prophecy,
Reporting Services, polling local, evidencia Oracle/OS, telemetría VMware/SQL Server. Estados:
`CONNECTED|AVAILABLE_OFFLINE|MANUAL_IMPORT|NOT_CONFIGURED|NOT_CERTIFIED`. En Fase 10 (MVP):
evidencia Oracle/OS `CONNECTED` (vía Fase 2/4/7/9); Site24x7/Prophecy/Reporting Services
`NOT_CONFIGURED`/`AVAILABLE_OFFLINE`; VMware/SQL Server `NOT_CERTIFIED` (sólo `MANUAL_IMPORT`).

## CPU / Memory / Storage capacity

`docs/CAPACITY_OS_MODEL.md`, `docs/CAPACITY_ORACLE_MODEL.md`. CPU: allocated/effective/used/
peak/average/p95/p99, nunca un pico puntual como baseline; utilización nunca modelada como recurso
acumulativo (`docs/CAPACITY_THRESHOLD_MODEL.md#cpu-forecast-semantics`). Memory: physical/
allocated/used/available/working-set/swap-pagefile-pressure/SGA-PGA/VM allocation; page cache de
Linux nunca tratado como consumo irreclamable. Storage: Storage Layer Model
(`physical/datastore → volume/filesystem/ASM → database logical → tablespace/datafile`), nunca
suma capas como capacidad independiente.

## Oracle / ASM / Tablespace / FRA capacity

`docs/CAPACITY_ORACLE_MODEL.md`. ASM usa `USABLE_FILE_MB` (nunca `FREE_MB/TOTAL_MB` simple) como
capacidad utilizable real. Tablespace distingue `allocated`/`maxsize`/`autoextend`/`used`/`free` —
el techo real es `maxsize` cuando autoextend está habilitado, nunca sólo `allocated`. FRA integra
con Fase 7 (`space_limit`/`space_used`/`space_reclaimable`/archivelog growth), nunca reclaim
automático. Todo por referencia a `oracle-dba-analyst`/`oracle-asm-storage-analyst`/
`oracle-backup-recovery-analyst` — nunca duplica collectors, nunca inspecciona business data.

## Linux / Windows / SQL Server / VMware capacity

`docs/CAPACITY_OS_MODEL.md`, `docs/CAPACITY_VMWARE_MODEL.md`, `docs/CAPACITY_SQLSERVER_MODEL.md`.
Linux `SUPPORTED` (reutiliza `os/cpu-topology`/`os/memory`/`os/swap`/`os/filesystems`/`os/inodes`/
`os/process-limits`, Fase 9). Windows Server `PARTIALLY_SUPPORTED` (misma cobertura que Fase 9:
WMI collectors `DOCUMENTATION_VALIDATED`, `ulimits`/`hugepages`/`aio` `NOT_APPLICABLE`). VMware y
SQL Server `PARTIALLY_SUPPORTED` — contract diseñado, `NOT_CERTIFIED` por defecto, disponibles
sólo vía `MANUAL_IMPORT` en esta fase (sin collector runtime certificado).

## Trend analysis / Growth rate / Anomaly & seasonality awareness

`docs/CAPACITY_FORECASTING_MODEL.md`. Clasificación `INCREASING|DECREASING|STABLE|VOLATILE|
UNKNOWN` con `slope`/`normalized_growth_rate`/`confidence` y estadísticas baseline (mean/median/
min/max/p95/stddev). `capacity/anomaly-awareness` detecta step changes/spikes/drops/source
reset/`capacity_resize` events — segmenta la serie y usa preferentemente datos posteriores al
último cambio estructural. `capacity/seasonality-awareness` reporta `NOT_DETECTED|POSSIBLE|
DETECTED|INSUFFICIENT_HISTORY` sin prometer modelos estacionales avanzados en el MVP.

## Forecasting / Confidence / Threshold crossing

`docs/CAPACITY_FORECASTING_MODEL.md`, `docs/CAPACITY_THRESHOLD_MODEL.md`. Método MVP por defecto:
regresión lineal sobre agregados diarios normalizados (hereda y extiende la lógica de
`capacity/forecast.md` de Foundation), con selección de método según histórico/volatilidad/
estacionalidad/calidad/outliers. Outliers: detectar/marcar/comparar, nunca eliminación silenciosa.
Horizontes obligatorios `1m/3m/6m` desde el último dato válido, con `lower/expected/upper` cuando
sea viable. Confidence: `HIGH|MEDIUM|LOW|INSUFFICIENT`, siempre con razón explícita — `RISK: HIGH`
+ `CONFIDENCE: LOW` es un resultado válido y esperado, nunca "mejorado" a certeza. Threshold
crossing: `DATE_ESTIMATED|NOT_EXPECTED_WITHIN_HORIZON|ALREADY_EXCEEDED|INSUFFICIENT_EVIDENCE|
NON_MONOTONIC`; `saturation_date` sólo para recursos acumulativos (disk/ASM/tablespace/FRA),
nunca CPU.

## Horizontal / Vertical capacity analysis

`docs/CAPACITY_HORIZONTAL_VERTICAL_MODEL.md`. Nunca decidido sólo por porcentaje de utilización —
considera topología, cuello de botella, growth rate, límites de plataforma, licenciamiento,
arquitectura HA/RAC, virtualización, complejidad operacional, cost-awareness. Evidencia
insuficiente → `INSUFFICIENT_EVIDENCE`, nunca recomendación forzada. Siempre advisory, nunca
ejecuta scale-out/resize.

## Source conflict model / Data quality

`docs/CAPACITY_DATA_SOURCE_MODEL.md`, `docs/CAPACITY_DATA_QUALITY_MODEL.md`. Múltiples fuentes de
la misma métrica: `preferred source`/`secondary source`/`reconciliation rule` declarados, nunca
promedio a ciegas — conflicto fuera de tolerancia → `SOURCE_CONFLICT` explícito. Data quality:
`GOOD|ACCEPTABLE|DEGRADED|INSUFFICIENT|INVALID`, evaluando sampling interval/missing/duplicate
samples/outliers/timezone/source changes — nunca forecast sobre dataset `INSUFFICIENT`/`INVALID`.

## Local computation / Token optimization / Cache / Reproducibility

Toda la matemática (normalización, agregación, regresión, intervalos de confianza) se ejecuta
localmente — nunca se envían series completas al modelo, sólo estadísticas + resultado + top
anomalías + evidence refs. Cada forecast registra `algorithm_version`, `input_evidence_ids`,
`time_window`, `aggregation`, `excluded_samples`, `threshold_policy_ref`, `generated_at`, bajo un
`forecast_contract_version` propio.

## Healthcheck / Assessment / Reporting / Manual Capacity Plan

`docs/CAPACITY_REPORTING_MODEL.md`, `docs/CAPACITY_MANUAL_ACTION_MODEL.md`. `/healthcheck
capacity` orquesta el flujo fijo (Target Profile → Source Inventory → Data Quality → Normalize →
Current Utilization → Trend → Forecast 1/3/6m → Threshold Crossing → Risk → Recommendations →
Markdown). `/assessment capacity --period quarterly|semiannual` cubre las 5 tecnologías con salida
mínima obligatoria (executive summary, scope, data sources, data quality, CPU/memory/storage
capacity, horizontal/vertical capacity, forecast 1/3/6m, threshold dates, top risks,
recommendations, evidence manifest). Toda recomendación es `manual_action` con `execution_status:
NOT_EXECUTED` — `recommended_capacity` explica su cálculo (`target_headroom_percent`), nunca
dimensiona "hasta justo el threshold".

## Target Profile

`docs/TARGET_PROFILE.md` `schema_version` 2.6.0→2.7.0 — bloque `capacity:` (`assessment_frequency,
horizons, thresholds` por recurso, `forecasting` policy, `source_priority`). Sin declaración
explícita del DBA, `thresholds`/`target_headroom_percent`/`source_priority` nunca se inventan —
degradan a `INSUFFICIENT_POLICY`/`REQUIRES_REVIEW`/`SOURCE_CONFLICT` explícitos.

## Workflows

`workflows/healthcheck.md` (`/healthcheck capacity`, activación condicional del agente),
`workflows/assessment.md` (`/assessment capacity --period quarterly|semiannual`,
`capacity/forecasting` reemplaza `capacity/forecast` en el flujo por defecto),
`workflows/diagnose.md` (routing de síntomas `capacity`/`capacity-cpu`/`capacity-memory`/
`capacity-storage`/`capacity-asm`/`capacity-tablespace`/`capacity-vmware`/`capacity-sqlserver`/
`capacity-source-conflict`/`capacity-data-quality`/`capacity-threshold`).

## Fixtures / Tests

16 fixtures sintéticas (`tests/fixtures/capacity-*.yaml`) — sin datos productivos: linear growth,
flat trend, decreasing trend, weekly seasonality, outliers, missing data, capacity resize, source
conflict, insufficient history, Oracle database growth, ASM USABLE_FILE_MB, tablespace autoextend,
FRA pressure, storage layers (no double counting), threshold already exceeded, horizontal/vertical
insufficient evidence. 70 tests nuevos (`tests/test_capacity_*.sh`, `tests/test_forecast_*.sh`,
`tests/test_threshold_*.sh`, `tests/test_cpu_no_exhaustion_semantics.sh`,
`tests/test_linux_cache_not_treated_as_unavailable.sh`, `tests/test_no_vm_resize.sh`,
`tests/test_no_storage_extension.sh`, `tests/test_no_asm_add_disk.sh`,
`tests/test_no_tablespace_extend.sh`, `tests/test_no_monitoring_mutation.sh`) cubriendo
normalization (5), data quality (6), CPU (5), memory (4), storage (5), Oracle/ASM/tablespace (5),
forecasting (9), threshold (5), source reconciliation (4), horizontal/vertical (4), safety (8),
cross-domain (5), reproducibility (5) — exactamente los nombres de las secciones 71-83 del prompt
de Fase 10. `tests/test_no_arbitrary_sql.sh`/`tests/test_no_arbitrary_shell.sh` (pre-existentes de
Fase 4/9) se **extendieron** con una verificación adicional de `capacity-analyst/manifest.yaml`,
preservando íntegramente su lógica original — nunca sobrescritos.

## Capability Matrix

`config/capability-matrix.yaml`, `docs/CAPABILITY_MATRIX.md` — dominio `capacity` PARTIAL→
SUPPORTED (10g-23ai, `future_status: COMPATIBILITY_VALIDATION_REQUIRED`). CPU/Memory/Storage/
Oracle/ASM/Tablespace/FRA/Linux capacity `SUPPORTED`; Windows/SQL Server/VMware capacity
`PARTIALLY_SUPPORTED`; forecast 1/3/6 meses `SUPPORTED`; threshold crossing `SUPPORTED`;
horizontal/vertical analysis `SUPPORTED`; capacity mutation execution `PROHIBITED`.

## Documentación

13 documentos nuevos: `docs/CAPACITY_COMMON_METRIC_MODEL.md`, `docs/CAPACITY_DATA_SOURCE_MODEL.md`,
`docs/CAPACITY_DATA_QUALITY_MODEL.md`, `docs/CAPACITY_FORECASTING_MODEL.md`,
`docs/CAPACITY_THRESHOLD_MODEL.md`, `docs/CAPACITY_HORIZONTAL_VERTICAL_MODEL.md`,
`docs/CAPACITY_ORACLE_MODEL.md`, `docs/CAPACITY_OS_MODEL.md`, `docs/CAPACITY_VMWARE_MODEL.md`,
`docs/CAPACITY_SQLSERVER_MODEL.md`, `docs/CAPACITY_REPORTING_MODEL.md`,
`docs/CAPACITY_MANUAL_ACTION_MODEL.md`, y este documento de cierre. Actualizados: `README.md`,
`ARCHITECTURE.md`, `SECURITY.md`, `docs/CAPABILITY_MATRIX.md`, `CHANGELOG.md`,
`docs/TARGET_PROFILE.md`, `agents/REGISTRY.md`, `skills/REGISTRY.md`.

## Seguridad

`security_mode: READ_ONLY_ALWAYS`. `forbidden_capabilities` explícitas en
`agents/capacity-analyst/manifest.yaml` cubren SQL/shell arbitrario, resize VM, add CPU/memoria,
extender filesystem/ASM diskgroup/tablespace, ALTER TABLESPACE/CREATE DATAFILE, modificar
asignación VMware, cambiar parámetros de base de datos/OS resource controls, modificar
herramientas de monitoreo, inspección de business data/bind values, y duplicar collectors ya
certificados — verificadas por `tests/test_capacity_read_only.sh`, `tests/test_no_vm_resize.sh`,
`tests/test_no_storage_extension.sh`, `tests/test_no_asm_add_disk.sh`,
`tests/test_no_tablespace_extend.sh`, `tests/test_no_monitoring_mutation.sh`,
`tests/test_no_arbitrary_sql.sh`, `tests/test_no_arbitrary_shell.sh`. Ninguna fuente externa
(Site24x7/Prophecy/Reporting Services) recibe credenciales de escritura ni capacidad de
reconfiguración (`read_only: true` fijo en el Source Adapter Contract).

## Known limitations

- VMware y SQL Server capacity: contract diseñado, sin collector runtime certificado en esta fase
  — disponibles sólo vía `MANUAL_IMPORT`, estado `NOT_CERTIFIED` por defecto.
- Site24x7/Prophecy/Reporting Services: adapters diseñados, sin conectividad runtime certificada
  — `NOT_CONFIGURED`/`AVAILABLE_OFFLINE` según declaración del DBA.
- Modelos estacionales avanzados (descomposición STL completa) no implementados en el MVP —
  `capacity/seasonality-awareness` reporta awareness (`NOT_DETECTED|POSSIBLE|DETECTED|
  INSUFFICIENT_HISTORY`), sin forecast estacional propio.
- `AWR`/histórico de performance en `capacity/oracle` permanece `LICENSE_RESTRICTED` sin
  confirmación explícita de Diagnostics Pack — mismo criterio que Fase 3/Fase 8.

## NOT_CERTIFIED sources

`VMwareTelemetry`, `SQLServerTelemetry` — contract completo, sin collector runtime en esta fase.
`Site24x7`, `Prophecy`, `ReportingServices` — sin conectividad certificada, disponibles sólo bajo
declaración explícita del DBA (`AVAILABLE_OFFLINE`/`MANUAL_IMPORT`) o `NOT_CONFIGURED` por defecto.
