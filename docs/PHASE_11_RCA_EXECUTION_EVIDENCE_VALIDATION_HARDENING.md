# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING

Hardening sobre `docs/PHASE_11_INCIDENT_ANALYSIS_ROOT_CAUSE_AUTOMATION.md` (misma rama
`phase/11-incident-rca`, baseline `v0.10.0-capacity-forecasting`). Mismo patrón exacto que
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md` aplicó a `capacity_engine/`
sobre `skills/capacity/*`: cierra la brecha entre los 34 skills `incident/*` declarativos y un
motor RCA local, ejecutable y verificable.

## Diagnóstico inicial (gap reproducido)

Antes de este hardening, `incident/root-cause`, `incident/timeline`, `incident/hypothesis-testing`,
`incident/contradiction-analysis` y el resto del dominio `incident` eran contratos (`SKILL.md` +
`manifest.yaml`) y 63 tests estructurales que verifican, vía `grep`, que ciertas frases/secciones
existen en esos Markdown — nunca ejecutan un análisis RCA real sobre evidencia. Ningún test previo
al hardening invoca un motor, procesa un fixture o produce un resultado calculado: el gap es
idéntico en naturaleza al que `PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md`
documentó para `capacity/forecasting` antes de `capacity_engine/`.

## Local engine location / invocation

`rca_engine/` (13 módulos Python 3, sólo stdlib, sin numpy/scipy/pandas — mismo criterio que
`capacity_engine/`):

```text
rca_engine/
  __init__.py          — re-exporta run_rca(), CONTRACT_VERSION, ENGINE_VERSION
  common.py             — enums (HypothesisStatus, RootCauseCompleteness, ConfidenceLevel,
                           TimelineConfidence, EvidenceManifestCompleteness) y dataclasses
  sanitize.py            — redacción KEEP/MASK/HASH/TOKENIZE/DROP en ejecutable (nuevo — no
                            existía un sanitizador Python previo que reutilizar, sólo la política
                            Markdown de sanitizers/data-classification-policy.md)
  intake.py               — validación de schema + sanitización-al-ingreso + evidence manifest
  timeline.py              — normalización UTC, clock skew, dedup con provenance
  rules.py                  — carga del catálogo versionado/allowlisted + motor de matching
  hypothesis.py              — generación/evaluación de hipótesis, gates de status
  causality.py                — agregación a RCA-level, gate de evidence-manifest, recomendaciones
  report.py                    — Markdown leído directamente del JSON (nunca recalculado)
  engine.py                     — orquestación run_rca(), analysis_origin determinista
  cli.py                         — entrypoint invocable (python3 -m rca_engine.cli)
  rules/default_rules.json       — catálogo de 6 reglas versionado (rules_version 1.0.0)
```

Invocación real:

```bash
python3 -m rca_engine.cli --fixture incident.json \
  [--rules rules.json] [--policy policy.json] \
  [--out result.json] [--markdown report.md] [--manifest manifest.json] \
  [--out-dir allowed/output/dir]
```

Ejercitado directamente por `tests/test_rca_*.sh` vía `tests/lib/rca_engine_e2e_helpers.sh`
(mismo patrón portable de rutas relativas que `tests/lib/capacity_engine_e2e_helpers.sh` — ver
ese archivo para la causa raíz completa del problema POSIX-vs-Windows-nativo, reproducido
idénticamente aquí y corregido con la misma estrategia desde el primer commit, nunca repetido).

## Algorithm / rules version / input-output contract

`CONTRACT_VERSION = "1.0.0"`, `ENGINE_VERSION = "rca_engine.rules_engine/1.0.0"`,
`rules_version` propio del catálogo (`"1.0.0"` en `default_rules.json`) — los tres se registran en
cada `RcaResult`. Input: `{"incident": {...}, "evidence": [...]}`. Output: `RcaResult` con
`timeline`, `evidence_manifest`, `hypotheses`, `root_cause`, `recommendations`,
`cross_domain_domains_involved`, `validation_issues`, `limitations`. `analysis_origin` es siempre
el timestamp máximo de evidencia normalizada realmente usada — nunca `datetime.now()`;
`generated_at` es la única metadata de reloj real, explícitamente excluida de la comparación de
reproducibilidad (mismo patrón que `history_end` vs `generated_at` en `capacity_engine.engine`).

## Timeline / UTC / clock-skew / dedup

`timeline.py` implementa `docs/INCIDENT_TIMELINE_MODEL.md` en código ejecutable:
timestamps con offset explícito (`Z`, `-06:00`, `+02:00`) se normalizan correctamente a UTC
(`test_rca_timestamp_timezone_normalization`); un timestamp naive se normaliza igual pero degrada
`timeline_confidence` explícitamente; una fuente con `source_clock_offset_seconds` por encima de
`policy.clock_skew_threshold_seconds` degrada toda su evidencia
(`test_rca_ambiguous_timestamp_or_clock_skew`); dedup agrupa por
`(source_id, domain, event_type, signature, timestamp // dedup_window_seconds)` conservando
`count`/`first_seen`/`last_seen`/`evidence_ids` (`test_rca_event_order_and_dedup_preserves_provenance`).
Orden cronológico estable (Python `sort` estable + `raw_index` como desempate determinista).

## Hypothesis engine / confirmation gates

`rules.py` + `hypothesis.py` + `causality.py` implementan el motor de reglas declarativo del § 4
del prompt de hardening: cada regla de `rules/default_rules.json` declara `symptom_match`,
`supporting_conditions`, `contradicting_conditions` (con `critical: true/false`),
`temporal_proof_condition` opcional y `min_independent_sources`. Orden de evaluación de estado
(`hypothesis.py#_status_and_confidence`, documentado en el propio módulo):

1. Contradicción crítica no resuelta → `WEAKENED`/`REJECTED`, **nunca** `CONFIRMED` — sin
   mecanismo de resolución automática en este motor.
2. Prueba temporal inequívoca → `CONFIRMED`.
3. `independent_source_count >= min_independent_sources` de la regla → `CONFIRMED`.
4. Alguna evidencia de soporte → `SUPPORTED`.
5. Nada → `INSUFFICIENT_EVIDENCE` (un síntoma aislado nunca se eleva por sí mismo).

`CAUSAL_ELIGIBLE_EVENT_TYPES` excluye estructuralmente `RECOVERY` — un evento de mitigación nunca
puede satisfacer ninguna condición de una regla, aunque declare atributos que coincidirían
(`test_rca_mitigation_not_root_cause`, verificado con evidencia que deliberadamente sí coincidiría
si no estuviera excluida por tipo). Múltiples hipótesis pueden alcanzar `CONFIRMED`
independientemente (múltiples causas raíz); hipótesis igualmente soportadas sin diferenciador
producen `INCONCLUSIVE` explícito, nunca un ganador arbitrario
(`test_rca_competing_hypotheses_remain_inconclusive`).

## Evidence manifest / completeness gate

`intake.build_evidence_manifest()` compara `incident.declared_evidence_refs` contra la evidencia
realmente presente; `causality.apply_evidence_completeness_gate()` degrada estructuralmente
**cualquier** hipótesis `CONFIRMED` a `SUPPORTED` cuando `evidence_manifest.completeness ==
INCOMPLETE_REFS` — una referencia declarada pero rota impide `CONFIRMED` incluso cuando la
evidencia presente es idéntica al caso que sí confirma (`test_rca_missing_or_broken_evidence_ref`,
usa el mismo fixture que el caso positivo, sólo agregando una referencia inexistente).

## Cross-domain evidence reuse

`causality.cross_domain_domains_involved()` enumera los dominios de toda evidencia efectivamente
referenciada por las hipótesis generadas. Verificado con un fixture RAC/OS/Network real
(`test_rca_cross_domain_evidence_reuse`) que confirma la regla `RULE-RAC-INTERCONNECT-001` y
reporta los 3 dominios y sus `evidence_id` exactos en la salida.

## Sanitization / read-only enforcement

`sanitize.py` (nuevo, no existía sanitizador Python previo — sólo la política Markdown) redacta,
mediante patrones de ejemplo (`password`, `secret`, `token` seguidos de `=` y un valor), claves
AWS, bloques PEM `PRIVATE KEY` y hashes hex de 32+ caracteres de todo campo de texto libre
(`summary`, `symptom_description`) **antes** de que
cualquier estructura llegue a `RcaResult`. `test_rca_no_secrets_in_outputs_or_logs` inyecta 4
canarios sintéticos distintos y verifica su ausencia en JSON, Markdown **y** stderr. `rca_engine/`
nunca importa `subprocess`, nunca llama `os.system()`, y no define `execute_sql`/`execute_shell`/
`read_file` como función pública — verificado estáticamente sobre el propio código fuente del
motor por `test_rca_manual_remediation_not_executed`, no sólo sobre su output. Toda recomendación
tiene `execution_status` fijo `"NOT_EXECUTED"` (default de dataclass, nunca parametrizable).

## Path/output safety

`cli.py#_validate_output_path()` valida, cuando se declara `--out-dir`, que toda ruta de salida
(`--out`/`--markdown`/`--manifest`) resuelva estrictamente dentro de ese directorio — un intento de
escape vía `..` se rechaza con exit no-cero antes de escribir nada
(`test_rca_cli_e2e_portable_paths`, incluye un caso con espacios en el path del directorio de
salida). `cli.py#_load_json()` aplica un límite de tamaño (`MAX_FIXTURE_BYTES = 5_000_000`) al
fixture de entrada.

## Mutation testing control

`test_rca_mutation_testing_control.sh`: copia `rca_engine/rules/default_rules.json` a un directorio
temporal, altera deliberadamente `RULE-OS-PROCESS-LIMIT-001` (`min_independent_sources: 999`,
umbral de `nproc_utilization_percent` a `999.0` — un defecto de causalidad inequívoco) y re-ejecuta
el mismo fixture que normalmente produce `CONFIRMED`. El resultado mutado nunca vuelve a ser
`CONFIRMED` (`PROBABLE` en la ejecución de referencia), demostrando que la suite es sensible a un
defecto real, no sólo que "algo se ejecutó". La mutación existe únicamente en el directorio
temporal (borrado por `trap ... EXIT`) — el archivo real `rca_engine/rules/default_rules.json`
nunca se toca, verificado al final del mismo test.

## New executable tests

20 tests nuevos bajo `tests/test_rca_*.sh` (19 exactamente nombrados por el prompt de hardening +
1 control de mutation testing), todos ejecutando `rca_engine.cli` real contra fixtures sintéticos
en `tests/fixtures/rca_engine/` (12 fixtures nuevos) — ninguno busca texto en Markdown como
sustituto de validar el resultado generado. Lista completa:

```text
test_rca_e2e_confirmed_with_causal_evidence.sh
test_rca_e2e_inconclusive_missing_evidence.sh
test_rca_critical_contradiction_blocks_confirmation.sh
test_rca_temporal_proximity_not_causation.sh
test_rca_mitigation_not_root_cause.sh
test_rca_symptom_not_root_cause.sh
test_rca_competing_hypotheses_remain_inconclusive.sh
test_rca_timestamp_timezone_normalization.sh
test_rca_ambiguous_timestamp_or_clock_skew.sh
test_rca_event_order_and_dedup_preserves_provenance.sh
test_rca_missing_or_broken_evidence_ref.sh
test_rca_json_markdown_consistency.sh
test_rca_manifest_traceability.sh
test_rca_reproducibility_same_input.sh
test_rca_invalid_input_fails_nonzero.sh
test_rca_no_secrets_in_outputs_or_logs.sh
test_rca_manual_remediation_not_executed.sh
test_rca_cross_domain_evidence_reuse.sh
test_rca_cli_e2e_portable_paths.sh
test_rca_mutation_testing_control.sh
```

Además: `tests/test_capability_matrix_schema.sh` extendido (18→19 dominios, fix real detectado y
corregido durante el gate final de la Fase 11 declarativa, no parte de este hardening pero
verificado de nuevo aquí).

## Capability differentiation (IMPLEMENTED_AND_TESTED vs DOCUMENTED_ONLY)

| Capacidad | Estado antes de este hardening | Estado después |
|---|---|---|
| Intake/schema validation | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`intake.py`) |
| Timeline UTC/clock-skew/dedup | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`timeline.py`) |
| Motor de hipótesis/contradicciones | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`hypothesis.py`, `rules.py`) |
| Root Cause Model / gates de confirmación | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`causality.py`) |
| Evidence manifest / completeness gate | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`intake.py`, `causality.py`) |
| Recomendaciones manuales (NOT_EXECUTED) | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`causality.py`) |
| Reporte JSON/Markdown/manifest | DOCUMENTED_ONLY | **IMPLEMENTED_AND_TESTED** (`report.py`, `cli.py`) |
| 9 skills de correlación cross-domain (evidencia real de cada especialista) | DOCUMENTED_ONLY | **PARTIALLY_SUPPORTED** — el motor consume evidencia ya normalizada por dominio (campo `domain` del fixture), pero no re-implementa los parsers/collectors certificados de cada especialista (Fase 2-10); eso permanece DOCUMENTED_ONLY/CONTRACT_ONLY, correctamente, por diseño (nunca duplicar collectors) |
| Playbooks (RAC eviction, listener, DG lag, FRA, RMAN, memory pressure) | DOCUMENTED_ONLY | DOCUMENTED_ONLY — el motor demuestra el mecanismo de matching de reglas genérico (6 reglas reales cubren 5 de los 6 escenarios de playbook), pero no hay una regla dedicada por cada uno de los 6 playbooks todavía — **NOT_CERTIFIED** como cobertura completa de playbook, ver Known limitations |
| `/diagnose incident`, `/rca`, `/healthcheck incident` (orquestación de agente vivo) | CONTRACT_ONLY | CONTRACT_ONLY/NOT_RUNTIME_CERTIFIED — sin cambio, depende del MCP Gateway (fase posterior) |

## Targeted tests: passed / failed / skipped

Ver la sección **Salida final obligatoria** de este mismo hardening (cerrada tras la ejecución
real) para los números verificados de esta corrida — 20/20 `test_rca_*.sh` más el resto del
targeted batch (`test_incident_*.sh`, safety, capability-matrix schema/registry).

## Full regression: passed / failed / skipped / timeout / not run

Ver **Salida final obligatoria** — capturada con `tests/run-all.sh`, exit code y RESUMEN final
del propio runner, reconciliación triple-independiente (mismo procedimiento que el gate final de
la Fase 11 declarativa).

## Security validation

READ-ONLY ALWAYS preservado: `rca_engine/` no importa `subprocess`, no llama `os.system`, no
define `execute_sql`/`execute_shell`/`read_file`, nunca conecta a Oracle/OS/red — opera
exclusivamente sobre fixtures JSON locales. Toda recomendación es texto con
`execution_status: "NOT_EXECUTED"` fijo. Sanitización verificada con 4 canarios sintéticos
distintos (password/secret/private-key/hash) — ninguno sobrevive en JSON, Markdown o stderr.

## Portability / git diff --check

`git diff --check` limpio sobre todos los archivos nuevos (`rca_engine/`, `tests/test_rca_*.sh`,
`tests/lib/rca_engine_e2e_helpers.sh`, `tests/fixtures/rca_engine/`) — sin trailing whitespace, sin
CRLF. Mismo patrón de rutas portables (`cd` + relativas) ya establecido para `capacity_engine`,
reproducido y verificado independientemente para `rca_engine` (`test_rca_cli_e2e_portable_paths`).

## Known limitations / NOT_CERTIFIED sources

- **6 reglas en el catálogo inicial** (`RULE-OS-PROCESS-LIMIT-001`,
  `RULE-OS-PROCESS-LIMIT-CGROUP-001`, `RULE-NET-LISTENER-HANG-001`,
  `RULE-STORAGE-LATENCY-CONTRADICTION-001`, `RULE-CAPACITY-TEMP-EXHAUSTION-001`,
  `RULE-RAC-INTERCONNECT-001`) — un MVP verificable, no una cobertura completa de los ~30+
  patrones de incidente descritos en las 34 skills declarativas. Ampliar el catálogo es un cambio
  gobernado vía `/change skill` (nuevas reglas), nunca lógica ad hoc.
- Los playbooks de Data Guard lag/RMAN/memory-pressure no tienen todavía una regla ejecutable
  dedicada en el catálogo inicial (aunque `RULE-CAPACITY-TEMP-EXHAUSTION-001` y el resto
  demuestran el mismo mecanismo) — **NOT_CERTIFIED** para esos 2 escenarios específicos hasta que
  se agreguen reglas dedicadas.
- El motor consume evidencia ya estructurada (`domain`, `event_type`, `signature`, `attributes`)
  — no reemplaza ni reimplementa los parsers de log reales de cada especialista (Fase 2-10);
  producir esa evidencia estructurada desde logs crudos reales permanece fuera de alcance de este
  hardening, por diseño (nunca duplicar collectors, `evidence_by_reference`).
- Fixtures sintéticos no equivalen a validación en producción — inferencia determinista basada en
  reglas no sustituye el juicio profesional de un DBA.
- Análisis lingüístico opcional de un LLM (si se integrara en una fase futura de orquestación en
  vivo) nunca es una dependencia para que los tests numéricos/estructurales de este motor pasen —
  el motor completo opera sin LLM, sin MCP y sin red, verificado en cada uno de los 20 tests.

## Referencias

`rca_engine/`, `tests/test_rca_*.sh`, `tests/lib/rca_engine_e2e_helpers.sh`,
`tests/fixtures/rca_engine/`, `docs/PHASE_11_INCIDENT_ANALYSIS_ROOT_CAUSE_AUTOMATION.md`,
`docs/INCIDENT_ROOT_CAUSE_MODEL.md`, `docs/INCIDENT_CAUSALITY_MODEL.md`,
`docs/INCIDENT_TIMELINE_MODEL.md`, `docs/INCIDENT_HYPOTHESIS_MODEL.md`,
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md` (mismo patrón aplicado).
