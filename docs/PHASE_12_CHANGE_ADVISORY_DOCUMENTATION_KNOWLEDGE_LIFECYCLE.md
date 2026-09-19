# PHASE 12 — Change Advisory, Documentation & Knowledge Lifecycle

Baseline: `v0.11.0-incident-rca` · Rama de trabajo: `phase/12-change-documentation-knowledge` · Tag propuesto (NO creado por el motor ni por el agente): `v0.12.0-change-documentation-knowledge`.

Este documento describe lo que Fase 12 **implementa y ejecuta** (paquete `change_documentation_knowledge/`), los contratos que consume de Phase 11, el modelo de amenazas, las limitaciones asumidas y cómo se prueba.
Invariantes: READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY · EVIDENCE FIRST · ANALYZE ONCE, DOCUMENT MANY · AGENTS FOR DOMAINS, SKILLS FOR TASKS · MULTI-AGENT DOES NOT MEAN MULTI-CONTEXT.

## 1. Alcance y lo que NO es

- Transforma diagnósticos/RCA **ya obtenidos** (salida real de `rca_engine`) en: (1) asesoría de cambio operativo `CHG` para ejecución humana externa, (2) documentos técnicos/ejecutivos reproducibles, (3) conocimiento versionado con ciclo de vida y aprobación humana externa, (4) gobierno de evolución del propio e-stack, (5) trazabilidad completa.
- **No** ejecuta nada: sin SQL/shell arbitrario, sin `subprocess`, sin red, sin Git, sin jobs en segundo plano, sin conexión a producción, sin credenciales. **No** aprueba ni publica: no existen banderas `approve`/`auto-publish`/`force-publish` ni aprobación por variable de entorno.
- **No** reconstruye RCA, forecasting, collectors, query registry, version resolver ni sanitización: importa la API pública de `rca_engine` (Phase 11).
- Fuera de alcance: Phase 13 (MCP Gateway/integración local), Phase 14 (production readiness), binarios DOCX/XLSX/PDF/PPTX (sin infraestructura probada).

## 2. Auditoría inicial y gap report (`EXISTING / REUSE / EXTEND / NEW / OUT_OF_SCOPE`)

| Clase | Ruta real | Decisión |
|---|---|---|
| EXISTING | `agents/change-advisor.md`, `agents/technical-documentation-manager.md`, `agents/knowledge-curator.md` (v1.0.0, planos, contenido real) | **EXTEND**: profundizados a `agents/<id>/AGENT.md + manifest/routing/context-policy/collaboration/output-schema + tests/README + CHANGELOG` (v2.0.0), mismo patrón que Fases 8-11; los planos se eliminan; `agents/REGISTRY.md` y referencias actualizadas. Sin agentes duplicados; orquestador intacto (18/18). |
| EXISTING | `skills/change/gap-analysis.md`, `skills/documentation/healthcheck-report.md`, registro de 12 skills `change/*` y 24 `documentation/*` (mayoría `registered`) | **REUSE/EXTEND**: `documentation/assessment-report` y `documentation/executive-summary` (ya `registered`) se materializan; 6 `change/*` y 3 `documentation/*` nuevos; dominio `knowledge` nuevo (7). |
| EXISTING | `.claude/commands/{change,document,recommend,incident,rca}.md`, `workflows/{change,document,recommend,rca,incident}.md` | **EXTEND** (sección Fase 12 añadida; contrato de gates intacto). |
| EXISTING | `EVOLUTION.md` (flujo DETECT GAP…PROMOTE), `docs/CONTRACTS.md`, `config/capability-matrix.yaml` (`documentation`, `change`) | **REUSE/EXTEND** (secciones/notas Fase 12; sin filas de dominio nuevas). |
| EXISTING | `rca_engine/` (RcaResult JSON, `sanitize`, `tokenization`, `rules`, `common`, `cli`) | **REUSE** por import de API pública. Contrato auditado en §3. |
| NEW | `change_documentation_knowledge/` (12 módulos, stdlib) | Motor ejecutable: adaptador de contrato, advisory, documentos, candidatos/lifecycle/KB, retrieval, CLI. |
| NEW | `.claude/commands/knowledge.md`, `workflows/knowledge.md` | `/knowledge` no existía. |
| NEW | `tests/p12/*.py` + 10 `tests/test_p12_*.sh` + `tests/fixtures/p12/` | Pruebas funcionales con `assert` sobre resultados reales. |
| OUT_OF_SCOPE | MCP Gateway (Fase 13), producción (Fase 14), binarios de documentos, firma/identidad real de aprobadores | No implementados; se declaran como limitaciones. |

Baseline reproducible: `v0.11.0-incident-rca` existe en Git (creado por el administrador); la rama `phase/12-change-documentation-knowledge` se creó desde `main` con el worktree limpio.
Los smoke tests de módulos tocados (`test_registries_consistency`, `test_skill_ids_*`, `test_document_traceability`, `test_no_promotion_without_human_review`, suite `test_rca_*`) se ejecutaron antes y después de los cambios (ver reporte final).

## 3. Auditoría del contrato Phase 11 y adaptador versionado

`rca_engine` emite `INC`, `EVD`, `HYP`, `RCA`, `REC` (contract_version `1.0.0`). **Incompatibilidades registradas** (resueltas en `schema.adapt_rca_result`, sin modificar `rca_engine`):

1. **No emite `FND-*`**: el adaptador deriva `FND-<incident>-<NNN>` 1:1 desde los eventos del timeline (`kind: timeline_event`, epistemic `observed`, `derived_by: p12_contract_adapter`) — no se inventa evidencia.
2. **No emite `CHG-*`**: los crea `change.py`, sólo para REC con `requires_change` y RCA `CONFIRMED`/`PROBABLE`.
3. **No emite factores contribuyentes ni impacto**: los documentos marcan esas secciones `NOT_PROVIDED_BY_SOURCE`.
4. **Texto de hipótesis/REC**: se reancla en el catálogo de reglas versionado (`rca_engine/rules/*.json`); un `rule_id` desconocido es `E_REFERENCE`; texto distinto del catálogo se reemplaza y se avisa (`HYPOTHESIS_TEXT_REANCHORED_ON_CATALOG`); una REC fuera del catálogo se sanea, se marca `UNCATALOGUED_SANITIZED` y se rechaza si contiene sintaxis de comando.
5. **Estados imposibles se rechazan, nunca se reparan**: `CONFIRMED` sin hipótesis confirmada, hipótesis `CONFIRMED` con contradicción crítica no resuelta, `CONFIRMED` con manifest `INCOMPLETE_REFS`, `INCONCLUSIVE` con hipótesis confirmada, referencias de evidencia inexistentes, REC con `execution_status` distinto de `NOT_EXECUTED`.
6. **Firmas**: una firma `CERTIFIED` se re-verifica con `rca_engine.sanitize.classify_signature`; una firma no reconocida sólo puede aparecer como token `SIG-…` (correlación conservada, texto original jamás).

Grafo lógico (no todo incidente llega a RCA confirmado, CHG o KB):

```text
INC → EVD → FND → HYP → RCA → REC → CHG
                           ↘ DOC → KB-CANDIDATE → KB-VERSION
```

Todo artefacto derivado lleva `schema_version`, id estable, `source_refs`, `generated_at_utc`, `generator_version`, `sanitization_status`, `review_status`, limitaciones y `content_digest` (SHA-256 del contenido **ya saneado**, excluyendo campos volátiles/de estado: aprobar o transicionar no cambia el digest al que la aprobación está atada, cualquier cambio de contenido sí).

## 4. Componentes ejecutables

| Módulo | Responsabilidad |
|---|---|
| `common.py` | enums (estados, gates, epistemología), tabla de transiciones, códigos de error con mensaje fijo, digest, reloj inyectable |
| `safety.py` | frontera de saneamiento: ids con gramática estrecha, `clean_text` (Phase 11 + una línea + esquemas bloqueados), guard de contenido ejecutable, marcadores de instrucciones, escape Markdown, lectura JSON estricta, confinamiento de rutas, escritura atómica sin sobrescritura, auto-auditoría de salidas |
| `schema.py` | validadores estrictos y adaptador Phase 11 → Phase 12 |
| `authorization.py` | verificación de registros de autorización humana **externos** |
| `change.py` | advisory operativo (`CHG`) y gobierno de evolución del e-stack |
| `documents.py` | fábrica: RCA técnico, resumen ejecutivo, advisory, assessment, post-incident review |
| `knowledge.py` | extracción de candidato, quality gate, duplicados/conflictos explicables |
| `kb_store.py` | KB local Markdown + JSON, versiones inmutables, manifest atómico, transiciones |
| `retrieval.py` | búsqueda local read-only, filtros, top-K, `NO_CERTIFIED_MATCH` |
| `cli.py` | `advise`, `document`, `kb-candidate`, `kb-add`, `kb-transition`, `kb-search`, `kb-status`, `kb-review-due` |

Ejemplo E2E (comandos reales; las rutas son ilustrativas):

```bash
python -m rca_engine.cli --fixture tests/fixtures/rca_engine/positive_confirmed.json --out rca.json
python -m change_documentation_knowledge.cli advise --rca-result rca.json --context tests/fixtures/p12/change_context_all_pass.json --generated-at 2026-03-11T16:00:00Z --output-dir out/advisory
python -m change_documentation_knowledge.cli document --kind rca --rca-result rca.json --generated-at 2026-03-11T16:00:00Z --output-dir out/rca
python -m change_documentation_knowledge.cli kb-candidate --rca-result rca.json --output-dir out/kbc
```

### 4.1 Contrato `CHG`

Campos: `change_id` (`CHG-<INC>-NNN`), `change_type` (`OPERATIONAL_MANUAL|ESTACK_DEVELOPMENT`), `status` (`DRAFT|REVIEW_REQUIRED|APPROVED_BY_HUMAN|REJECTED|SUPERSEDED`), `source_refs`, `evidence_refs`, `recommendation_refs`, `context`, `objective`, `scope`, `out_of_scope`, `assumptions`, `proposed_manual_steps` (texto), criterios de entrada/salida, ventana/responsable `TO_BE_DEFINED`, `impact`, `risk_factors` (dimensión/nivel/criterio/base; **sin score numérico**), `affected_components`, `blast_radius`, `service_dependencies`, `expected_benefit_as_hypothesis`, `reversibility`, `rollback_plan`, `validation_plan`, `stop_conditions`, `observability`, `open_questions`, `oracle_version`/`release_update`/`platform`/`topology` (`UNKNOWN` si no se declaran), `capability_gate`, `license_gate`, `privilege_gate`, `change_window_gate`, `execution_status: NOT_EXECUTED_BY_ESTACK` (inmutable) y `external_execution_report` (`HUMAN_REPORTED_UNVERIFIED`, nunca ejecución del sistema).

Reglas: gates `UNKNOWN` por defecto y bloqueantes; `UNKNOWN != NOT_APPLICABLE`; dominios con opciones licenciadas (Data Guard, Performance) rechazan `NOT_APPLICABLE` sin evidencia; un gate `FAIL`, `ROLLBACK_MISSING` o `VALIDATION_MISSING` => `BLOCKED`; un `CHG` bloqueado no puede aprobarse; `APPROVED_BY_HUMAN` sólo con registro externo que coincida con id + digest + versión y con `reviewer != proposer`.

### 4.2 Gobierno de evolución del e-stack (plano B)

`advise --mode estack` recibe la solicitud (etapas del workflow `/change` con su resultado, checks de compatibilidad, proponente) y **sólo informa**: `IN_PROGRESS`, `RETURNED_TO_PROPOSAL` (falla SECURITY/REGRESSION), `PENDING_HUMAN_REVIEW`, `BLOCKED`. Etapas PASS sólo como prefijo contiguo; `PROMOTE` jamás PASS; compatibilidad `UNKNOWN` bloquea; `promote_status: HUMAN_ACTION_REQUIRED` siempre.

### 4.3 Fábrica de documentos

Contrato: `document_id`, `document_type`, `audience`, `schema_version`, `incident_id`/`change_id`/`assessment_id`, `source_refs`, `generated_at_utc`, `content_status` (`COMPLETE|PARTIAL`), `review_status`, `redaction_profile`, `generator_version`, `limitations`, `warnings`, `sections[]` (estado `PRESENT|NOT_PROVIDED_BY_SOURCE|MISSING`, ítems con refs y etiqueta epistemológica). Orden estable, valores en línea única, Markdown/HTML escapados, límite de tamaño (512 KB por artefacto, 2000 ítems), UTF-8. Reporte técnico y resumen ejecutivo comparten `root_cause_state`. No se inventan métricas (MTTR/SLA) ni impacto.

### 4.4 Ciclo de vida del conocimiento

```text
CANDIDATE → DRAFT → PENDING_HUMAN_REVIEW → APPROVED_BY_HUMAN → PUBLISHED
                                  ↘ REJECTED
PUBLISHED → REVIEW_DUE → DEPRECATED → RETIRED
PUBLISHED → SUPERSEDED (nueva versión aprobada)
```

- Candidato: sólo un RCA `CONFIRMED` puede llegar a revisión; los demás producen `REJECTED` con `RCA_NOT_CONFIRMED` (bloqueo de publicación factual) y no tocan el KB (`kb-add` => `E_QUALITY_GATE`). Firmas no allowlisted se descartan del artículo. Alcance explícito (`UNKNOWN` jamás significa universal; un artículo `UNKNOWN` no coincide con un filtro de versión explícito).
- Aprobar/publicar/deprecar/superseder/retirar: registro de autorización humana **externo** (`authorization_id`, `artifact_id`, `decision`, `reviewer_id` tokenizado, `decision_at_utc`, `artifact_digest`, `version`, `review_notes_sanitized`) que debe coincidir con el digest y versión **vigentes**; una aprobación de la versión N es inválida para N+1; id de autorización de un solo uso y cronología monotónica; sin autoaprobación.
- Duplicados/conflictos: claves normalizadas seguras (familia, código certificado, regla, versión/RU/plataforma/arquitectura/licencia), sin embeddings ni servicios externos; resultado explicable `NEW|DUPLICATE|SCOPE_DIFFERENCE|CONFLICT|SUPERSESSION_PROPOSED`; diferencias de alcance jamás se fusionan; un conflicto bloquea PENDING_HUMAN_REVIEW/APPROVED/PUBLISHED.
- KB local: `articles/<KB-id>/v<N>.json|md` inmutables (sin sobrescritura, digest verificado en cada lectura => `E_KB_INTEGRITY`), `manifest.json` con reemplazo atómico e historial append-only. Revisión vencida = metadato + consulta read-only; sin cron ni jobs.
- Retrieval: filtros dominio/versión/código/tipo/arquitectura/licencia/fecha, top-K ≤ 20, sólo PUBLISHED/REVIEW_DUE como guía vigente; DRAFT/DEPRECATED etiquetados si se piden; RETIRED/REJECTED nunca; sin coincidencias => `NO_CERTIFIED_MATCH`; la consulta es dato (no ruta/regex/SQL) y no se refleja; el resultado advierte que el KB no reemplaza evidencia actual.

## 5. Modelo de amenazas y controles

Amenaza: evidencia/candidato/nota maliciosos con instrucciones para el agente, secretos en `title`, `summary`, `signature`, ids, `attributes` anidados, `review_notes`, filenames, enlaces Markdown, frontmatter YAML, errores o rutas. Todo es **dato no confiable, nunca instrucción**.

| Control | Implementación |
|---|---|
| Validar esquema antes de construir salidas | `schema.py`/`change.parse_change_context`/`documents.parse_*` estrictos; claves desconocidas => fallo cerrado (input propio) o descarte con warning (RCA) |
| Sanitizar antes de Markdown/JSON/manifest/índice/errores | `safety.clean_text` (Phase 11 `sanitize_text`), ids con gramática estrecha (INC/EVD/REV), tokens `TGT-/SRC-/SIG-` de Phase 11 |
| Firmas | sólo allowlist Phase 11; desconocidas => token; re-verificación de `CERTIFIED` |
| Errores | mensajes **fijos** por código (`E_*`), jamás construidos desde la entrada; `argparse` sobreescrito; sin traceback |
| Escape | Markdown/HTML/`file:`/`javascript:`/URLs; una sola línea por valor (no hay frontmatter/encabezado inyectable) |
| Inyección de instrucciones | marcadores detectados y marcados (`INSTRUCTION_LIKE_TEXT_TREATED_AS_DATA`); jamás cambian estados (tests) |
| Contenido ejecutable | guard de sintaxis de comando (`sudo`, `srvctl`, `ALTER SYSTEM`, DDL/DML…) => `E_UNSAFE_CONTENT` |
| Rutas | `confine`: sin `..`, absolutas ni symlinks; manifest KB con ids/versiones validados por regex |
| Directorios de trabajo | `assert_dev_workdir`: los artefactos derivados y el KB de desarrollo nunca se escriben en directorios gestionados del repositorio (`agents/`, `skills/`, `knowledge/`, `config/`, `docs/`, …) ni artefactos derivados dentro de una raíz de KB; probado incluso con *junctions* de Windows (la contención se comprueba sobre la ruta resuelta) |
| Salidas | `audit_strings`/`audit_rendered` (patrones estructurados de Phase 11) sobre TODO artefacto antes de escribir; manifest de artefactos sin rutas internas |
| Fail closed | si `rca_engine.sanitize` no carga => `E_SANITIZATION`; escritura atómica, sin sobrescritura, sin archivos parciales |

## 6. Limitaciones y riesgos residuales (declarados)

1. **Identidad de aprobadores no verificable**: no hay autenticación ni firma. Un registro de autorización local es una declaración estructural (`STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`), no prueba de identidad ni de autorización externa. PUBLISHED debe ser una acción manual verificable en el repositorio bajo revisión. No se proclama RBAC ni aprobaciones criptográficas.
2. La sanitización de Phase 11 es heurística y sesgada a sobre-redactar; el texto de catálogo confiable se usa literal para no destruirlo. La auto-auditoría usa los patrones estructurados de Phase 11 (privados en `rca_engine.sanitize`, importados sin copiarlos).
3. Guía de dominio (impacto/rollback) es **genérica** y no reemplaza un plan específico del sitio; se etiqueta como tal.
4. `FND` es una derivación (adaptador), no una salida nativa de `rca_engine`.
5. El KB es un directorio local de desarrollo; no hay concurrencia multi-escritor ni bloqueo entre procesos.
6. Sin binarios (DOCX/XLSX/PDF/PPTX).
7. `/change`, `/document`, `/knowledge` describen orquestación de un runtime de agente vivo (`CONTRACT_ONLY`) hasta el MCP Gateway; el CLI es el único camino ejecutable (`LOCAL_RUNTIME_TESTED`).

## 7. Pruebas (funcionales, sobre resultados reales)

| Archivo | Cobertura |
|---|---|
| `tests/test_p12_contract_adapter.sh` | adaptador con salidas reales de Phase 11 + entradas forjadas/hostiles |
| `tests/test_p12_change_advisory.sh` | CHG coherente, gates, RCA no confirmado, riesgos sin score, aprobación externa/digest/auto-aprobación, gobierno plano B |
| `tests/test_p12_documentation_factory.sh` | 5 tipos de documento, mismo estado de causa, PARTIAL, timeline UTC, contradicciones, sin métricas inventadas, escape/tamaño |
| `tests/test_p12_knowledge_lifecycle.sh` | candidato, REJECTED por RCA no confirmado, transiciones legales/ilegales, autorización atada al digest/versión, conflicto/duplicado/alcance, supersesión, retrieval, integridad |
| `tests/test_p12_security_threat_model.sh` | marcadores sintéticos en TODOS los artefactos/STDOUT/STDERR, errores sin eco, inyección, traversal/symlink, banderas prohibidas, sin subprocess/red/env/git (AST), sanitizador ausente => fail closed |
| `tests/test_p12_cross_domain.sh` | RAC, ASM, Data Guard, Multitenant, RMAN, Network, OS, Security, Capacity; sin 19c universal; sin licencias por defecto; forecast ≠ causa pasada |
| `tests/test_p12_phase11_integration.sh` | `rca_engine.cli` real → `advise`/`document`/`kb-*`; cadena positiva hasta KB publicado con registros externos sintéticos y cadena negativa inconclusa → bloqueo KB |
| `tests/test_p12_harness_isolation.sh` | aislamiento del arnés: cada módulo `tests/p12/check_*.py` ejecuta exactamente los casos que define (sin efectos colaterales de import) y los wrappers transmiten su salida en vivo, sin variable de shell; regresión del cierre de validación de seguridad |
| `tests/test_p12_mutation_controls.sh` | control de mutation testing: se desactivan en runtime 8 defensas (binding de digest, guard ejecutable, gates UNKNOWN, allowlist de firmas, exclusión de RETIRED, tabla de transiciones, saneamiento de notas, auto-aprobación) y el check que las protege DEBE fallar |
| tests declarativos (`tests/test_p12_agents_skills_registry.sh`) | 3 agentes con estructura completa, 18 skills, registros, workflow/comando `/knowledge`, sin agentes duplicados, sin ciclos de delegación |

Los registros de autorización usados en las pruebas se construyen **fuera del motor** (`tests/p12/harness.make_auth`) a partir del digest impreso por el motor y son datos sintéticos de prueba (`REV-TESTREV…`): verifican que el motor acepta un registro que coincide y rechaza los que no; no representan aprobación real alguna.

## 8. Decisiones humanas pendientes

Revisión de este cambio, y — sólo si corresponde — `git commit`/merge/tag `v0.12.0-change-documentation-knowledge` manuales. El motor y el agente no crean tags, merges, pushes ni publican conocimiento.
