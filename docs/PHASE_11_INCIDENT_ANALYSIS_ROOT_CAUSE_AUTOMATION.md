# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION

Documento de cierre de Fase 11. Construye sobre baseline `v0.10.0-capacity-forecasting` (Fase 10 —
Capacity Management & Forecasting). No reconstruye ninguna fase previa — el dominio `incident` era
un placeholder Foundation (8 skill_ids `registered`, 1 `active`: `incident/root-cause-analysis.md`)
que esta fase materializa por completo, fusionando el contenido real de Foundation en la nueva
estructura, mismo patrón de deepening que Security (Fase 8), OS Platform (Fase 9) y Capacity
(Fase 10).

## Objetivo

Construir un dominio transversal de Incident Intake/Triage/Timeline/Hypothesis/Root-Cause/Impact/
Playbook/Postmortem sobre Oracle Database y su infraestructura de hospedaje, con un único agente
`incident-root-cause-analyst` (nunca dividido por capability), estricta separación
SYMPTOM/CONDITION/CONTRIBUTING_FACTOR/ROOT_CAUSE/IMPACT, un Root Cause Model que exige
confirmación basada en evidencia (nunca proximidad temporal sola), correlación cross-domain que
reutiliza por referencia la evidencia de los 10 especialistas de dominio ya certificados (nunca
duplica collectors), playbooks de incidente read-only (diagnose-and-recommend only), disciplina de
remediación manual incluso en escenarios de emergencia, revisión post-incidente y lecciones
aprendidas — cerrando el dominio con el mismo rigor que Fases 2-10.

## Agente principal

`incident-root-cause-analyst` (`agents/incident-root-cause-analyst/`, v2.0.0) — `supersedes`
`agents/incident-root-cause-analyst.md` (Foundation v1.0.0, manifest plano real, modelo RCA de seis
estados preservado íntegramente). `security_mode: READ_ONLY_ALWAYS`. `supported_architectures:
[standalone, rac, rac_one_node]`. 12 `forbidden_capabilities` explícitas (SQL/shell arbitrario,
mutación de Oracle/OS/red/storage/seguridad, ejecución de RMAN, matar sesiones/procesos, reiniciar/
relocalizar servicios, failover/switchover, cambio de parámetros, cambios de seguridad,
auto-cierre de tickets externos, duplicación de collectors, llamadas MCP no certificadas).
`output_contract.never_reports` codifica explícitamente las tres reglas centrales del dominio: no
`CONFIRMED_ROOT_CAUSE` sin evidencia suficiente, no proximidad temporal como prueba de causalidad,
no forecast de capacidad como causa de un evento ya ocurrido.

## Skills

34 skills `incident/*`, todos `active`, agrupados en 6 bloques:

- **Intake/Triage (4)**: `incident/intake`, `incident/classification`, `incident/severity-awareness`,
  `incident/scope-identification`.
- **Timeline/Evidence (4)**: `incident/timeline`, `incident/evidence-plan`,
  `incident/evidence-correlation` (v2.0.0, materializa el `registered` de Foundation),
  `incident/symptom-clustering`.
- **Hypothesis/Causality/Root-Cause (5)**: `incident/hypothesis-generation`,
  `incident/hypothesis-testing`, `incident/contradiction-analysis`, `incident/root-cause` (v2.0.0,
  absorbe `skills/incident/root-cause-analysis.md` de Foundation), `incident/contributing-factors`.
- **Impact/Recovery/Correlación general (7)**: `incident/impact-analysis`, `incident/blast-radius`
  (v2.0.0, materializa el `registered` de Foundation), `incident/recovery-status`,
  `incident/recurrence-awareness`, `incident/known-error-correlation`,
  `incident/change-correlation`, `incident/capacity-correlation`.
- **Correlación cross-domain (9)**: `incident/performance-correlation`, `incident/rac-correlation`,
  `incident/dataguard-correlation`, `incident/asm-storage-correlation`,
  `incident/network-correlation`, `incident/os-correlation`, `incident/security-correlation`,
  `incident/rman-correlation`, `incident/multitenant-correlation` — cada una consume
  `evidence_refs` del especialista de dominio correspondiente (Fase 2-10) por referencia, nunca
  duplica su collector.
- **Output/Process (5)**: `incident/manual-remediation-plan`, `incident/post-incident-review`,
  `incident/lessons-learned` (v2.0.0, materializa el rol implícito de Foundation),
  `incident/incident-report`, `incident/rca-report`.

## Root Cause Model

Extiende `docs/CONTRACTS.md#rca-model` (preservado verbatim desde Foundation:
`FACT → OBSERVATION → HYPOTHESIS → PROBABLE_CAUSE → CONFIRMED_ROOT_CAUSE`, `UNDETERMINED` como
estado terminal legítimo) con `completeness` (`CONFIRMED|PROBABLE|INCONCLUSIVE|
INSUFFICIENT_EVIDENCE`), `causal_chain` explícito (nunca un salto directo alerta→causa), soporte
para múltiples causas raíz simultáneas, y `confidence` (`HIGH|MEDIUM|LOW|INSUFFICIENT`) con score
opcional siempre acompañado de explicación. `CONFIRMED_ROOT_CAUSE` requiere dos fuentes de
evidencia independientes o prueba temporal inequívoca — regla estructural, nunca relajada. Ver
`docs/INCIDENT_ROOT_CAUSE_MODEL.md`.

## Causality Model

`CORRELATION IS NOT CAUSATION` como principio arquitectónico central: `CHANGE_CORRELATED`
(coincidencia temporal) nunca se colapsa con `CHANGE_CAUSED` (evidencia causal directa); una
acción de recuperación exitosa (ej. "restart listener restored service") nunca prueba por sí
misma la causa raíz; un forecast de capacidad futuro nunca se usa como prueba de causa de un
incidente ya ocurrido sin evidencia histórica/actual directa; `ORA-12537` y símbolos equivalentes
son siempre SYMPTOM, nunca root cause automático. Ver `docs/INCIDENT_CAUSALITY_MODEL.md`.

## Hypothesis Model

Ciclo de vida `OPEN → SUPPORTED → CONFIRMED` / `OPEN → SUPPORTED → WEAKENED → REJECTED` /
`OPEN → INSUFFICIENT_EVIDENCE`. `incident/hypothesis-generation` aplica un límite Top-N
configurable (`incident.max_hypotheses`, Target Profile). `incident/contradiction-analysis`
implementa el ejemplo verbatim del prompt (contradicción de storage latency). Hipótesis
`REJECTED`/`WEAKENED` son resultados legítimos, nunca ocultados del reporte final —
`incident/rca-report` las lista siempre. Ver `docs/INCIDENT_HYPOTHESIS_MODEL.md`.

## Timeline Model

Normalización a UTC con `source_timestamp` siempre preservado; 6 tipos de evento
(`SYMPTOM_OBSERVED`, `ALERT_TRIGGERED`, `CONFIG_CHANGE`, `CAPACITY_EVENT`, `RECOVERY`,
`INVESTIGATION_STEP`); deduplicación de eventos multi-fuente sin perder la referencia a cada
fuente original; clock skew detectado y marcado vía `TIMELINE_CONFIDENCE_DEGRADED`, nunca
"corregido" silenciosamente. Ver `docs/INCIDENT_TIMELINE_MODEL.md`.

## Impact / Blast Radius / Recovery Status

Campos de impacto (`users_affected`, `data_loss`, etc.) nunca inventados sin evidencia directa —
`null` explícito por defecto. Blast radius clasificado al nivel más específico soportado por
evidencia entre 11 niveles (`INSTANCE|DATABASE|PDB|RAC_NODE|RAC_CLUSTER|HOST|SERVICE|
DATAGUARD_CONFIG|STORAGE|NETWORK_SEGMENT|MULTIPLE_SYSTEMS|UNKNOWN`), `UNKNOWN` nunca sobreestimado.
Recovery status (`RECOVERED|PARTIALLY_RECOVERED|STABLE_WITH_RISK|NOT_RECOVERED|UNKNOWN`) con
modelo `MITIGATION|TEMPORARY_FIX|PERMANENT_FIX|WORKAROUND` separado de la atribución causal. Ver
`docs/INCIDENT_IMPACT_MODEL.md`.

## Playbooks

Read-only, diagnose-and-recommend only. Cobertura mínima: RAC node eviction, listener/TNS failure,
Data Guard lag/gap, FRA pressure, RMAN backup failure, OS memory pressure — cada uno vinculado al
skill de correlación cross-domain correspondiente. Ver `docs/INCIDENT_PLAYBOOK_MODEL.md`.

## Manual Remediation / Post-Incident Review / Lessons Learned

`incident/manual-remediation-plan` produce texto/procedimiento exclusivamente, incluso para
acciones de emergencia (restart, relocate, kill session, failover, extender filesystem) —
`execution_status: NOT_EXECUTED` sin excepción, mismo patrón que `change-advisor`/
`capacity/manual-capacity-plan`/`os/manual-hardening-plan`/`rman/manual-recovery-plan`/
`security/manual-remediation-plan`. `incident/post-incident-review` es blameless por diseño — foco
sistémico, nunca culpa individual. `incident/lessons-learned` (v2.0.0) propone candidatos de
knowledge base vía el flujo `/change` gobernado, nunca escribe automáticamente en
`knowledge/errors/`. Ver `docs/INCIDENT_MANUAL_REMEDIATION_MODEL.md`,
`docs/INCIDENT_POSTMORTEM_MODEL.md`.

## Local computation / Token optimization / Evidence policy

Pipeline `raw evidence → local parser → event extraction → dedup → timeline summary → top
hypotheses → LLM reasoning` — archivos de log completos nunca se envían al modelo
(`no_raw_logs_to_model`). Cadena de identificadores `INC-YYYYMMDD-NNN → EVD-... → FND-... →
HYP-... → RCA-... → REC-... → CHG-...`, misma disciplina de trazabilidad que el resto del e-stack.
Ver `docs/INCIDENT_EVIDENCE_MODEL.md`.

## Target Profile

Bloque `incident:` agregado a `docs/TARGET_PROFILE.md` (`schema_version` 2.7.0 → 2.8.0):
`severity_model`, `evidence_window`, `change_correlation`, `max_hypotheses`,
`confidence_thresholds`, `recurrence_window_days`, `timeline_granularity`, `required_domains` —
todos configurables, ninguno con default universal inventado; `required_domains` nunca reduce el
scope mínimo de seguridad, sólo puede ampliarlo.

## Workflows

`workflows/incident.md` (v1.0.0 → v2.0.0) y `workflows/rca.md` (v1.0.0 → v2.0.0) actualizados a la
secuencia completa de 34 skills. `workflows/healthcheck.md` (v2.0.0 → v2.1.0) agrega
`/healthcheck incident`. `workflows/diagnose.md` (v1.1.0 → v1.2.0) agrega routing
`/diagnose incident`, activando el flujo completo de `workflows/incident.md`/`workflows/rca.md`
según si el incidente está activo o ya cerrado.

## Fixtures / Tests

~32 fixtures bajo `tests/fixtures/incident/{oracle,rac,dataguard,rman,os,capacity,security}/` (5
ORA/TNS, 5 RAC, 5 Data Guard, 4 RMAN, 6 OS, 3 Capacity, 4 Security). 63 tests exactamente
nombrados, verificados individualmente: Intake (5), Timeline (5), Hypotheses (5), Root Cause (5),
Causality (4), Impact (3), Cross-domain (9), Playbooks (6), Safety (13 — 6 extendidos sin
sobrescribir: `test_no_arbitrary_sql.sh`, `test_no_arbitrary_shell.sh`,
`test_no_parameter_change.sh`, `test_no_network_change.sh`, `test_no_failover_execution.sh`,
`test_no_switchover_execution.sh`; 7 nuevos), Traceability (4), Documentation (4).

## Capability Matrix

Fila `incident` agregada a `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md`:
`SUPPORTED` 10g-23ai, `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (mismo criterio que Data
Guard/Multitenant/RMAN/Security/OS/Capacity). Correlación cross-domain hereda el boundary de
versión/arquitectura del especialista referenciado.

## Documentación

12 documentos nuevos: este documento de cierre, `docs/INCIDENT_INTAKE_MODEL.md`,
`docs/INCIDENT_EVIDENCE_MODEL.md`, `docs/INCIDENT_TIMELINE_MODEL.md`,
`docs/INCIDENT_HYPOTHESIS_MODEL.md`, `docs/INCIDENT_CAUSALITY_MODEL.md`,
`docs/INCIDENT_ROOT_CAUSE_MODEL.md`, `docs/INCIDENT_IMPACT_MODEL.md`,
`docs/INCIDENT_PLAYBOOK_MODEL.md`, `docs/INCIDENT_MANUAL_REMEDIATION_MODEL.md`,
`docs/INCIDENT_POSTMORTEM_MODEL.md`, `docs/INCIDENT_READONLY_SECURITY_MODEL.md`. `README.md`,
`ARCHITECTURE.md` (principio #33), `SECURITY.md`, `CHANGELOG.md`, `skills/REGISTRY.md` (301 → 334
skills activos), `agents/REGISTRY.md` actualizados.

## Seguridad

`security_mode: READ_ONLY_ALWAYS`. HUMAN-EXECUTED REMEDIATION ONLY incluso en escenarios de
emergencia — ninguna excepción. NO ROOT, NO SUDO, NO ARBITRARY SQL, NO ARBITRARY SHELL, NO
AUTOMATIC SERVICE/DATABASE RESTART, NO PARAMETER CHANGE, NO FAILOVER/SWITCHOVER EXECUTION, NO
SESSION/PROCESS KILL, NO STORAGE/NETWORK/SECURITY CHANGE, NO RMAN EXECUTION (ni siquiera durante
investigación de incidente), NO INCIDENT ACTION MAY MUTATE PROD — todas verificadas por los 13
tests de safety. Ver `docs/INCIDENT_READONLY_SECURITY_MODEL.md`, `SECURITY.md`.

## Known limitations

- `incident/multitenant-correlation` no tiene un test exactamente nombrado dedicado en la lista de
  63 (no listado explícitamente en la sección de cross-domain del prompt de Fase 11) — cubierto
  transversalmente por `test_incident_root_cause.sh` y el resto de tests de root cause/hipótesis.
- `incident/recurrence-awareness`/`incident/known-error-correlation` no tienen test exactamente
  nombrado dedicado — cubiertos transversalmente por los tests de root cause y playbooks, mismo
  criterio documentado explícitamente en sus propios `SKILL.md#tests`.
- Orquestación de agente vivo (`/incident`, `/rca`, `/healthcheck incident` end-to-end) permanece
  `CONTRACT_ONLY`/`NOT_RUNTIME_CERTIFIED` — depende del MCP Gateway, fase posterior; consistente
  con el mismo estado que el resto de agentes del e-stack (Fase 2-10).
- No existe un motor ejecutable equivalente a `capacity_engine/` para el dominio `incident` — a
  diferencia de Fase 10, este dominio es declarativo (contratos de agente/skill), sin lógica
  numérica que justifique una implementación Python dedicada; la verificación de esta fase es
  estructural/de consistencia (grep-based contra `SKILL.md`/`manifest.yaml`/fixtures), mismo
  patrón que Fases 4-9.
