# CHANGELOG

Versionado semántico del e-stack. Cambios por artefacto individual (agente/skill/query/workflow/policy) se versionan por separado según `EVOLUTION.md`; este changelog cubre el repositorio en su conjunto.

## [Unreleased] — 2026-09-19 — PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING

Micro-hardening acotado sobre `PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING` (misma
rama `phase/11-incident-rca`). Cierra una fuga real y reproducida: `normalize_signature()`
aceptaba verbatim cualquier cadena de forma `UPPER_SNAKE_CASE` (3-64 caracteres) — un marcador
sintético como `SYNTHETIC_SECRET_DO_NOT_USE` coincidía con esa forma genérica y se filtraba
literal a JSON/Markdown. Ver
`docs/PHASE_11_RCA_SIGNATURE_ALLOWLIST_LEAK_PREVENTION_MICRO_HARDENING.md` para el reporte de
cierre completo.

### Added

- `rca_engine/sanitize.classify_signature()` — certificación por dos vías acotadas (código
  numérico tipado bajo prefijo fijo, o membresía exacta en el catálogo de reglas versionado) —
  nunca por forma genérica.
- `rca_engine/tokenization.derive_signature_token()` — token opaco para firmas no reconocidas.
- `rca_engine/rules.collect_certified_signatures()`.
- `common.SignatureStatus` (`CERTIFIED|UNRECOGNIZED_SIGNATURE|INSUFFICIENT_EVIDENCE`).
- 6 fixtures + 9 tests nuevos bajo `tests/test_rca_signature_*.sh`/`test_rca_unknown_signature_*.sh`/
  `test_rca_certified_signature_regression.sh`.
- `docs/PHASE_11_RCA_SIGNATURE_ALLOWLIST_LEAK_PREVENTION_MICRO_HARDENING.md`.

### Fixed

- `rca_engine/sanitize.py`: `normalize_signature()` (aceptación genérica por regex de forma) —
  reemplazado; una firma nunca certifica sólo por coincidir con una expresión regular de forma.
  Reproducido antes del fix (marcador sintético filtrado en JSON/Markdown con exit 0), corregido,
  re-verificado.

### Changed

- `NormalizedEvidence`/`TimelineEvent` (`rca_engine/common.py`): el campo único `signature` se
  reemplaza por `signature_status`/`canonical_signature`/`signature_token` — cambio de schema
  deliberado y documentado; `tests/test_rca_signature_safe_clustering.sh` extendido al nuevo
  schema (no reescrito desde cero).
- `rca_engine/rules.py`: `_symptom_matches()` ahora exige `signature_status == CERTIFIED` antes de
  comparar `canonical_signature` contra `signature_any` de una regla.
- `rca_engine/timeline.py`: agrupación/dedup usan `canonical_signature`/`signature_token` — nunca
  el texto crudo como clave serializable.
- `docs/INCIDENT_READONLY_SECURITY_MODEL.md` — sección de `signature` reescrita.

## [Unreleased] — 2026-09-18 — PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING

Hardening de seguridad acotado sobre `PHASE_11_RCA_EXECUTION_EVIDENCE_VALIDATION_HARDENING`
(misma rama `phase/11-incident-rca`). Cierra una fuga real y reproducida: `target_id`,
`signature`, `source_id` y las claves/valores de `attributes` nunca se sanitizaban (el
sanitizador previo sólo cubría `summary`/`symptom_description`), y los mensajes de error de
intake ecoaban el valor crudo ofensivo. Ver
`docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md` para el reporte de cierre
completo.

### Added

- `rca_engine/tokenization.py` — tokens opacos deterministas para `target_id`/`source_id`,
  namespaced por `incident_id`.
- 13 fixtures nuevos bajo `tests/fixtures/rca_engine/` con el marcador sintético
  `SYNTHETIC_SECRET_DO_NOT_USE_8f2c` en cada campo de riesgo, separado y combinado.
- 12 tests ejecutables nuevos bajo `tests/test_rca_*.sh` (nombrados exactamente por el prompt de
  este hardening), incluyendo un caso de regresión propia detectado y corregido durante el
  desarrollo (heurística de token desnudo aplicada incorrectamente a nombres de clave legítimos).
- `docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md`.
- `rca_engine.cli --token-map` — mapa de tokens en archivo separado, nunca fusionado con
  `--out`/`--markdown`/`--manifest`.

### Fixed

- `rca_engine/sanitize.py`/`intake.py`: `target_id`, `signature`, `source_id`, `attributes`
  (claves y valores, incluidos anidados) nunca se sanitizaban — reescritos con
  `deep_sanitize()` recursivo, `sanitize_attributes()` (allowlist), `normalize_signature()` y
  tokenización.
- Mensajes de `IntakeError` (event_type inválido, evidence_id duplicado) ecoaban el valor crudo
  ofensivo hacia stderr — corregido para nunca ecoar.
- 2 falsos positivos de `tests/test_secret_detection.sh` contra prosa de este mismo hardening
  (menciona un patrón `password` seguido de `=` a modo de placeholder) — reformulados sin relajar el escáner.

### Changed

- `rca_engine/engine.py` — reordena: catálogo de reglas se carga antes que intake (el allowlist
  de atributos depende de él); `run_rca()` retorna ahora `(result, token_map)`.
- `docs/INCIDENT_READONLY_SECURITY_MODEL.md` — sección nueva de sanitización estructurada.

## [Unreleased] — 2026-09-17 — PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING

Hardening acotado sobre el hardening anterior (misma rama `phase/11-incident-rca`), previo a
aprobar `v0.11.0-incident-rca`. Cierra la brecha entre los 34 skills `incident/*` declarativos y
un motor RCA local, ejecutable y verificable — mismo patrón que
`PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING` aplicó a `capacity_engine/`. Ver
`docs/PHASE_11_RCA_EXECUTION_EVIDENCE_VALIDATION_HARDENING.md` para el reporte de cierre completo.

### Added

- `rca_engine/` (13 módulos Python 3, sólo stdlib): `common.py`, `sanitize.py`, `intake.py`,
  `timeline.py`, `rules.py`, `hypothesis.py`, `causality.py`, `report.py`, `engine.py`, `cli.py`,
  `rules/default_rules.json` (catálogo versionado de 6 reglas allowlisted).
- `tests/lib/rca_engine_e2e_helpers.sh` — helper de invocación portable (mismo patrón de rutas
  relativas que `tests/lib/capacity_engine_e2e_helpers.sh`).
- 12 fixtures funcionales bajo `tests/fixtures/rca_engine/`.
- 20 tests ejecutables nuevos bajo `tests/test_rca_*.sh` (19 nombrados exactamente por el prompt
  de hardening + 1 control de mutation testing), todos invocando `rca_engine.cli` real.
- `docs/PHASE_11_RCA_EXECUTION_EVIDENCE_VALIDATION_HARDENING.md`.

### Fixed

- `tests/test_capability_matrix_schema.sh`: conteo de dominios hardcodeado en 18, no actualizado
  tras agregar la fila `incident` en la Fase 11 declarativa — corregido a 19 (detectado y
  corregido durante el gate final de la Fase 11 declarativa, re-verificado aquí).

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — fila `incident` extendida: 5
  capacidades pasan de `CONTRACT_DEFINED`/`DOCUMENTED_ONLY` a `LOCAL_RUNTIME_TESTED`/
  `IMPLEMENTED_AND_TESTED` (`incident/root-cause`, `incident/timeline`,
  `incident/hypothesis-generation`, `incident/hypothesis-testing`,
  `incident/contradiction-analysis`).

## [Unreleased] — 2026-09-17 — PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION

Nuevo dominio transversal `incident` sobre baseline `v0.10.0-capacity-forecasting`: agente único
`incident-root-cause-analyst` (v2.0.0, deepening del manifest plano real de Foundation, mismo
patrón que Security/OS Platform/Capacity) y 34 skills `incident/*` completamente materializados
(Intake/Triage, Timeline/Evidence, Hypothesis/Causality/Root-Cause, Impact/Recovery/Correlación
general, 9 skills de correlación cross-domain con los especialistas de Fase 2-10, Output/Process).
Ver `docs/PHASE_11_INCIDENT_ANALYSIS_ROOT_CAUSE_AUTOMATION.md` para el reporte de cierre completo.

### Added

- `agents/incident-root-cause-analyst/` (manifest.yaml, routing.yaml, context-policy.yaml,
  collaboration.yaml, output-schema.yaml, AGENT.md, CHANGELOG.md, tests/README.md) — v2.0.0,
  `supersedes: agents/incident-root-cause-analyst.md` (Foundation v1.0.0).
- 34 skills `incident/*` (SKILL.md + manifest.yaml cada uno) — `intake`, `classification`,
  `severity-awareness`, `scope-identification`, `timeline`, `evidence-plan`,
  `evidence-correlation` (v2.0.0), `symptom-clustering`, `hypothesis-generation`,
  `hypothesis-testing`, `contradiction-analysis`, `root-cause` (v2.0.0, absorbe
  `skills/incident/root-cause-analysis.md` de Foundation), `contributing-factors`,
  `impact-analysis`, `blast-radius` (v2.0.0), `recovery-status`, `recurrence-awareness`,
  `known-error-correlation`, `change-correlation`, `capacity-correlation`,
  `performance-correlation`, `rac-correlation`, `dataguard-correlation`,
  `asm-storage-correlation`, `network-correlation`, `os-correlation`, `security-correlation`,
  `rman-correlation`, `multitenant-correlation`, `manual-remediation-plan`,
  `post-incident-review`, `lessons-learned` (v2.0.0), `incident-report`, `rca-report`.
- 12 documentos de modelo: `docs/INCIDENT_INTAKE_MODEL.md`, `docs/INCIDENT_EVIDENCE_MODEL.md`,
  `docs/INCIDENT_TIMELINE_MODEL.md`, `docs/INCIDENT_HYPOTHESIS_MODEL.md`,
  `docs/INCIDENT_CAUSALITY_MODEL.md`, `docs/INCIDENT_ROOT_CAUSE_MODEL.md`,
  `docs/INCIDENT_IMPACT_MODEL.md`, `docs/INCIDENT_PLAYBOOK_MODEL.md`,
  `docs/INCIDENT_MANUAL_REMEDIATION_MODEL.md`, `docs/INCIDENT_POSTMORTEM_MODEL.md`,
  `docs/INCIDENT_READONLY_SECURITY_MODEL.md`,
  `docs/PHASE_11_INCIDENT_ANALYSIS_ROOT_CAUSE_AUTOMATION.md`.
- ~32 fixtures bajo `tests/fixtures/incident/{oracle,rac,dataguard,rman,os,capacity,security}/`.
- 63 tests exactamente nombrados (Intake/Timeline/Hypotheses/Root Cause/Causality/Impact/
  Cross-domain/Playbooks/Safety/Traceability/Documentation) — 57 nuevos, 6 extendidos
  (`tests/test_no_arbitrary_sql.sh`, `tests/test_no_arbitrary_shell.sh`,
  `tests/test_no_parameter_change.sh`, `tests/test_no_network_change.sh`,
  `tests/test_no_failover_execution.sh`, `tests/test_no_switchover_execution.sh`).
- `incident:` block en `docs/TARGET_PROFILE.md` (`schema_version` 2.7.0 → 2.8.0).
- Fila `incident` en `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md`.

### Changed

- `skills/REGISTRY.md` — sección `## incident` de 8 skill_ids (1 activo) a 34 (todos activos);
  total de skills activos 301 → 334.
- `agents/REGISTRY.md` — fila `incident-root-cause-analyst` apunta a
  `agents/incident-root-cause-analyst/AGENT.md`.
- `workflows/incident.md` (v1.0.0 → v2.0.0), `workflows/rca.md` (v1.0.0 → v2.0.0) — secuencia de
  skills actualizada a la nueva estructura de 34 skills.
- `workflows/healthcheck.md` (v2.0.0 → v2.1.0) — agrega `/healthcheck incident`.
- `workflows/diagnose.md` (v1.1.0 → v1.2.0) — agrega routing `/diagnose incident`.
- `ARCHITECTURE.md` — principio # 33 (correlación temporal nunca es causación).
- `SECURITY.md` — caso concreto de evidencia por referencia y remediación manual en incidentes.
- `README.md` — sección Estado actualizada a Fase 11.

### Non-negotiables verificados

READ-ONLY ALWAYS, HUMAN-EXECUTED REMEDIATION ONLY incluso en escenarios de emergencia, CORRELATION
IS NOT CAUSATION, CAUSE/CONTRIBUTING-FACTOR/SYMPTOM distintos, UNCERTAINTY explícita (UNDETERMINED
como estado legítimo), TIMELINE trazable (clock skew nunca corregido silenciosamente), RCA
reproducible (hipótesis rechazadas siempre listadas), NO RMAN EXECUTION ni siquiera durante
investigación de incidente.

## [Unreleased] — 2026-09-17 — PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING

Hardening acotado sobre el hardening anterior (misma rama `phase/10-capacity-forecasting`), previo
a aprobar `v0.10.0-capacity-forecasting`. Corrige un defecto real de rutas en
`tests/test_capacity_engine_end_to_end.sh` detectado por revisión externa. Ver
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md#addendum` para el reporte
de cierre completo.

### Fixed

- **`tests/test_capacity_engine_end_to_end.sh` construía rutas inválidas en POSIX sin `cygpath`**:
  concatenaba `"$WTMPDIR\\archivo.json"` incondicionalmente; en POSIX la barra invertida no es un
  separador, así que Python recibía un nombre de archivo literal con un `\` incrustado y fallaba
  con `FileNotFoundError`. Reproducido verbatim, corregido reescribiendo el test para pasar rutas
  **relativas** al CLI tras un `cd` al directorio de trabajo (bash builtin, resuelto correctamente
  por el SO sin importar el intérprete invocado después) — root cause eliminado por construcción,
  ya no depende de la disponibilidad de `cygpath`.

### Added

- `tests/lib/capacity_engine_e2e_helpers.sh` — helpers compartidos: `capacity_engine_run`,
  `capacity_engine_write_linear_fixture` (estrategia de rutas relativas), y
  `capacity_engine_to_interp_path` (fallback para ruta absoluta genuina, pregunta a `python3` su
  `sys.platform` real, nunca infiere desde `uname`/`$OSTYPE`, antes de decidir si usar
  `cygpath -w`).
- 5 tests nuevos: `tests/test_capacity_engine_end_to_end_linux_paths.sh` (reproduce el defecto de
  raíz + confirma el fix), `tests/test_capacity_engine_end_to_end_paths_with_spaces.sh`,
  `tests/test_capacity_engine_end_to_end_missing_fixture_fail_fast.sh`,
  `tests/test_capacity_engine_end_to_end_cli_nonzero_exit.sh`,
  `tests/test_capacity_engine_end_to_end_output_consistency.sh`.

### Changed

- `docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md` — nuevo addendum
  documentando el defecto, el fix, los tests nuevos y las plataformas realmente ejecutadas en esta
  sesión (Windows 11 + Git Bash/Cygwin + Python 3.13.14 nativo `win32` — sin una corrida Linux/WSL
  independiente).

## [Unreleased] — 2026-09-16 — PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING

Hardening sobre la Fase 10 base (misma rama `phase/10-capacity-forecasting`), previo a aprobar
`v0.10.0-capacity-forecasting`. Cierra la brecha entre los contratos declarativos de
`skills/capacity/*` y un motor local ejecutable. Ver
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md` para el reporte de cierre
completo.

### Added

- `capacity_engine/` — motor de forecasting local, determinista, Python 3 stdlib puro (sin
  numpy/scipy/pandas): `common.py` (ForecastResult y demás dataclasses/enums),
  `normalization.py` (validación de esquema/unidades/tiempo), `quality.py` (coverage/freshness/
  missingness/gaps/outliers), `segmentation.py` (detección de capacity_resize), `aggregation.py`
  (agregación diaria determinista), `stats.py` (OLS puro, intervalos de predicción, aritmética de
  meses calendario, outliers MAD), `trend.py` (clasificación de tendencia), `threshold.py`
  (cruce de umbral), `reconciliation.py` (SOURCE_CONFLICT sin promedio ciego), `engine.py`
  (`run_capacity_forecast`, orquestador), `report.py` (tabla de capacidad Markdown), `cli.py`
  (adaptador local invocable, `python3 -m capacity_engine.cli`).
- 18 tests numéricos ejecutables que corren el motor real y comparan salidas contra valores
  calculados independientemente: `tests/test_capacity_engine_{flat,decreasing,
  threshold_crossing,calendar,insufficient_history,missing_irregular_duplicates,outliers,
  resize_segmentation,source_conflict,units,interval_semantics,storage_layers,cpu_semantics,
  security,end_to_end,no_false_pass_mutation}.sh` — más `tests/test_forecast_linear_growth.sh` y
  `tests/test_forecast_reproducible_same_input.sh` endurecidos (ejecución real añadida, checks
  documentales originales conservados y etiquetados).
- `docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md`.

### Changed

- `docs/CAPACITY_FORECASTING_MODEL.md`, `docs/CAPACITY_DATA_QUALITY_MODEL.md`,
  `docs/CAPACITY_THRESHOLD_MODEL.md`, `docs/CAPACITY_REPORTING_MODEL.md`,
  `docs/CAPABILITY_MATRIX.md`, `config/capability-matrix.yaml` — documentan el motor ejecutable y
  la distinción `CONTRACT_DEFINED`/`LOCAL_RUNTIME_TESTED`/`PRODUCTION_RUNTIME_CERTIFIED`;
  `/healthcheck capacity`/`/assessment capacity` (agente vivo, MCP Gateway) permanecen
  `CONTRACT_ONLY`/`NOT_RUNTIME_CERTIFIED`, nunca declarados como ejecutados.

## [Unreleased] — 2026-09-14 — PHASE 10 — CAPACITY MANAGEMENT & FORECASTING

Nueva fase sobre baseline `v0.9.0-os-platform`, rama `phase/10-capacity-forecasting`. Ver
`docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md` para el reporte de cierre completo.

### Added

- `agents/capacity-analyst/` v2.0.0 — deepening del manifest plano real de Foundation v1.0.0
  (`supersedes`) a contrato estructurado completo (`AGENT.md`, `manifest.yaml`, `routing.yaml`,
  `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`, `tests/README.md`,
  `CHANGELOG.md`) — único agente transversal del dominio `capacity`, nunca fragmentado por
  recurso/tecnología.
- 28 skills `capacity/<name>/{SKILL.md,manifest.yaml}` — `data-source-inventory`, `data-quality`,
  `normalization`, `cpu`, `memory`, `storage`, `oracle`, `asm`, `tablespace`, `os`, `windows`,
  `linux`, `sqlserver`, `vmware`, `horizontal`, `vertical`, `trend-analysis`, `forecasting`,
  `threshold-crossing`, `anomaly-awareness`, `seasonality-awareness`, `growth-rate`, `confidence`,
  `risk-classification`, `capacity-healthcheck`, `capacity-assessment`, `manual-capacity-plan`,
  `executive-summary` — reemplaza el modelo de 16 skill_ids `registered`-only de Foundation.
  `skills/capacity/forecast.md` (único activo previo, regresión lineal + umbrales de riesgo por
  headroom) se funde íntegramente como base MVP de `capacity/forecasting` v2.0.0.
- Common Metric Model (`capacity_metric`) transversal a Oracle/Linux/Windows/SQL Server/VMware;
  Source Adapter Contract (`read_only: true` fijo) para Site24x7/Prophecy/Reporting
  Services/evidencia Oracle/OS/telemetría VMware/SQL Server.
- Forecasting reproducible y confidence-aware: horizontes 1/3/6 meses desde el último dato válido,
  intervalos `lower/expected/upper`, `confidence: HIGH|MEDIUM|LOW|INSUFFICIENT` siempre con razón
  explícita, `forecast_contract_version`/`algorithm_version`/`input_evidence_ids`/`time_window`/
  `excluded_samples` para reproducibilidad completa.
- Threshold crossing (`DATE_ESTIMATED|NOT_EXPECTED_WITHIN_HORIZON|ALREADY_EXCEEDED|
  INSUFFICIENT_EVIDENCE|NON_MONOTONIC`), Capacity Risk Model (`HEALTHY|WATCH|WARNING|HIGH|
  CRITICAL|UNKNOWN`, siempre con `confidence` explícito), Horizontal/Vertical Decision Model
  (nunca decidido sólo por porcentaje de utilización).
- `docs/TARGET_PROFILE.md` `schema_version` 2.6.0→2.7.0 — bloque `capacity:` (thresholds,
  forecasting policy, source_priority).
- `workflows/healthcheck.md` (`/healthcheck capacity`), `workflows/assessment.md` (`/assessment
  capacity --period quarterly|semiannual`), `workflows/diagnose.md` (routing de 10 síntomas de
  capacidad).
- 13 documentos nuevos `docs/CAPACITY_*.md` + `docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md`.
- 16 fixtures sintéticas (`tests/fixtures/capacity-*.yaml`, sin datos productivos) y 70 tests
  nuevos (normalization×5, data quality×6, CPU×5, memory×4, storage×5, Oracle/ASM/tablespace×5,
  forecasting×9, threshold×5, source reconciliation×4, horizontal/vertical×4, safety×8,
  cross-domain×5, reproducibility×5) — `tests/test_no_arbitrary_sql.sh`/
  `tests/test_no_arbitrary_shell.sh` (pre-existentes de Fase 4/9) extendidos con verificación de
  `capacity-analyst/manifest.yaml`, preservando su lógica original.
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `capacity` PARTIAL→
  SUPPORTED (10g-23ai).

## [Unreleased] — 2026-09-14 — PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING

Micro-hardening sobre la Fase 9 base + los dos hardenings previos (misma rama
`phase/9-os-platform`), previo a aprobar `v0.9.0-os-platform`. Ver
`docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md` para el reporte de cierre
completo.

### Fixed

- **`pam_limits.so` custom `conf=` source no modelado**: `pam_limits.applicability ==
  APPLICABLE` se trataba como prueba de que `/etc/security/limits.conf`/`limits.d/*` eran la
  fuente de policy efectiva, sin parsear los argumentos reales de la invocación de
  `pam_limits.so`. Corregido: nuevo collector `get_pam_limits_policy_source(service)` parsea
  `conf=`/`debug=`/`set_all=`/`utmp_early=` y determina `mode: DEFAULT|CUSTOM_CONF|
  INSUFFICIENT_EVIDENCE|NOT_APPLICABLE` — con `conf=` presente, `limits.conf`/`limits.d` nunca se
  agregan como fuente concurrente; múltiples invocaciones preservadas por separado.
- **`TasksMax`/`pids.max` del mismo cgroup contados dos veces**: el Binding Constraint Model
  siempre listaba `SYSTEMD_TASKS_MAX` y `CGROUP_PIDS_MAX` como constraints independientes, incluso
  cuando resuelven al mismo control group. Corregido: nuevo collector `get_unit_cgroup_path(unit)`
  y PID Controller Canonical Model en `os/process-limits` — deduplica en un único constraint
  `PID_CONTROLLER` cuando `unit_cgroup_path_token == cgroup_path_token`; nodos `PARENT`/`CHILD`/
  `DELEGATED` con path distinto permanecen separados, nunca deduplicados por similitud numérica.
- Defecto de edición pre-existente en `skills/os/cgroups/SKILL.md` (secciones "Documentation
  requirements"/"Change history" duplicadas al final, con la segunda copia truncada) — corregido.

### Added

- Collectors `get_pam_limits_policy_source(service)`, `get_unit_cgroup_path(unit)` —
  `docs/OS_READONLY_COLLECTOR_MODEL.md`.
- PID Controller Canonical Model (`process_constraint_pid_controller`,
  `CONFIGURATION_EFFECTIVE_MISMATCH` a nivel de nodo) en `os/process-limits` v4.0.0.
- Cgroup hierarchy model (`cgroup_constraint`, `relation: UNIT|PARENT|CHILD|DELEGATED|OTHER`) en
  `os/cgroups` v3.0.0.
- 7 fixtures y 21 tests nuevos — ver el reporte de cierre.
- `docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

### Changed

- `os/systemd-limits` v3.0.0→v4.0.0, `os/process-limits` v3.0.0→v4.0.0, `os/ulimits`
  v3.0.0→v4.0.0, `os/cgroups` v2.0.0→v3.0.0.
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `os`: notas extendidas con
  PAM policy source/module arguments/PID controller identity/cgroup hierarchy.

## [Unreleased] — 2026-09-14 — PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING

Micro-hardening sobre la Fase 9 base + el hardening EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM
SOURCE-OF-TRUTH (misma rama `phase/9-os-platform`), previo a aprobar `v0.9.0-os-platform`. Ver
`docs/PHASE_9_PAM_LIMITS_PROCESS_CONSTRAINT_SCOPE_HARDENING.md` para el reporte de cierre completo.

### Fixed

- **`os/systemd-limits` — `PAMName=` tratado como prueba suficiente de PAM applicability**: el
  hardening anterior corrigió el merge systemd/PAM pero introdujo este defecto propio —
  `pam_applicable: true` se derivaba de `PAMName=` confirmado sin verificar que `pam_limits.so`
  estuviera realmente cargado en la pila PAM efectiva del servicio. Corregido: nuevo modelo
  `pam_limits: {pam_session_present, pam_service, pam_limits_module_present, applicability}` con
  estados `APPLICABLE|NOT_APPLICABLE|INSUFFICIENT_EVIDENCE|NOT_ASSESSED`, determinado vía el nuevo
  collector `get_pam_limits_applicability(service)` (sigue `include`/`substack` con protección
  contra loops).
- **`os/cgroups` — regla de mínimo universal `min(nproc, TasksMax, pids.max)`**: v1.0.0 declaraba
  "el valor efectivo es el más restrictivo entre cgroup, nproc y TasksMax systemd", ignorando scope
  y membership de cada constraint. Corregido: `RLIMIT_NPROC`/`TasksMax`/`pids.max`/`pid_max` se
  modelan como constraints paralelos (scopes `USER`/`UNIT`/`CGROUP`/`HOST`) en el nuevo Binding
  Constraint Model de `os/process-limits` (`process_capacity`), que calcula la restricción
  vinculante real desde `applicability`+`scope`+`current_usage`+`headroom`+membership — nunca por
  comparación directa de valores configurados.

### Added

- Collector `get_pam_limits_applicability(service)` — `docs/OS_READONLY_COLLECTOR_MODEL.md`.
- Binding Constraint Model (`process_capacity: {constraints, binding_constraint}`) en
  `os/process-limits` v3.0.0; bloque `process_capacity`/`pam_limits` en
  `agents/os-platform-analyst/output-schema.yaml`.
- Manejo explícito de valores `UNLIMITED`/`FINITE`/`UNKNOWN` para constraints sin valor numérico.
- 7 fixtures y 19 tests nuevos — ver el reporte de cierre.
- `docs/PHASE_9_PAM_LIMITS_PROCESS_CONSTRAINT_SCOPE_HARDENING.md`.

### Changed

- `os/systemd-limits` v2.0.0→v3.0.0, `os/process-limits` v2.0.0→v3.0.0, `os/ulimits`
  v2.0.0→v3.0.0, `os/cgroups` v1.0.0→v2.0.0.
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `os`: notas extendidas con
  PAM session/pam_limits applicability/include-chain/binding-constraint.
- `tests/test_systemd_limits.sh`, `tests/test_systemd_service_does_not_assume_pam_limits.sh`,
  `tests/test_cgroup_pids_limit_awareness.sh` — aserciones actualizadas al nuevo modelo
  (`pam_limits:`/`pids_constraint:` reemplazan a `pam_applicable`/`pids_max`).

## [Unreleased] — 2026-09-14 — PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING

Hardening sobre la Fase 9 base (misma rama `phase/9-os-platform`), previo a aprobar
`v0.9.0-os-platform`. Ver `docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md` para el
reporte de cierre completo.

### Fixed

- **`os/systemd-limits` — regla universal incorrecta de "mínimo entre systemd y limits.conf"**:
  un proceso lanzado directamente por systemd normalmente no pasa por una sesión PAM, así que
  `/etc/security/limits.conf` no aplica automáticamente — la regla combinaba ambas fuentes sin esa
  distinción. Corregido: PAM sólo se correlaciona con evidencia explícita de `PAMName=` en la
  unit; el valor efectivo real se prioriza desde el PID objetivo (`get_process_effective_limits`),
  nunca inferido calculando el mínimo entre fuentes configuradas. `docs/OS_KERNEL_LIMITS_MODEL.md`
  corregido en el mismo sentido.
- **`os/process-limits`/`os/open-files`/`os/ulimits` — diagnostic-user ulimit tratado
  implícitamente como evidencia Oracle**: el `ulimit -a`/`prlimit` del propio proceso de
  diagnóstico nunca representó explícitamente sólo su propio contexto — ahora `diagnostic_session_limits`
  queda separado y nunca alimenta `effective_limits`.

### Added

- Modelo `launch_context` (`SYSTEMD|PAM_LOGIN|PAM_SU|MANUAL_SHELL|ORACLE_CLUSTERWARE|OTHER|UNKNOWN`)
  en `os/process-limits` v2.0.0, determinado antes de interpretar cualquier fuente configurada.
- Collectors `get_process_effective_limits` (PID-scoped, `/proc/<pid>/limits`),
  `get_service_limit_configuration` (unit systemd allowlisted), `get_pam_limit_configuration`
  (claves acotadas) — `docs/OS_READONLY_COLLECTOR_MODEL.md`.
- Bloque `process_limits_assessment` en `agents/os-platform-analyst/output-schema.yaml`
  (`launch_context`, `effective_limits`, `configured_sources`, `conflicts`).
- Manual Collection Contract (`docs/OS_HARDENING_MANUAL_ACTION_MODEL.md`) — fallback
  `INSUFFICIENT_PRIVILEGES` sin escalamiento de privilegios, distinto de `manual_action`.
- 5 fixtures nuevas (systemd effective, PAM session, diagnostic-user mismatch, insufficient
  privileges, configuration/effective mismatch) y 18 tests nuevos — ver el reporte de cierre.
- `docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md`.

### Changed

- `os/systemd-limits` v1.0.0→v2.0.0, `os/process-limits` v1.0.0→v2.0.0, `os/open-files`
  v1.0.0→v2.0.0, `os/ulimits` v1.0.0→v2.0.0.
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `os`: notas extendidas con
  el detalle de effective process limits/systemd/PAM/cgroup/Solaris/Windows/privilege escalation.
- `tests/test_systemd_limits.sh` — eliminada la aserción que institucionalizaba la regla
  incorrecta de mínimo universal.

## [Unreleased] — 2026-09-13 — PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING

Sobre baseline `v0.8.0-security-compliance`, rama `phase/9-os-platform`. Ver `docs/PHASE_9_OS_PLATFORM_DIAGNOSTICS_HARDENING.md` para el reporte de cierre completo.

### Added

- `agents/os-platform-analyst/` — deepening de manifest plano de Foundation a contrato estructurado completo v2.0.0 (`AGENT.md`, `manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`), mismo patrón que Security (Fase 8): `supersedes:` explícito, nunca reescrito desde cero. `agents/os-platform-analyst.md` (flat file de Foundation) eliminado, contenido preservado y ampliado.
- 45 skills `os/*` completamente materializados, reemplazando el modelo `os/<plataforma>/<skill>` de Foundation (18 skills × 5 plataformas, sólo `os/linux/memory` materializado) por un modelo domain-per-skill-id `os/<capability>` con platform-awareness vía campo `platforms:` en cada manifest — igual que `network/*`/`security/*`. `os/linux/memory.md` fusionado como base de `os/memory` v2.0.0.
- ~25 collectors OS semánticos (`docs/OS_READONLY_COLLECTOR_MODEL.md`), catalogados por Linux/Windows/Solaris — reutiliza (nunca duplica) los collectors ya certificados desde Fase 4 (`get_interfaces`, `get_routes`, `get_socket_summary`, `get_name_resolution`, `get_host_identity`).
- 7 docs de modelo: `docs/OS_PLATFORM_DIAGNOSTIC_MODEL.md`, `docs/ORACLE_HUGEPAGES_ASSESSMENT_MODEL.md`, `docs/OS_KERNEL_LIMITS_MODEL.md`, `docs/OS_NETWORK_DIAGNOSTIC_MODEL.md`, `docs/OS_STORAGE_FILESYSTEM_MODEL.md`, `docs/OS_HARDENING_MANUAL_ACTION_MODEL.md`, `docs/OS_READONLY_PRIVILEGES.md`.
- 26 fixtures (`tests/fixtures/*.yaml`) cubriendo Linux (Oracle Linux/RHEL/SUSE/LinuxONE), Solaris, Windows Server, y escenarios cross-domain (RAC interconnect, RMAN media manager, Data Guard network, security wallet).
- 67 tests nuevos cubriendo collector safety/agent contract, discovery/CPU/memoria, HugePages/THP, límites/IPC/AIO, puertos/red, filesystem/storage, time/SSH/grupos/procesos, integración cross-domain, sanitización, y contratos de collector por plataforma.
- Bloque `os_platform` en `docs/TARGET_PROFILE.md` (`schema_version` 2.5.0 → 2.6.0): `family`/`distribution`/`version`/`kernel`/`architecture`/`virtualization`/`oracle_home_owner`/`grid_home_owner`/`oracle_groups`/`expected_hugepages_policy`/`expected_thp_policy`/`expected_time_sync`/`expected_network_model` — sin secretos, campos `expected_*` nunca inventados sin declaración explícita del DBA.
- `/healthcheck os`, `/assessment os-platform` y routing de síntomas OS en `/diagnose` (`workflows/healthcheck.md`, `workflows/assessment.md`, `workflows/diagnose.md`).

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `os` pasa de `PARTIAL` a `SUPPORTED` (10g–23ai, `future_status: COMPATIBILITY_VALIDATION_REQUIRED`, mismo criterio que Data Guard/Multitenant/RMAN/Security). Linux `SUPPORTED`, Windows Server `SUPPORTED` (con sub-capacidades `PARTIALLY_SUPPORTED`/`NOT_APPLICABLE`), Solaris `PARTIALLY_SUPPORTED`, AIX/HP-UX fuera de alcance.
- `agents/REGISTRY.md`, `skills/REGISTRY.md` (`os` de 18×5 a 45 skills `active`) actualizados.

### Fixed

- Referencia obsoleta "entregables binarios (DOCX/XLSX/PDF/PPTX) son Fase 9" en `config/capability-matrix.yaml` y `templates/README.md` — factualmente incorrecta desde que la Fase 9 real pasó a ser OS Platform Diagnostics & Hardening; corregida a "fase de implementación aún no asignada".

## [Unreleased] — 2026-09-13 — PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION

Corrección final sobre la Fase 8 base (misma rama `phase/8-security-compliance`), previo a aprobar `v0.8.0-security-compliance`. Ver `docs/PHASE_8_FINAL_DBA_USERS_12102_SOURCE_OF_TRUTH_CORRECTION.md` para el reporte de cierre completo.

### Fixed

- **`DBA_USERS.COMMON`/`DBA_USERS.ORACLE_MAINTAINED` — boundary de patch-level incorrecto**: corregidos de `min_version: "12.1"` (leído como 12.1.0.1, entrada de CHANGELOG del hardening anterior) a `"12.1.0.2"`. Verificado en el HTML crudo (curl, sin resumen de modelo intermedio) de la página oficial `docs.oracle.com/database/121/REFRN/.../DBA_USERS`: footnote oficial explícito "This column is available starting with Oracle Database 12c Release 1 (12.1.0.2)." adjunto a `COMMON`, `ORACLE_MAINTAINED`, `LAST_LOGIN` y `PROXY_ONLY_CONNECT` las cuatro. La conclusión "12.1.0.1" del hardening anterior se basó en evidencia indirecta (Security Guide sobre la arquitectura Multitenant, blog datado) que confundía la feature arquitectónica (GA 12.1.0.1) con la columna de diccionario específica que la expone vía SQL (12.1.0.2) — dos intentos previos de fetch de la misma página oficial no detectaron el footnote porque se pierde en la conversión HTML→texto de un resumen de modelo intermedio.
- **`Q-SEC-DEFAULT-ACCOUNTS-001`**: `V1` (`legacy_pre12102`) extendida de `max: "11.2"` a `max: "12.1.0.1"` (cerraba un gap real: 12.1-12.1.0.1 no tenía variante que lo cubriera). `V2` (`modern_12102plus`) movida de `min: "12.1"` a `min: "12.1.0.2"`.
- **`Q-SEC-ACCOUNT-INVENTORY-001`**: `V2` (`multitenant_pre12102`, 12.1-12.1.0.1) ya no selecciona `common`/`oracle_maintained` — sólo `authentication_type` (certificada independientemente, 11.2+). `V3` (12.1.0.2+) permanece con las tres columnas.

### Removed

- `tests/test_dba_users_common_12101_valid.sh`, `tests/test_dba_users_oracle_maintained_12101_valid.sh` — aserciones factualmente incorrectas, eliminadas (no renombradas con contenido preservado).

### Added

- `tests/test_dba_users_common_12101_invalid.sh`, `tests/test_dba_users_oracle_maintained_12101_invalid.sh` — reemplazan a los tests eliminados con la aserción correcta (`NOT_CERTIFIED` en 12.1.0.1).
- `docs/PHASE_8_FINAL_DBA_USERS_12102_SOURCE_OF_TRUTH_CORRECTION.md`.

## [Unreleased] — 2026-09-12 — PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING

Hardening sobre la Fase 8 base (misma rama `phase/8-security-compliance`), previo a aprobar `v0.8.0-security-compliance`. Ver `docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md` para el reporte de cierre completo.

### Fixed

- **Static Validator — gap sistémico para objetos sin `$`**: `tests/test_sql_static_validator.sh#extract_aliases()` sólo reconocía objetos `V$*`/`GV$*` — cualquier objeto `DBA_*`/`CDB_*`/`ALL_*`/`USER_*`/`ROLE_*`/`AUDIT_*`/`UNIFIED_*`/`REDACTION_*` nunca entraba en `alias_map`, así que su existencia de columna y version-gating nunca se validaban, en ninguna fase del catálogo (Oracle Core, Data Guard, Multitenant, RMAN, Security). Corregido dictionary-driven: un token es candidato a vista si contiene `$` o coincide exactamente con un objeto registrado en `compatibility/oracle-dictionary/views.yaml`.
- **`DBA_USERS.LAST_LOGIN` — boundary de patch-level incorrecto**: corregido de `min_version: "12.1"` a `"12.1.0.2"` (verificado WebSearch/WebFetch, múltiples fuentes independientes citando "12.1.0.2" explícitamente) — la columna NO existe en 12.1.0.1. `COMMON`/`ORACLE_MAINTAINED` verificados correctos en `12.1` (`12.1.0.1`, GA de Multitenant) — una síntesis de WebFetch inicial que afirmaba `12.1.0.2` para las 3 columnas fue descartada por contradecir evidencia fechada independiente.
- **`Q-SEC-DEFAULT-ACCOUNTS-001`**: declaraba `min: "11.0"` y seleccionaba incondicionalmente `DBA_USERS.ORACLE_MAINTAINED` (real min 12.1) — sólo certificó por el gap del Static Validator. Dividida en variantes `legacy_11g` (11.0-11.2, sin `oracle_maintained`) y `modern_12plus` (12.1-23.0, con `oracle_maintained`).
- **`Q-SEC-ACCOUNT-INVENTORY-001`**: dividida de 2 a 3 variantes — la `V2` original (min "12.1", con `last_login`) habría certificado incorrectamente `LAST_LOGIN` para 12.1.0.1, donde no existe.
- **`Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` — fuente de evidencia estructuralmente incorrecta**: consultaba `SQLNET.*` desde `V$PARAMETER` — `SQLNET.*` es configuración de Oracle Net (`sqlnet.ora`), nunca un parámetro de inicialización de instancia. Retirada (`NOT_CERTIFIED: INCORRECT_EVIDENCE_SOURCE`, nuevo estado documentado en `docs/QUERY_VARIANTS.md`), reemplazada por el collector semántico `get_oracle_net_security_configuration`.

### Added

- `skills/network/oracle-net-security/` — nueva skill de `oracle-network-analyst` implementando el collector semántico `get_oracle_net_security_configuration` (allowlist de `SQLNET.ENCRYPTION_*`/`SQLNET.CRYPTO_CHECKSUM_*` + metadata TCPS, nunca lector de archivo genérico ni shell arbitrario). `skills/REGISTRY.md` pasa de 235 a 236 skills `active`.
- 15 tests nuevos: `test_security_default_accounts.sh` (faltante desde la creación de la query — detectado por el nuevo `test_all_security_query_test_references_exist.sh`), 4 tests de boundary patch-level `DBA_USERS` (`test_dba_users_last_login_12101_invalid/12102_valid`, `test_dba_users_oracle_maintained_12101_valid`, `test_dba_users_common_12101_valid` — 2 de los 4 nombres se desviaron deliberadamente de los sugeridos originalmente por contradecir la verificación real), 4 tests de cobertura del Static Validator para objetos `DBA_*`, 5 tests de evidencia de Oracle Net, `test_all_security_query_test_references_exist.sh`.

### Changed

- `config/query-compatibility-matrix.yaml`, `queries/REGISTRY.md` — `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` removida/marcada retirada; catálogo Security pasa de 30 a 29 queries SQL certificadas activas.
- `skills/security/network-encryption/`, `skills/security/tls-awareness/SKILL.md` — consumen ahora `network/oracle-net-security` en vez de la query retirada; fallback `PARTIALLY_SUPPORTED`/`evidence_source: MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION` documentado explícitamente.
- `agents/oracle-network-analyst/` — nueva skill en `allowed_skills`; `forbidden_capabilities` extendido con lector de archivo genérico/shell arbitrario/handshake TLS activo no certificado.
- `collectors/README.md`, `docs/QUERY_VARIANTS.md` (nuevo estado `INCORRECT_EVIDENCE_SOURCE` y nueva sección "Privilege-scope variants" — ver nota abajo), `docs/CAPABILITY_MATRIX.md`, `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md`.

### Known limitations

- `network/oracle-net-security` permanece `CONTRACT_DEFINED / NOT_RUNTIME_CERTIFIED` — el Gateway MCP real es Fase 13 (roadmap vigente; corregido desde la referencia obsoleta "Fase 7" en el micro-hardening posterior).
- La certificación patch-level de `DBA_USERS` se limita a las columnas efectivamente usadas por el catálogo Security (`ORACLE_MAINTAINED`, `COMMON`, `LAST_LOGIN`) — no exhaustiva de toda la vista.

## [Unreleased] — 2026-09-11 — Fase 8: Oracle Security & Compliance

Octava capa funcional del e-stack, sobre baseline `v0.7.0-backup-recovery-rman`. Ver `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md` para el reporte de cierre completo.

### Added

- `agents/oracle-security-analyst/` (`v2.0.0`) — deepening de manifest plano de Foundation (`agents/oracle-security-analyst.md`, real y materializado, a diferencia del caso RMAN) a contrato estructurado completo (`AGENT.md`/`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`/`tests/`/`CHANGELOG.md`) — responsabilidades/boundaries del v1.0.0 preservadas y ampliadas, nunca contradichas.
- 39 skills `security/*` completamente materializadas — `skills/REGISTRY.md` pasa de 196 a 235 skills `active` (dominio genuinamente nuevo, sin placeholder previo que reconciliar).
- `queries/security/` — 30 queries certificadas (`Q-SEC-ACCOUNT-INVENTORY-001`, `Q-SEC-DEFAULT-ACCOUNTS-001`, `Q-SEC-COMMON-LOCAL-USERS-001`, `Q-SEC-ROLES-001`, `Q-SEC-ROLE-GRANTS-001`, `Q-SEC-NESTED-ROLE-GRANTS-001`, `Q-SEC-SYSTEM-PRIVILEGES-001`, `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`, `Q-SEC-OBJECT-PRIVILEGES-001`, `Q-SEC-ROLE-OBJECT-PRIVILEGES-001`, `Q-SEC-PUBLIC-SYSTEM-GRANTS-001`, `Q-SEC-PUBLIC-OBJECT-GRANTS-001`, `Q-SEC-ADMIN-PRIVILEGES-001`, `Q-SEC-PROXY-AUTHENTICATION-001`, `Q-SEC-PASSWORD-PROFILES-001`, `Q-SEC-PASSWORD-VERIFY-SOURCE-001`, `Q-SEC-PASSWORD-VERSIONS-001`, `Q-SEC-UNIFIED-AUDIT-POLICIES-001`, `Q-SEC-UNIFIED-AUDIT-TRAIL-001`, `Q-SEC-TRADITIONAL-AUDIT-001`, `Q-SEC-TDE-WALLET-001`, `Q-SEC-ENCRYPTED-TABLESPACES-001`, `Q-SEC-ENCRYPTED-COLUMNS-001`, `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001`, `Q-SEC-SECURITY-PARAMETERS-001`, `Q-SEC-DB-LINKS-001`, `Q-SEC-DIRECTORIES-001`, `Q-SEC-DATABASE-VAULT-STATUS-001`, `Q-SEC-OLS-STATUS-001`, `Q-SEC-DATA-REDACTION-POLICIES-001`).
- `compatibility/oracle-dictionary/views.yaml` — 24 vistas nuevas de seguridad (`DBA_USERS`, `DBA_ROLES`, `DBA_ROLE_PRIVS`, `DBA_SYS_PRIVS`, `DBA_TAB_PRIVS`, `ROLE_*_PRIVS`, `DBA_PROFILES`, `DBA_USERS_WITH_DEFPWD`, `DBA_AUDIT_TRAIL`/`SESSION`, `UNIFIED_AUDIT_TRAIL`, `AUDIT_UNIFIED_ENABLED_POLICIES`, `AUDIT_UNIFIED_POLICIES`, `V$OPTION`, `V$ENCRYPTION_WALLET`, `V$ENCRYPTED_TABLESPACES`, `DBA_ENCRYPTED_COLUMNS`, `DBA_DB_LINKS`, `DBA_DIRECTORIES`, `DBA_NETWORK_ACLS`, `DBA_HOST_ACES`, `DBA_SOURCE`/`ALL_SOURCE`, `DBA_DV_STATUS`, `V$PWFILE_USERS`, `REDACTION_POLICIES`/`COLUMNS`, `PROXY_USERS`, `V$TABLESPACE`), cada boundary de versión verificado vía WebFetch/WebSearch antes de certificar (ver `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md#version-verification`).
- Password Strength Policy Model (`docs/ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md`) y Password Verify Function Analysis (`docs/ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md`) — nuevos: evaluación por control (longitud/complejidad/expiración/reuse/lock/grace) contra `Target Profile.security.password_policy`, inspección read-only del source de `PASSWORD_VERIFY_FUNCTION` (nunca ejecutado, nunca con contraseñas reales), `existing_password_compliance: NOT_DIRECTLY_VERIFIABLE` obligatorio incluso cuando la política actual es `COMPLIANT`.
- `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md`, `docs/ORACLE_SECURITY_DIAGNOSTIC_MODEL.md`, `docs/ORACLE_SECURITY_READONLY_QUERY_MODEL.md`, `docs/ORACLE_SECURITY_PRIVILEGE_MODEL.md`, `docs/ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md`, `docs/ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md`, `docs/ORACLE_AUDIT_DIAGNOSTIC_MODEL.md`, `docs/ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md`, `docs/ORACLE_SECURITY_LICENSING_GATES.md`, `docs/ORACLE_COMPLIANCE_MAPPING_MODEL.md`, `docs/ORACLE_SECURITY_READONLY_PRIVILEGES.md`.
- 24 fixtures de escenario (11g traditional audit/legacy account posture/password profile baseline; 19c unified audit healthy, excessive privilege, dangerous PUBLIC grant, stale accounts, weak profile policy, password policy compliant/non-compliant, custom verify function compliant/partially analyzable, external/global user N/A, TDE enabled/absent, keystore closed, TCPS configured, network encryption missing, common/local users, Database Vault awareness, compliance partial; 23ai modern security metadata; future unknown major).
- 75 tests nuevos: 9 accounts/privileges, 23 password policy (la mayor de las categorías — incluye 5 tests de bloqueo de exposición de hash/verifier/testing/cracking/reset), 6 profile/audit, 7 TDE/network, 6 advanced features/licensing, 6 compliance, 14 execution-block adicionales (`test_no_user_creation`, `test_no_grant_execution`, `test_no_audit_policy_change`, `test_no_keystore_change`, `test_no_database_vault_change`, `test_no_redaction_change`, `test_no_masking_execution` et al. — 3 nombres domain-prefixed porque `test_no_arbitrary_sql`/`test_no_arbitrary_shell`/`test_no_secrets` ya existían, propiedad de Data Guard, mismo patrón que Fase 7 con RMAN), 4 contrato de agente.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Security `PLANNED → SUPPORTED` (10g–23ai) para el dominio base; sub-capacidades con boundary propio (Unified Auditing 12.1+, TDE/keystore 11.2+, `INACTIVE_ACCOUNT_TIME` 12.2+) `PARTIALLY_SUPPORTED` sin afectar el dominio completo; Database Vault/OLS/Data Redaction/Data Masking siempre `LICENSE_DEPENDENT`; `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (mismo criterio que Fase 5-7).
- `docs/TARGET_PROFILE.md` — schema `2.4.0 → 2.5.0` (aditivo): bloque `security` (`compliance_frameworks`, `account_inactivity_policy_days`, `password_policy`, `encryption_required`, `audit_requirements`, `tls_required`, `licensing_profile`).
- `agents/REGISTRY.md` — `oracle-security-analyst` pasa de manifest plano (`agents/oracle-security-analyst.md`, Foundation `v1.0.0`) a estructura de carpeta completa (`v2.0.0`) — a diferencia de RMAN (que nunca tuvo un flat file real), aquí el flat file sí existía y sus responsabilidades/boundaries se preservaron íntegramente.
- `queries/REGISTRY.md`, `skills/REGISTRY.md` — 30 queries y 39 skills `security/*` registrados; `Q-SEC-COMMON-LOCAL-USERS-001` documentado como complemento (no reemplazo) de `Q-CDB-USERS-001` (Fase 6).
- `ARCHITECTURE.md` — 1 principio nuevo (30: password strength es evaluación de política nunca de contenido real, y una política actual compliant nunca certifica contraseñas existentes).
- `SECURITY.md` — caso concreto password verify function source inspection (vector de inyección en código PL/SQL real dentro de la base de datos, distinto de los casos previos de salida de comando externo).
- `policies/forbidden-operations.md` — nueva sección "Security / Users / Roles / Auditing / Encryption" con la lista completa de operaciones prohibidas del dominio.
- `workflows/healthcheck.md`, `workflows/assessment.md`, `workflows/diagnose.md` — extendidos con activación/enrutamiento de `oracle-security-analyst`/`security/*`.

### Known limitations

Ver `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md#known-limitations`. En resumen: `security/data-masking-awareness` no tiene visibilidad real de Enterprise Manager (Data Masking and Subsetting Pack es un producto EM, fuera de alcance de introspección SQL directa) — awareness conceptual/de licenciamiento únicamente; `security/password-verify-function` no es un parser PL/SQL completo, sólo detección de patrones deterministas (`REGEXP_LIKE`/`LENGTH`); `DBA_NETWORK_ACLS`/`DBA_HOST_ACES` certificadas en el dictionary pero sin query/skill dedicado en esta fase (no nombrados explícitamente en la lista de 39 skills del prompt).

## [Unreleased] — 2026-09-09 — Fase 7: Oracle Backup & Recovery / RMAN

Séptima capa funcional del e-stack, sobre baseline `v0.6.0-multitenant`. Ver `docs/PHASE_7_ORACLE_BACKUP_RECOVERY_RMAN.md` para el reporte de cierre completo.

### Added

- `agents/oracle-backup-recovery-analyst/` (`v1.0.0`) — contrato estructurado completo (`AGENT.md`/`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`/`tests/`/`CHANGELOG.md`), mismo patrón que Fase 4/5/6.
- 30 skills `rman/*` completamente materializadas — `skills/REGISTRY.md` pasa de 166 a 196 skills `active` (reemplaza el placeholder de 14 skills `registered` de Foundation).
- `queries/rman/` — 14 queries certificadas (`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-STATUS-001`, `Q-RMAN-OUTPUT-001`, `Q-RMAN-BACKUP-JOB-001`, `Q-RMAN-BACKUP-SET-001`, `Q-RMAN-BACKUP-PIECE-001`, `Q-RMAN-BACKUP-DATAFILE-001`, `Q-RMAN-ARCHIVELOG-BACKUP-001`, `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`, `Q-RMAN-CONTROLFILE-BACKUP-001`, `Q-RMAN-SPFILE-BACKUP-001`, `Q-RMAN-BACKUP-DEVICE-001`, `Q-RMAN-FRA-USAGE-001`, `Q-RMAN-CONTROLFILE-RECORD-SECTION-001`).
- `compatibility/oracle-dictionary/views.yaml` — 14 vistas RMAN nuevas, todas `columns_exhaustive: true`, verificadas vía WebFetch contra docs.oracle.com/oracle-base.com (`V$RMAN_CONFIGURATION` desde 9i, `V$RMAN_STATUS`/`V$RMAN_OUTPUT`/`V$RMAN_BACKUP_JOB_DETAILS` desde 10g).
- `parsers/rman/` — 6 parsers (`show_all_parser.py`, `list_backup_parser.py`, `list_backup_summary_parser.py`, `report_obsolete_parser.py`, `report_need_backup_parser.py`, `restore_preview_parser.py`) + `common.py`, para ingest de output RMAN ya producido manualmente por el DBA — nunca ejecutado.
- `docs/PHASE_7_ORACLE_BACKUP_RECOVERY_RMAN.md`, `docs/RMAN_DIAGNOSTIC_MODEL.md`, `docs/RMAN_READONLY_QUERY_MODEL.md`, `docs/RMAN_COMMAND_SAFETY_MODEL.md`, `docs/RMAN_RECOVERY_READINESS_MODEL.md`, `docs/RMAN_RAC_DATAGUARD_MULTITENANT_INTEGRATION.md`, `docs/RMAN_READONLY_PRIVILEGES.md`.
- 16 fixtures de escenario (11g/19c/23ai disk backup, incremental strategy, FRA pressure, archivelog backup lag, controlfile autobackup disabled, snapshot controlfile local-path RAC risk, RAC multiple channels, SBT backup, media manager contention, Data Guard standby backup, PDB backup context, restore readiness healthy/incomplete, versión futura desconocida).
- 69 tests nuevos: 11 query/inventario, 7 parsers, 19 canales/FRA/readiness, 13 RAC/DG/MT/SBT, 15 seguridad específicos de Fase 7 (`# 46`: no arbitrary RMAN, no backup/restore/recover/delete/crosscheck/change/configure/catalog/uncatalog/duplicate/switch-database/channel-allocate execution, SQL/secrets domain-scoped), 4 contrato de agente.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — RMAN `PARTIAL → SUPPORTED` (10g–23ai); `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (mismo criterio que Data Guard/Multitenant).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-RMAN-BACKUP-JOB-001`/`Q-RMAN-BACKUPSET-001` (Foundation) figuraban "materializadas" sin archivo real. `Q-RMAN-BACKUP-JOB-001` materializado de verdad (`V$RMAN_BACKUP_JOB_DETAILS`, verificado real vía WebFetch); `Q-RMAN-BACKUPSET-001` reemplazado por `Q-RMAN-BACKUP-SET-001` (mismo propósito, nombre corregido a la convención hyphenated del resto de `Q-RMAN-*`).
- `agents/REGISTRY.md` — corregido un gap pre-existente: apuntaba a `agents/oracle-backup-recovery-analyst.md` (plano), archivo que nunca existió realmente (dangling reference desde Foundation) — ahora apunta a `agents/oracle-backup-recovery-analyst/AGENT.md`.
- `skills/rman/backup-status.md` (plano, Foundation) → `skills/rman/backup-status/{SKILL.md,manifest.yaml}` (carpeta), mismo patrón de migración que `agents/oracle-multitenant-analyst.md` en Fase 6.
- `docs/TARGET_PROFILE.md` — schema `2.3.0 → 2.4.0` (aditivo): bloque `backup_recovery`.
- `ARCHITECTURE.md` — 2 principios nuevos (28: `ANALYTICAL_PREVIEW` como categoría nunca invocada; 29: recoverability nunca inferida de la existencia de un backup set).
- `SECURITY.md` — caso concreto parsers RMAN (SBT `PARMS` tokenizado, `RESTORE ... PREVIEW` nunca ejecutado).

### Known limitations

Ver `docs/PHASE_7_ORACLE_BACKUP_RECOVERY_RMAN.md#known-limitations`. En resumen: `rman/multitenant-awareness`/`rman/pdb-pitr-awareness` degradan a `PARTIALLY_SUPPORTED` para el detalle completo de PDB-level RMAN backup/restore por versión (mejoras 12.1→12.2, sin verificación exhaustiva); `rman/sbt-media-manager` sin integración profunda de ningún vendor específico (awareness genérica únicamente); Gateway MCP/ejecución real de collectors semánticos fuera de alcance.

### Fixed — PHASE 7 — RMAN Legacy SQL Syntax & Query Certification Hardening

Cierre de un defecto de compatibilidad SQL detectado antes de aprobar `v0.7.0-backup-recovery-rman`. Ver `docs/PHASE_7_RMAN_LEGACY_SQL_SYNTAX_HARDENING.md` para el detalle completo.

- **10 queries RMAN certificaban `FETCH FIRST ... ROWS ONLY` con `min_version: "10.2"`** (bug real): la row limiting clause (ANSI SQL:2008) requiere Oracle Database 12.1+ (verificado vía WebFetch), no disponible en 10g/11g. Ninguno de los 3 chequeos existentes del Static Validator (view/column version-gating, column existence) podía detectarlo — el repositorio nunca había modelado la dimensión "sintaxis SQL por versión". Corregidas las 9 queries `implicit_full_range` afectadas (split en variantes `-V1 legacy_10g_11g`/`-V2 modern_12plus`, `ROWNUM` sobre inline view ya ordenado para 10g/11g) y `Q-RMAN-BACKUP-SET-001` (sólo su variante V1 in-place, split preexistente por `CON_ID` no rehecho). `Q-RMAN-CONFIGURATION-001`/`Q-RMAN-BACKUP-DEVICE-001`/`Q-RMAN-CONTROLFILE-RECORD-SECTION-001`/`Q-RMAN-FRA-USAGE-001` sin cambios (nunca usaron row limiting).
- **SQL Syntax Feature Compatibility Model (causa raíz)**: nuevo `compatibility/oracle-sql-syntax/features.yaml` (`FETCH_FIRST`, `OFFSET_ROWS`, ambas `min_version: "12.1"`), deliberadamente separado del dictionary de vistas/columnas. `tests/test_sql_static_validator.sh` extendido con un Chequeo 4 (`check_syntax_features`) que detecta cláusulas de sintaxis version-gated en cualquier bloque SQL certificado de todo el catálogo (`queries/**`, no sólo RMAN) usando `scripts/lib/version.sh` exclusivamente — verificado unitariamente contra los 5 casos del prompt antes de tocar ningún query real.
- `config/query-compatibility-matrix.yaml` — 9 entradas `Q-RMAN-*` migradas de `implicit_full_range` a variantes explícitas `-V1`/`-V2`.
- 14 tests nuevos (matriz de features, boundary FETCH_FIRST/OFFSET_ROWS, 3 fixtures positivos/negativo embebidos, 2 tests de regresión global sobre todo el catálogo, 5 tests de resolución de variante RMAN-scoped por versión 10g/11g/12c/19c/23ai).
- `docs/ORACLE_SQL_SYNTAX_COMPATIBILITY_MODEL.md`, `docs/PHASE_7_RMAN_LEGACY_SQL_SYNTAX_HARDENING.md` — nuevos. `docs/QUERY_VARIANTS.md` — certificación ahora declara 4 dimensiones (view/column/**SQL syntax**/version compatibility), no 3.

### Fixed — PHASE 7 — RMAN Security Test Robustness Micro-Hardening

Cierre de un falso negativo detectado en `tests/test_no_arbitrary_rman.sh` antes de aprobar `v0.7.0-backup-recovery-rman`. Ver `docs/PHASE_7_RMAN_SECURITY_TEST_ROBUSTNESS_HARDENING.md` para el detalle completo.

- **`tests/test_no_arbitrary_rman.sh` fallaba sobre `agents/oracle-backup-recovery-analyst/manifest.yaml:91`** pese a que esa línea vive dentro del bloque `forbidden_capabilities:` (línea 78). Causa doble: la ventana de sólo 3 líneas hacia atrás no alcanzaba a ver la clave YAML envolvente, y el wildcard `ning.n` no empareja los 2 bytes UTF-8 de "ningún" en este entorno (Git Bash/MSYS). El problema estaba en el test, no en la arquitectura — el manifest ya declaraba correctamente la prohibición.
- Test reescrito para ser structure-aware sobre YAML (`classify_yaml_section()`, vía `awk` — no un parser YAML completo): `forbidden_capabilities`/`blocked_capabilities`/`prohibited_capabilities`/`prohibited` → PASS estructural; `allowed_tools`/`allowed_capabilities`/`collectors`/`tools`/`execution`/`runtime`/`actions` → FAIL duro; sección no reconocida o archivo no-YAML → fallback al chequeo de lenguaje de prohibición previo, con el wildcard UTF-8 corregido (`ningún|ningun` explícitos en vez de `ning.n`).
- 3 fixtures controladas embebidas en el propio test (sin tocar `queries/rman/**`/`skills/rman/**`/`parsers/rman/**`): negativa (`allowed_tools` + los 3 nombres peligrosos → FAIL), positiva (`forbidden_capabilities` + los 3 nombres → PASS), UTF-8 (`ningún` con tilde en texto libre → PASS).
- Sin debilitar detección: `execute_rman`/`run_rman`/`rman_shell` se siguen buscando en todo el dominio; la mejora es de clasificación de contexto, no de cobertura.
- `TEST_SCOPE: TARGETED` — sólo se modificó lógica de un test de seguridad, ninguna infraestructura compartida (`scripts/lib/version.sh`, Static Validator, Query Variant Resolver, harness global, escáner de seguridad global). 16/16 tests targeted (incluye los 14 tests de seguridad RMAN directamente relacionados, el contrato del agente y portabilidad LF) en PASS, sin full regression.

## [Unreleased] — 2026-09-08 — Fase 6: Oracle Multitenant / CDB / PDB

Sexta capa funcional del e-stack, sobre baseline `v0.5.0-dataguard`. Ver `docs/PHASE_6_ORACLE_MULTITENANT.md` para el reporte de cierre completo.

### Added

- `agents/oracle-multitenant-analyst/` (`v2.0.0`) — reestructurado de manifest plano a contrato estructurado completo, mismo patrón que Fase 4/5.
- 26 skills `multitenant/*` completamente materializadas — `skills/REGISTRY.md` pasa de 141 a 166 skills `active`.
- `queries/multitenant/` — 15 queries certificadas (`Q-CDB-PDB-STATE-001`, `Q-CDB-CONTAINERS-001`, `Q-CDB-PDB-SAVED-STATE-001`, `Q-CDB-SERVICES-001`, `Q-CDB-SESSION-DIST-001`, `Q-CDB-TABLESPACES-001`, `Q-CDB-TEMP-001`, `Q-CDB-PARAMETERS-001`, `Q-CDB-USERS-001`, `Q-CDB-ROLES-001`, `Q-CDB-COMPONENTS-001`, `Q-CDB-PLUGIN-VIOLATIONS-001`, `Q-CDB-RESOURCE-USAGE-001`, `Q-CDB-RESOURCE-MANAGER-001`, `Q-CDB-LOCKDOWN-001`).
- `compatibility/oracle-dictionary/views.yaml` — 15 vistas Multitenant nuevas, 7 con `columns_exhaustive: true` (`V$PDBS`, `V$CONTAINERS`, `DBA_PDB_SAVED_STATES`, `PDB_PLUG_IN_VIOLATIONS`, `V$RSRCPDBMETRIC`, `DBA_CDB_RSRC_PLAN_DIRECTIVES`, `CDB_LOCKDOWN_PROFILES` — nombre/rango de las primeras 3 corregido en el hardening posterior, ver entrada `[Unreleased] Fase 6: Query Compatibility & Dictionary Certification Hardening` abajo).
- `docs/PHASE_6_ORACLE_MULTITENANT.md` (incluye el Manual Action Contract), `docs/MULTITENANT_DIAGNOSTIC_MODEL.md`, `docs/CDB_PDB_QUERY_MODEL.md`, `docs/MULTITENANT_READONLY_PRIVILEGES.md`, `docs/PDB_HEALTHCHECK_MODEL.md`.
- 14 fixtures de escenario (11g NON-CDB, 12.1/12.2/19c/21c/23ai CDB, RAC PDB placement, PDB mounted/restricted, plug-in violations, temp/resource pressure, contexto Data Guard, Application Container, versión futura desconocida).
- 53 tests nuevos: 14 query/inventario, 7 versión, 4 RAC, 5 plug-in violations, 4 recursos, 15 seguridad específicos de Fase 6 (`# 62`: no create/drop/clone/unplug/plug PDB, no open/close/save-state execution, no alter session container si prohibido, no common/local user create, no lockdown/resource-manager/parameter change, queries SELECT-only), 4 contrato de agente.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Multitenant `PARTIAL → SUPPORTED` (12.1–23ai); columna `latest` reemplazada por `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (mismo criterio que Data Guard Fase 5).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` (Foundation) nunca tuvieron archivo real ni `container_scope` correcto pese a figurar "materializadas"; ahora genuinamente construidas bajo `queries/multitenant/`.
- `docs/TARGET_PROFILE.md` — schema `2.2.0 → 2.3.0` (aditivo): bloque `multitenant`.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — nota apuntando a `docs/MULTITENANT_READONLY_PRIVILEGES.md` (documento nuevo, no consolidado aquí).
- `ARCHITECTURE.md` — 2 principios nuevos (26: Container Scope Contract; 27: `MESSAGE`/`ACTION` como DATA + Health Model sin score único).
- `SECURITY.md` — caso concreto `PDB_PLUG_IN_VIOLATIONS.MESSAGE`/`.ACTION` como vector de inyección interno a la base de datos (distinto de los casos previos de salida de comando externo).

### Known limitations

Ver `docs/PHASE_6_ORACLE_MULTITENANT.md#known-limitations`. En resumen: Application Containers/Proxy PDB reconocidos por topología sin análisis profundo de lifecycle (`PARTIALLY_SUPPORTED`); 8 vistas `CDB_*` mirror estándar registradas sin `columns_exhaustive: true`; sin errores ORA-650xx/651xx específicos en `knowledge/errors/` (opcional, no inventado).

### Fixed — PHASE 6 — Multitenant Query Compatibility & Dictionary Certification Hardening

Cierre de 3 defectos de certificación detectados antes de aprobar `v0.6.0-multitenant`. Ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md` para el detalle completo.

- **`Q-CDB-PDB-SAVED-STATE-001` (bug real)**: seleccionaba `FROM cdb_pdb_saved_states` — esa vista no existe (WebFetch: 404 en docs.oracle.com). Corregida a v2.0.0, usa `DBA_PDB_SAVED_STATES` (7 columnas reales). Además, la feature requiere patch level 12.1.0.2 — no existe en 12.1.0.0/12.1.0.1; `config/query-compatibility-matrix.yaml` y el dictionary ahora declaran `min: "12.1.0.2"` (patch-level), con una extensión aditiva del comparador de versión (`vernum3`) acotada a este caso.
- **`Q-CDB-RESOURCE-USAGE-001` (rango de versión incorrecto)**: `V$RSRCPDBMETRIC` declarada disponible desde 12.1 sin verificación independiente — en realidad se introduce en 12.2.0.1 (WebFetch confirmado). Corregida a `min: "12.2"`; 12.1 degrada explícitamente a `capability_status: PARTIALLY_SUPPORTED` (sin fuente alternativa inventada) en `skills/multitenant/resource-usage/SKILL.md`.
- **`Q-CDB-PLUGIN-VIOLATIONS-001` (rango de versión incorrecto)**: `CON_ID` seleccionado incondicionalmente desde 12.1 — esa columna no existe en la referencia 12.1 (9 columnas), se agrega en 12.2 (10 columnas, WebFetch confirmado en ambas versiones). Corregida a v2.0.0 con dos variantes reales (legacy 12.1 sin `CON_ID` / modern 12.2+ con `CON_ID`); `skills/multitenant/plugin-violations/SKILL.md` normaliza `container_id: NOT_AVAILABLE` en la variante legacy, nunca inventado.
- **SQL Static Validator (causa raíz)**: sólo validaba existencia de columna en la vista, nunca si esa columna/vista ya existía en el `min_version` declarado del bloque SQL — por eso las 3 metadata incorrectas certificaron SQL incorrecto sin que ningún test lo detectara. Añadido un tercer chequeo (view-level y column-level `min_version` cross-check contra el rango declarado, patch-level-aware vía `vernum3`) sobre las 7 vistas Multitenant `columns_exhaustive: true`. Corregido de paso un efecto colateral: la derivación de `min` del bucle `implicit_full_range` (por etiqueta descriptiva "12c"→12.1) producía falsos positivos contra `Q-CDB-LOCKDOWN-001`/`Q-CDB-RESOURCE-USAGE-001` (ambas 12.2+-only) — sustituido por el `min` preciso de `config/query-compatibility-matrix.yaml` sólo para este chequeo nuevo, sin alterar el chequeo de version-gating original.
- Dictionary certification: `CDB_PDB_SAVED_STATES` eliminada (no era una vista real); `V$CONTAINERS` completada con bloque `validation:` (ya estaba verificada, faltaba la trazabilidad declarada); 2 tests negativos (`FAKE_MULTITENANT_VIEW`/`fake_column`) confirman que un nombre fabricado nunca certifica.
- 21 tests nuevos de regresión específicos de este hardening.

### Fixed — PHASE 6 — Final PDB Identity & Patch-Level Resolver Hardening

Cierre de los 2 últimos defectos antes de aprobar `v0.6.0-multitenant`. Ver `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md` para el detalle completo.

- **`PDB_PLUG_IN_VIOLATIONS.NAME` semantics (interpretación incorrecta)**: la construcción base y el hardening de compatibilidad asumían que `NAME` identifica "la violación/componente", no la PDB — verificado vía WebFetch (Oracle Database Reference 12.1 y 19c, ambas coinciden): *"The name of an existing PDB or a PDB intended to be created"*. `NAME` es identidad de PDB, disponible en todo el rango 12.1–23ai. Corregido: `Q-CDB-PLUGIN-VIOLATIONS-001.md` (v3.0.0) y `skills/multitenant/plugin-violations/SKILL.md` (v3.0.0) — en 12.1, `container_name`/`pdb_token` ahora se derivan de `NAME` (sanitizado, `container_id` sigue `NOT_AVAILABLE`); en 12.2+ se correlacionan `CON_ID`+`NAME`, publicando `IDENTITY_MISMATCH` si no coinciden. `name` corregido de sanitización `KEEP` a `MASK` (tokenizado, mismo criterio que `Q-CDB-PDB-STATE-001.name`). `ACTION`/`MESSAGE` mantienen su protección "siempre DATA" sin cambios.
- **Query Variant Resolver sin implementación compartida (causa raíz)**: el "resolver" nunca fue un componente único — era un algoritmo documentado reimplementado ad-hoc como `vernum()`/`vernum3()` local en ~22 archivos de test, sólo uno de ellos (el Static Validator) con soporte patch-level real. Anti-patrón: un test podía declarar cobertura patch-level sin que ninguna implementación real la tuviera. Fix: `scripts/lib/version.sh` — librería única compartida (`normalize_oracle_version`, `compare_oracle_versions`, `version_gte`, `version_lte`, `version_in_range`; modelo de 5-tupla, patch-level-aware, preserva los alias de marketing y el sentinel `latest` ya usados por ~40 queries de fases anteriores). `tests/test_sql_static_validator.sh` y `tests/test_query_variant_resolver_{10g,11g}.sh` refactorizados para consumirla — sin cambio de comportamiento, verificado explícitamente contra el resultado previo al refactor.
- 13 tests nuevos (identidad de PDB + librería de versión compartida + integración resolver) y 4 tests refactorizados sin cambio de comportamiento.
- ~~Conocido: la librería compartida no se propagó a los ~17 archivos de test de resolución de variantes fuera de alcance...~~ — **resuelto**, ver subsección siguiente.

### Fixed — PHASE 6 — Version Resolver Consolidation Finalization

Cierra el último bloqueo antes de aprobar `v0.6.0-multitenant`. Ver `docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md` para el detalle completo.

- **Migración completa**: los 17 archivos de test restantes que reimplementaban `vernum()`/`vernum3()` localmente (`test_query_variant_resolver_{12c,18c,19c,21c,23ai}.sh`, `test_dataguard_process_variant_resolution_{11g,121,122,19c,23ai}.sh`, `test_dataguard_{23ai_supported_when_certified,24_or_future_not_auto_supported}.sh`, `test_fixture_query_variant_resolution.sh`, `test_query_variant_ranges_do_not_overlap_invalidly.sh`, `test_version_resolver_{12101,12102}.sh`, `test_plugin_violation_variant_resolution.sh`) migrados a `scripts/lib/version.sh` — sin cambio de comportamiento verificado explícitamente, salvo un hallazgo real: `test_query_variant_resolver_12c.sh` detectó que `Q-CDB-PDB-SAVED-STATE-001` (min real `12.1.0.2`) resolvía incorrectamente como compatible para "12c" con el comparador 2-tier antiguo (patch level ignorado) — el comparador patch-level-aware corrige esto correctamente (no una regresión).
- **Enforcement global endurecido**: `tests/test_query_variant_resolver_uses_shared_version_library.sh` reescrito de un allowlist fijo de 7 archivos a una verificación dinámica — delega la comprobación negativa a un nuevo test global (`tests/test_no_local_version_resolvers_in_tests.sh`, recorre `tests/**/*.sh`+`scripts/**/*.sh` excepto la librería canónica) y comprueba positivamente que todo test que invoque una función de la librería la sourcee, sin exigir el import a tests que no comparan versiones.
- 2 tests nuevos (`test_no_local_version_resolvers_in_tests.sh`, `test_shared_version_library_exists.sh`).
- Documentación obsoleta corregida: `queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md` y la cabecera de `compatibility/oracle-dictionary/views.yaml` ya no describen "el resolver genérico compara sólo major.minor" como limitación vigente — declaran `scripts/lib/version.sh` como la única implementación de comparación de versión autorizada en todo el repositorio.

## [0.5.0-dataguard] — 2026-09-07 — Fase 5: Oracle Data Guard

Quinta capa funcional del e-stack, sobre baseline `v0.4.0-rac-gi-asm-network`. Ver `docs/PHASE_5_ORACLE_DATAGUARD.md` para el reporte de cierre completo.

### Added

- `agents/oracle-dataguard-analyst/` (`v2.0.0`) — reestructurado de manifest plano a contrato estructurado completo, mismo patrón que Fase 4.
- 21 skills `dataguard/*` completamente materializadas — `skills/REGISTRY.md` pasa de 120 a 141 skills `active`.
- `queries/dataguard/` — 7 queries certificadas (`Q-DG-ROLE-001`, `Q-DG-STATS-001`, `Q-DG-DEST-001`, `Q-DG-ARCHIVED-LOG-001`, `Q-DG-ARCHIVE-GAP-001`, `Q-DG-MANAGED-PROCESS-001`, `Q-DG-SRL-001`).
- `parsers/dataguard/` (nuevo, Python 3 stdlib-only) — `broker_parser.py` (4 funciones DGMGRL `SHOW`), `alertlog_filter.py` (filtro local de alert.log), mismo envelope/disciplina de seguridad que `parsers/rac/` de Fase 4.
- `docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md` — Collector Contract Broker (reutiliza Fase 4), `docs/DATAGUARD_DIAGNOSTIC_MODEL.md`, `docs/DATAGUARD_READONLY_QUERIES.md`, `docs/DATAGUARD_SWITCHOVER_READINESS.md`, `docs/DATAGUARD_FAILOVER_READINESS.md`, `docs/PHASE_5_ORACLE_DATAGUARD.md` (incluye el Manual Action Contract).
- 17 fixtures de escenario (11gR2/19c/23ai, RAC primary+standby, transport/apply lag, archive gap, MRP stopped, destination error, SRL insuficiente, degradación de protección, Broker healthy/warning, FSFO enabled, switchover ready/not-ready, failover exposure) + 6 fixtures de salida DGMGRL Broker (`tests/fixtures/broker/`, incl. prueba de prompt-injection).
- ~80 tests nuevos: 10 query, 11 Broker, 6 transporte, 7 apply, 4 gap, 6 SRL, 7 readiness, 3 licensing, ~17 seguridad específicos de Fase 5, 4 contrato de agente.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Data Guard `PARTIAL → SUPPORTED` (10g–23ai para Physical Standby).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-DG-STATS-001`/`Q-DG-ARCHIVE-GAP-001` (Foundation) nunca tuvieron archivo real pese a figurar "materializadas"; ahora genuinamente construidas bajo `queries/dataguard/`.
- `docs/TARGET_PROFILE.md` — schema `2.1.0 → 2.2.0` (aditivo): bloque `dataguard`.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — grants Data Guard, cuarta identidad separada (Broker diagnóstica).
- `mcp/tool-manifest.md` — 9 tools nuevas; corregida referencia stale de `get_dataguard_status`.

### Known limitations

Ver `docs/PHASE_5_ORACLE_DATAGUARD.md#known-limitations`. En resumen: Logical/Snapshot Standby/Far Sync reconocidos sin análisis profundo; `broker_parser.py` primera versión funcional; leak real de `db_unique_name` sin tokenizar detectado y corregido durante la construcción (campo `observer_state` eliminado del parser).

### Fixed — PHASE 5 — Data Guard Compatibility & Query Certification Hardening

Cierre de 3 defectos de certificación detectados antes de aprobar `v0.5.0-dataguard`. Ver `docs/PHASE_5_COMPATIBILITY_HARDENING.md` para el detalle completo.

- **`Q-DG-ROLE-001` (bug real)**: seleccionaba `LOG_ARCHIVE_CONFIG` de `V$DATABASE` — esa columna no existe ahí (es un parámetro, vía `V$PARAMETER`). Corregida a v2.0.0; fuente correcta documentada vía `Q-ORA-PARAMETERS-001`.
- **SQL Static Validator (causa raíz)**: sólo validaba version-gating de 4 columnas conocidas, nunca existencia real de columna — por eso el bug de `Q-DG-ROLE-001` pasó todos los tests. Añadido un segundo chequeo de existencia de columna (alias-aware, JOIN/comma-join-aware, abstención ante subqueries) sobre vistas marcadas `columns_exhaustive: true` en `compatibility/oracle-dictionary/views.yaml` (9 vistas Data Guard auditadas en este hardening). Halló, de paso, el mismo patrón de defecto en `V$ASM_DISK` (Fase 4, fuera de alcance — documentado, no corregido aquí).
- **Future version policy**: `config/query-compatibility-matrix.yaml` declaraba `max: latest` en las 7 queries `Q-DG-*`, que el resolver interpreta como techo sin límite (`vernum("latest") = 99999`) — contradiciendo la propia declaración `UNKNOWN_FUTURE` del agente para versiones futuras. Corregido a `max: "23.0"` explícito en las 7. Aclarada la semántica de `latest: SUPPORTED` en `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md`. Corregidas también 3 entradas `role_scope: PHYSICAL_STANDBY` remanentes (fuera del enum) en la misma matriz.
- **`Q-DG-MANAGED-PROCESS-001` modernizada**: de un único statement legacy (`V$MANAGED_STANDBY`) a un modelo de variantes legacy (default, 10.2+)/modern (`V$DATAGUARD_PROCESS`, on-demand, 11.2+), con normalización semántica a un modelo lógico común — sin forzar equivalencia en campos que la vista moderna no expone (`thread`/`sequence` quedan `PARTIALLY_SUPPORTED` en la variante moderna).
- 15 tests nuevos de regresión específicos de este hardening.

### Fixed — PHASE 5 — Data Guard Final Process-View & Portability Hardening

Cierre de 4 defectos finales antes de aprobar `v0.5.0-dataguard`. Ver `docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_HARDENING.md` para el detalle completo.

- **`V$DATAGUARD_PROCESS` metadata (bug real)**: el hardening anterior declaró `min_version: "11.2"` y columnas `status`/`client_process` — ambos datos incorrectos, verificado contra Oracle Database Reference. Versión real de introducción: **12.2.0.1**. `STATUS`/`CLIENT_PROCESS` no son columnas de esta vista (pertenecen a `V$MANAGED_STANDBY` — confusión entre ambas vistas). Corregido a las columnas reales documentadas (`name`/`pid`/`type`/`role`/`action`/`client_pid`/`client_role`/`thread#`/`sequence#`/`block#`/`block_count`); `V$MANAGED_STANDBY` corregida también (agregadas `thread#`/`client_pid`, documentada su deprecación oficial desde 12.2.0.1).
- **Legacy/modern boundary corregida**: de "legacy default 10.2–23.0 + modern on-demand desde 11.2" a una partición real sin solapamiento — legacy única opción 10.2–12.1, modern única opción 12.2–23.0. `Q-DG-MANAGED-PROCESS-001` v3.0.0.
- **Semantic normalization corregida**: modelo lógico renombrado (`process_name`/`process_role`/`process_action`/`client_pid`/`thread`/`sequence`/`source_view`/`source_variant`) — `thread`/`sequence` pasan de `PARTIALLY_SUPPORTED` (suposición incorrecta del hardening anterior) a soportados en ambas variantes; único campo sin equivalente real es `process_role` en legacy.
- **`latest: SUPPORTED` eliminado estructuralmente** de la fila `dataguard` en `config/capability-matrix.yaml` (no sólo reinterpretado por comentario como en el hardening anterior) — reemplazado por `future_status: COMPATIBILITY_VALIDATION_REQUIRED`. `docs/CAPABILITY_MATRIX.md` actualizado igual.
- **Regresión CRLF corregida**: `compatibility/oracle-dictionary/views.yaml` tenía terminadores de línea CRLF pese a `.gitattributes` ya declarar `eol=lf` — normalizado a LF (contenido sin cambios semánticos). Barrido de todo el repositorio confirmó que era el único archivo afectado.
- **Nuevo test general de portabilidad**: `tests/test_repository_text_files_are_lf.sh` (Python stdlib, escanea *.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md) + `tests/test_gitattributes_lf_policy.sh`.
- 10 tests nuevos + 6 tests corregidos (no cosméticos — reflejan el rango/columnas reales corregidos).

## [0.4.0-rac-gi-asm-network] — 2026-09-04 — Fase 4: RAC / Grid Infrastructure / ASM / Network

Cuarta capa funcional del e-stack, sobre baseline `v0.3.0-performance`. Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md` para el reporte de cierre completo.

### Added

- `agents/oracle-rac-analyst/` (`v2.0.0`), `agents/oracle-asm-storage-analyst/` (`v2.0.0`), `agents/oracle-network-analyst/` (`v2.0.0`) — los 3 reestructurados de manifest plano a contrato estructurado completo (`AGENT.md`/`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`/`tests/`/`CHANGELOG.md`), mismo patrón que `oracle-performance-analyst` v4.0.0. `oracle-rac-analyst` absorbe Grid Infrastructure — sin agente GI separado.
- `agents/os-platform-analyst.md` (`v1.1.0`) — extensión ligera: colaboración con `oracle-rac-analyst`/`oracle-network-analyst` para interconnect OS-level/TCP.
- 57 skills nuevas completamente materializadas: 31 `rac/*` (19 RAC + 12 `gi-*`), 12 `asm/*`, 14 `network/*` — `skills/REGISTRY.md` pasa de 63 a 120 skills `active`.
- `queries/rac/` (`Q-RAC-TOPOLOGY-001` con 2 variantes, `Q-RAC-SERVICES-001`, `Q-RAC-INTERCONNECT-001`, `Q-RAC-GES-GCS-001`) y `queries/asm/` (`Q-ASM-TOPOLOGY-001`, `Q-ASM-DISKS-001`, `Q-ASM-REBALANCE-001`) — 7 queries certificadas nuevas.
- `parsers/rac/` (nuevo, Python 3 stdlib-only) — 8 parsers de salida de collectors GI/Clusterware/ASM/red (`crsctl_resource_parser.py` cubre resources+version+oifcfg, `olsnodes_parser.py`, `srvctl_scan_parser.py`, `srvctl_service_parser.py`, `lsnrctl_status_parser.py`, `ocrcheck_parser.py`, `voting_parser.py`, `asmcmd_lsdg_parser.py`), mismo envelope/disciplina de seguridad que `parsers/performance/` de Fase 3.
- `docs/GI_READONLY_COLLECTORS.md` — Collector Contract completo (16 collectors: 11 GI/Clusterware/ASM + 5 OS network), `docs/RAC_DIAGNOSTIC_MODEL.md`, `docs/ASM_DIAGNOSTIC_MODEL.md`, `docs/ORACLE_NETWORK_DIAGNOSTIC_MODEL.md`, `docs/PHASE_4_RAC_GI_ASM_NETWORK.md` (incluye el Manual Action Contract).
- 15 fixtures de collectors (`tests/fixtures/collectors/`) + 13 fixtures de escenario (11gR2/19c/23ai RAC, service imbalance, SCAN healthy/DNS failure, listener registration issue, TNS timeout, ASM normal/low-capacity/rebalance, interconnect anomaly).
- 9 entradas nuevas de `knowledge/errors/` (`tns/`: TNS-12541/12537/12170/01199; `ora/`: ORA-3136/27300-27301/27501-27530; `crs/`: CRS-4535/4529/4533).
- 68 tests nuevos: 16 collector/parser (incl. prueba viva de prompt-injection), 11 RAC, 8 ASM, 11 Network, 14 seguridad específicos de Fase 4, 8 contrato de agente.
- `EVOLUTION.md` sección 15 — `/change parser` con checklist obligatorio para nuevos tipos de collector/parser.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — RAC/GI/ASM/Network `PARTIAL/FOUNDATION_ONLY → SUPPORTED` (11gR2–23ai; 10g queda `PLANNED`/`UNSUPPORTED` según corresponda).
- `queries/rac/Q-RAC-SESSION-DIST-001.md` relocalizada desde `queries/` plano (mismo ID, sin duplicar).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-RAC-SERVICE-PLACEMENT-001`/`Q-ASM-DG-USAGE-001`/`Q-ASM-OPERATION-001` (Foundation) nunca tuvieron archivo real pese a figurar "materializadas"; reemplazadas por las 7 queries RAC/ASM genuinamente construidas esta fase.
- `docs/TARGET_PROFILE.md` — schema `2.0.0 → 2.1.0` (aditivo): bloques `rac`/`gi`/`asm`/`network`.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — grants RAC/GI/Network/ASM, separación explícita de 3 identidades (database/GI-OS/ASM).
- `mcp/tool-manifest.md` — 15 tools nuevas; corregidas 2 referencias a queries Foundation nunca materializadas (`get_session_distribution`, `get_asm_usage`, `get_listener_status`).
- `collectors/README.md` — 4 tipos de collector nuevos documentados en la tabla existente, referencia a `docs/GI_READONLY_COLLECTORS.md`.
- `workflows/rac.md` (`v2.0.0`), `workflows/healthcheck.md`/`assessment.md`/`diagnose.md` extendidos con las invocaciones acotadas `/healthcheck rac|asm|network`, `/assessment rac`, escenarios `/diagnose rac|service|scan|listener|interconnect|asm|connection`.
- `.gitattributes`/portabilidad (Fase 3 Completion Hardening) sin cambios — 0 archivos nuevos con CRLF detectados en esta fase.

### Known limitations

Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#known-limitations`. En resumen: parsers `parsers/rac/*.py` primera versión funcional, validados contra fixtures propios, no contra la diversidad completa de formatos `crsctl`/`srvctl` entre versiones GI; TAF/Application Continuity documentados narrativamente sin `skill_id`/query/collector propio; sin collector de latencia de red certificado; gap pre-existente de Multitenant sin cambios (no corresponde a esta fase).

## [0.3.0-performance] — 2026-09-03 — Fase 3: Performance Completion & Portability Hardening

Cierra 4 gaps de Fase 3 sobre el mismo baseline `v0.2.0-oracle-core` — no es un rebuild de Fase 3. Ver `docs/PHASE_3_COMPLETION_HARDENING.md` para el reporte de cierre completo.

### Added

- `parsers/performance/` (nuevo, Python 3 stdlib-only — primer código fuente no Markdown/YAML/Bash del repositorio): `common.py` (envelope `ParsedReport`, `ParseStatus`, `SizeLimitPolicy`, `Sanitizer`), `type_detector.py`, `statspack_parser.py`, `awr_parser.py`, `addm_parser.py`, `execution_plan_parser.py`, `ingest.py` (orquestador único), `__init__.py`.
- Statspack ahora cubre reportes multi-sección completos (Load Profile, Instance Efficiency, Top Wait Events, SQL ordered by CPU/elapsed/executions/gets/reads, Instance Activity, Library Cache, Latch, Enqueue, I/O incl. ASM, Memory/Cache Sizes, Redo/Commit y Parsing derivados) — antes sólo wait events.
- 15 fixtures de reportes (`tests/fixtures/reports/`), incluyendo un intento de prompt injection (`addm-injection-attempt.txt`) usado para probar que el contenido de un reporte nunca se interpreta como instrucción.
- 28 tests nuevos de parsers (detección de tipo ×6, parsers AWR/ADDM/execution-plan ×4, Statspack ×12, seguridad/límites/sanitización ×3, secciones faltantes/malformadas/vacías ×3).
- `agents/oracle-performance-analyst/` materializado en contrato estructurado completo (`v4.0.0`): `manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`, `tests/README.md`, `CHANGELOG.md`; `AGENT.md` reescrito como documento narrativo que referencia, nunca duplica, esos campos.
- 7 tests nuevos de contrato de agente (manifest/routing/context-policy/collaboration/output-schema/no-execution-capability/no-delegation-loop).
- `.gitattributes` — fuerza `eol=lf` en `*.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md`.
- `tests/test_no_crlf_in_shell_scripts.sh` — falla el build si cualquier `*.sh`/`*.bash` contiene CRLF o carece de shebang bash válido.
- `tests/run_all.py` — runner de tests portable en Python 3 (stdlib only), coherente con `tests/run-all.sh`, no lo reemplaza.

### Changed

- `skills/performance/statspack-analysis` (`v2.0.0`) — capability map explícito por sección (`statspack_capabilities:`), 3 patrones de correlación certificados nuevos.
- `skills/performance/awr-analysis` (`v1.1.0`), `skills/performance/addm-analysis` (`v1.1.0`), `skills/performance/execution-plan` (`v1.1.0`) — añadida ruta de ingesta de reporte de archivo vía el parser correspondiente, sin tocar la ruta de query en vivo existente.
- `tests/run-all.sh` — agrega totales (`N/M tests OK`) y lista de nombres de tests fallidos al resumen; preserva el comportamiento existente (no fail-fast, exit code agregado).
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Statspack ya no se limita a "sólo wait events"; nota actualizada para reflejar cobertura multi-sección con `capability_status` por sección.
- **Normalización de line endings**: 85 archivos `tests/test_*.sh` pre-existentes (de Foundation Hardening/Fase 2/Oracle Core Compatibility Hardening) contenían CRLF real, no detectado hasta ahora porque el chequeo original carecía de la flag `-U`/`--binary` de grep (en Git Bash/MSYS, grep descarta CR de fin de línea antes de matchear salvo que se le indique explícitamente no hacerlo). Normalizados a LF sin alterar contenido (verificado byte a byte, `diff` vacío tras `tr -d '\r'`).

### Known limitations

- `awr_parser.py` es una primera versión funcional — alineación de columnas numéricas imperfecta en algunas filas de wait events; no cubre todos los formatos históricos de AWR.
- El parser de ejecución de planes requiere la firma exacta `"| Id  | Operation"`; formatos de `DBMS_XPLAN` no tabulares devuelven `UNSUPPORTED_FORMAT` en vez de un intento de mejor esfuerzo.
- Ningún parser genera evidencia desde un reporte que el DBA no haya adjuntado — la ruta de query en vivo sigue siendo la única fuente de evidencia sin insumo externo.

Segunda capa funcional del e-stack, sobre baseline `v0.2.0-oracle-core`. Ver `docs/PHASE_3_ORACLE_PERFORMANCE.md` para el reporte de cierre completo.

### Added

- `agents/oracle-performance-analyst/AGENT.md` (`v3.0.0`) — reestructurado a carpeta profunda; Licensing Gate formalizado, Performance workflow, Correlation model con ejemplos certificados, SQL text policy, Manual command generation (nunca `KILL SESSION`/`ALTER SYSTEM` ejecutado).
- 31 skills `performance/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), incluyendo 3 previamente ni siquiera `registered` (`memory`, `commit-redo`, `trending`).
- `queries/performance/` — 21 queries certificadas (Query Contract v2 + Query Variant Contract), todas `implicit_full_range`, sin discrepancias metadata↔SQL.
- `Q-PERF-WAIT-STATSPACK-001` materializada (antes sólo `registered`) — Statspack como ruta de primera clase, no fallback de segunda categoría.
- 11 fixtures nuevas (`tests/fixtures/{10g-statspack,11g-statspack,12c-awr,19c-standalone-performance,19c-rac-multi-instance,19c-no-diagnostic-pack,19c-blocking,19c-high-cpu,19c-high-io,19c-log-file-sync,23ai-modern-performance}.yaml`).
- 47 tests nuevos: AWR (9), Statspack (5), ruta estándar sin licencia (5), SQL performance (6), memoria (4), concurrencia (4), I/O (3), paralelismo (2), seguridad (8), version-support (1).
- `docs/PHASE_3_ORACLE_PERFORMANCE.md` — reporte de cierre de fase.
- 9 tools MCP nuevas en `mcp/tool-manifest.md` (`get_db_time`, `get_execution_plan`, `get_memory_status`, `get_io_waits`, `get_active_temp_usage`, `get_blocking_sessions`, `get_parallel_sessions`, `get_redo_activity`; `get_top_sql_metrics` materializada de `registered` a `active`).

### Changed

- `Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-ASH-001` relocalizadas de `queries/` plano a `queries/performance/waits/` (mismos IDs, sin duplicar).
- `skills/performance/wait-events` reestructurado de `wait-events.md` plano a `wait-events/SKILL.md` + `manifest.yaml` (v2.0.0) — extendido con ruta dinámica sin licencia, no reconstruido.
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — `Performance` `PARTIAL → SUPPORTED`, `Statspack` `FOUNDATION_ONLY → SUPPORTED` (10g–23ai); `AWR`/`ASH`/`ADDM` sin cambio (`LICENSE_DEPENDENT`, no es limitación del e-stack).
- `workflows/analyze.md` extendido con mapeo explícito `performance`/`sql`/`memory`/`io`/`waits` → `oracle-performance-analyst`, sin slash commands nuevos.
- `workflows/awr.md` — gate de versión actualizado (Statspack `FOUNDATION_ONLY → SUPPORTED`).
- `policies/licensing-awareness-policy.md`, `queries/REGISTRY.md` — referencias de ruta actualizadas tras la relocalización de `wait-events`.

### Known limitations

Ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#known-limitations`. En resumen: parser local de AWR HTML/texto externo documentado pero no implementado (evidencia proviene de queries certificadas contra el ambiente vivo, no de parsear un archivo); Statspack cubre sólo wait events (Load Profile/SQL statistics vía Statspack quedan para `/change query` futuro); `V$PQ_SYSSTAT` agregado no materializado; ADDM se interpreta sólo cuando el DBA provee su output, nunca generado por el e-stack.

## [0.1.0] — 2026-09-02 — Fase 1: Foundation

### Added

- Arquitectura, planos del sistema y decisiones de diseño (`ARCHITECTURE.md`).
- Modelo de seguridad, amenazas y controles (`SECURITY.md`).
- Modelo de evolución gobernada `/change` (`EVOLUTION.md`).
- Modelo de distribución y bootstrap (`DISTRIBUTION.md`).
- Agent Contract, Skill Contract, Workflow Contract y Query Contract definitivos (`docs/CONTRACTS.md`).
- Registro completo de 18 agentes obligatorios con manifests conforme al Agent Contract (`agents/`).
- Registro completo del catálogo de skills por dominio (`skills/REGISTRY.md`) con materialización representativa por dominio.
- Catálogo certificado inicial de queries/tools semánticas read-only, extendido más allá de las 14 nombradas explícitamente para cubrir RMAN/backup, security posture y capacity trending (`queries/`).
- Diseño del MCP Diagnostic Gateway local y su tool manifest (`mcp/`).
- Política de sanitización y minimización de datos (`sanitizers/`).
- Políticas de seguridad, identidad, operaciones prohibidas, rate limiting, licensing y retención de evidencia (`policies/`).
- Modelo de evidencia (`raw/sanitized/derived`) y de análisis (`analysis/ANA-*`) con trazabilidad EVD→FND→REC→CHG.
- Modelo de documentación Markdown-first con entregables binarios bajo demanda (`docs/CONTRACTS.md`, `templates/`).
- 13 slash commands implementados en `.claude/commands/`, cada uno resolviendo a un Workflow Contract en `workflows/`.
- Taxonomía inicial de `knowledge/errors/` (ORA/TNS/RMAN/CRS) con entradas representativas validadas.
- Suite de tests de Fase 1: prohibición de escritura, prohibición de shell arbitrario, bloqueo de application data, detección de secretos, trazabilidad de evidencia, activación mínima de agentes, tests adversariales/prompt-injection (`tests/`).
- Scripts de bootstrap de estación de trabajo (`scripts/`).

### Known limitations

Ver reporte de cierre de Fase 1. En resumen: el Gateway MCP, los collectors y los generadores de documentos binarios son contratos/diseño, no runtime ejecutable; eso corresponde a Fases 2–9.

## [0.1.0-foundation] — 2026-09-02 — Foundation Hardening

Pass de endurecimiento sobre el mismo baseline de Fase 1 (no avanza a Fase 2). Ver reporte de cierre "FOUNDATION HARDENING RESULT".

### Added

- **Query Contract v2** (`docs/CONTRACTS.md`, `queries/_QUERY_CONTRACT_TEMPLATE.md`): `container_scope`, `database_role_scope`, `risk_class` (separado de `cost_class`), `cost_class`, `max_output_bytes`, `sanitization_required`, `license_requirements`, `execution_mode: READ_ONLY`.
- `policies/query-cost-policy.md` — clasificación LOW/MEDIUM/HIGH/BLOCKED, distinta de `risk_class`.
- `policies/capability-degradation-policy.md` — modelo formal de 8 estados (`SUPPORTED…ENVIRONMENT_UNKNOWN`) con `reason/impact/alternative/required_action`.
- `policies/version-awareness-policy.md` — representación normalizada de versión (`major/minor/release/ru/raw`) y degradación explícita por versión/arquitectura.
- `docs/CAPABILITY_MATRIX.md` + `config/capability-matrix.yaml` — cobertura por 17 dominios × 8 versiones Oracle.
- `skills/core/version-awareness.md` — materializado (`registered → active`).
- Bloque `gates:` (version/architecture/environment/license/privilege/security/cost/evidence) en el Workflow Contract y en los 13 workflows activos.
- Pipeline `DISCOVERY → CAPABILITY FILTER → AGENT FILTER → SKILL FILTER → CONTEXT PACKAGE` y métricas `agents_skipped_by_capability`/`skills_skipped_by_version`/`skills_skipped_by_license`/`queries_skipped_by_cost`/`tokens_avoided` en `docs/CONTRACTS.md` y `agents/oracle-operations-orchestrator.md`.
- 28 tests nuevos (IDs canónicos, Query Contract v2, cost class, los 8 estados de capability, gates de version/license/workflow, schema y consistencia de la Capability Matrix) — ver `tests/README.md`.

### Changed (breaking)

- **`skill_id` es siempre domain-qualified** (`dominio/skill`). `skills/REGISTRY.md` reescrito con `skill_id` explícito por fila; nombres cortos (`temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io`) dejan de ser identificadores válidos — sólo `display_name`.
- `agents/os-platform-analyst.md` — `Allowed skills` corregido de `os/<skill>` a `os/<platform>/<skill>` para coincidir con el `skill_id` canónico real.
- `queries/REGISTRY.md`, `queries/_QUERY_CONTRACT_TEMPLATE.md` y las 3 queries materializadas migradas a Query Contract v2 (`objects_queried` → `objects_accessed`, `versions` → `supported_oracle_versions`, `platform` → `supported_os`, `architecture` → `supported_architectures`, `risk` → `risk_class` + `cost_class` nuevo).
- `policies/rate-limiting-policy.md` — la clasificación de costo se movió a `policies/query-cost-policy.md`; esta política mantiene sólo los límites por defecto.
- `policies/licensing-awareness-policy.md` — agregada la secuencia de gate explícita y el estado formal `LICENSE_RESTRICTED`.
- `EVOLUTION.md` — nueva sección 13 (`/change compatibility` — validaciones obligatorias); `GAP ANALYSIS`/`IMPACT ANALYSIS`/`TEST` amplían su alcance.
- `tests/test_application_data_blocked.sh`, `tests/test_version_awareness.sh`, `tests/test_query_limits.sh` actualizados a los nuevos nombres de campo.

### Known limitations

Las mismas de Fase 1 (Gateway MCP/collectors/generadores de documentos son contrato, no runtime). Adicional: `test_no_ambiguous_skill_references.sh` es una heurística de grep sobre backticks, no un parser real de Markdown — puede tener falsos negativos ante formatos de referencia no anticipados; se refuerza en Fase 2+ si aparecen casos reales.

## [0.2.0-oracle-core] — 2026-09-03 — Oracle Core Compatibility Hardening

Pasada de endurecimiento sobre `v0.2.0-oracle-core` (branch `phase/2-oracle-core`), previa a aprobar ese baseline — NO una reconstrucción de Fase 2. Ver `docs/PHASE_2_COMPATIBILITY_HARDENING.md` para el reporte de cierre completo.

### Added

- **Query Variant model** (`docs/QUERY_VARIANTS.md`) — separa logical query de physical SQL variant; Query Variant Resolver documentado (Target Profile → variante compatible → SQL certificado); nunca "closest version", nunca fallback silencioso.
- `compatibility/oracle-dictionary/views.yaml` — capa mínima de disponibilidad de vistas/columnas por versión Oracle, usada por el SQL Static Validator.
- `config/query-compatibility-matrix.yaml` — fuente estructurada por logical query (variantes, rango, vistas requeridas, `validation_status`).
- 28 tests nuevos: SQL Static Validator, contrato de variantes (7), Resolver por versión (7 + no-match), regresión específica Identity/RAC/ASM/TEMP/CDB/PDB (10), documentación-vs-realidad, fixture-resolution.
- `compatibility_schema` (`available_views`/`available_columns`) en las 9 fixtures existentes.

### Changed

- `Q-DISC-IDENTITY-001` (v3.0.0), `Q-DISC-RAC-001` (v2.0.0), `Q-ORA-INSTANCE-STATE-001` (v2.0.0), `Q-DBA-TBS-USAGE-001` (v2.0.0) — divididas en variantes reales; ya no declaran soporte de versión sin SQL validado para ese rango.
- `Q-DISC-ASM-001` (v2.0.0) — variante `routine_stat` (`V$ASM_DISKGROUP_STAT`, `cost_class: LOW`, default) separada de `detailed_diskgroup` (`V$ASM_DISKGROUP`, `cost_class: MEDIUM`, on-demand only).
- `Q-ORA-JOBS-SUMMARY-001` + `skills/oracle/jobs/SKILL.md` (v1.1.0) — alcance acotado a `DBMS_SCHEDULER`; gap `DBA_JOBS` legacy documentado `PARTIALLY_SUPPORTED`/`PLANNED`, no un SELECT ficticio.
- `Q-ORA-ARCHIVE-001`, `Q-ORA-CONTROLFILE-001`, `Q-ORA-DB-STATE-001`, `Q-ORA-REDO-001`, `Q-ORA-REDO-SWITCH-FREQ-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001` — `container_scope: CDB_ROOT → ANY_CONTAINER` (CDB_ROOT es exclusivo de Multitenant 12c+, inválido junto a soporte 10g/11g declarado); propagado a `queries/REGISTRY.md`.
- `docs/CONTRACTS.md` — campo opcional `open_mode_scope` en el Query Contract.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — mapping `query_variant → required object privilege`.
- `mcp/tool-manifest.md` — sección "MCP Query Certification" (sólo `CERTIFIED` por target, nunca `NOT_CERTIFIED`/`PARTIAL sin variant`/`UNKNOWN`).
- `EVOLUTION.md` — checklist obligatorio de `/change compatibility` extendido (dictionary delta + variants + matrix + fixtures + tests + skills + docs).
- `config/capability-matrix.yaml` — nota de `oracle-core` extendida (validación real vía Resolver, gap `DBA_JOBS` documentado).

### Fixed

- `tests/test_non_cdb_pdb_unsupported.sh` (Foundation Hardening) — su aserción de que existe una query materializada `container_scope: CDB_ROOT` quedó invalidada por la corrección de arriba; ajustada para validar la existencia del valor de enum en el contrato, no un uso concreto.
- 6 tests de extracción de bloque SQL por variante (`test_identity_*`/`test_rac_*`) tenían un bug de coincidencia de patrón `awk` que capturaba el bloque de metadata del frontmatter en vez del heading real del body.

## [0.2.0-oracle-core] — 2026-09-03 — Fase 2: Oracle Core

Primera capa funcional Oracle del e-stack, sobre baseline `v0.1.0-foundation`. Ver `docs/PHASE_2_ORACLE_CORE.md` para el reporte de cierre completo.

### Added

- **Target Profile** (`docs/TARGET_PROFILE.md`) — schema estructurado de identidad de ambiente (versión normalizada, arquitectura, rol, container, capabilities), publicado una vez por análisis y reutilizado por todo el pipeline.
- `agents/oracle-discovery-analyst/AGENT.md` (`v2.0.0`) — Discovery Sequence de 11 pasos, detección por dimensión, Discovery Cache diferenciado por volatilidad.
- `agents/oracle-dba-analyst/AGENT.md` (`v2.0.0`) — 18 áreas Oracle Core, DBA Command Generation formalizado.
- 18 skills `oracle/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), reemplazando el único ejemplo representativo de Fase 1.
- ~20 queries nuevas `Q-ORA-*` (Query Contract v2) bajo `queries/oracle/<categoría>/`, más 3 queries de discovery/tablespaces previamente sólo-registro ahora materializadas.
- `policies/discovery-cache-policy.md` — TTL diferenciado por volatilidad de campo.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — propuesta de `ESTACK_DIAGNOSTIC_ROLE` para Oracle Core (revisión humana, nunca ejecutado).
- 9 fixtures (`tests/fixtures/*.yaml`) para 10g/11g/12c/19c/21c/23ai × standalone/RAC/CDB/standby.
- 40 tests nuevos: 7 de detección por versión, 18 de skill Oracle Core, 12 de seguridad, 3 de compatibilidad de query.
- 15 nuevas tools MCP semánticas en `mcp/tool-manifest.md` (`get_database_state`, `get_controlfile_metadata`, etc.).

### Changed

- `agents/oracle-discovery-analyst.md` y `agents/oracle-dba-analyst.md` → reestructurados a `agents/<id>/AGENT.md` (extensión aditiva; el resto de agentes permanece plano).
- `skills/oracle/tablespaces.md` → `skills/oracle/tablespaces/SKILL.md` + `manifest.yaml`, extendido de v1.0.0 a v2.0.0.
- `config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md`: fila `oracle-core` de `PARTIAL` a `SUPPORTED` en las 8 columnas de versión.
- `workflows/healthcheck.md` → `v2.0.0`, cobertura ampliada a las 18 áreas Oracle Core.
- `skills/core/context-discovery.md` → `v1.1.0`, nota de supersesión de nomenclatura por el Target Profile (sin romper Foundation).
- Tests de Foundation/Hardening que escaneaban `queries/*.md` de forma plana actualizados para recorrer `queries/oracle/**` recursivamente.

### Known limitations

Ver `docs/PHASE_2_ORACLE_CORE.md#known-limitations`. En resumen: Gateway MCP/collectors/generadores de documentos siguen siendo contrato, no runtime; multi-PDB individual no iterado automáticamente; RAC One Node no confirmable sin query adicional; tests estáticos/basados en fixtures, no contra ambiente real.
