# CONTRACTS.md — Contratos definitivos

Estos son los contratos obligatorios de Fase 1. Ningún agente, skill, workflow o query puede existir sin satisfacer el contrato correspondiente. Los templates en `agents/_AGENT_CONTRACT_TEMPLATE.md`, `skills/_SKILL_CONTRACT_TEMPLATE.md`, `workflows/_WORKFLOW_CONTRACT_TEMPLATE.md` y `queries/_QUERY_CONTRACT_TEMPLATE.md` son la forma rellenable de lo que sigue.

---

## Agent Contract

Todo agente declara, en su manifest `agents/<id>.md`, frontmatter YAML + secciones Markdown con:

```yaml
id: string                     # kebab-case, único
role: string                   # una línea
mission: string                # 2-4 líneas
version: semver
status: candidate|under_review|active|deprecated|retired
```

Secciones obligatorias (Markdown, en este orden):

1. **Responsibilities** — lista cerrada de lo que el agente SÍ hace.
2. **Explicit boundaries** — lista cerrada de lo que el agente NO hace, incluyendo remisión explícita a otro agente cuando corresponda.
3. **Supported versions/platforms/architectures** — Oracle 10g–23ai (marcar cuáles aplican), OS soportados, Standalone/RAC/RAC One Node, NON-CDB/CDB/PDB, ASM/Filesystem, Primary/Physical Standby/Active Data Guard. Si algo no aplica al agente, se declara "N/A" explícitamente, nunca se omite.
4. **Allowed skills** — lista cerrada de `skills/<dominio>/<skill>` que el agente puede invocar. No puede invocar nada fuera de esta lista.
5. **Forbidden capabilities** — recordatorio explícito de READ-ONLY ALWAYS aplicado a este agente: qué operaciones de escritura están prohibidas específicamente en su dominio (ej. RAC: no `srvctl start/stop/modify`; Data Guard: no switchover/failover; RMAN: no restore/recover).
6. **Required input contract (Task Package)** — campos mínimos que este agente necesita recibir: `task_id, target_summary, question, relevant_evidence_refs, constraints, expected_output`, más cualquier campo específico del dominio.
7. **Output contract (Result Package)** — `findings, evidence_refs, hypotheses, confidence, recommendations, next_skill/agent (sólo si es necesario)`, más `capability_status` (sólo si alguna capacidad solicitada no pudo ejecutarse — ver `Capability Status Model` abajo) y schema específico del dominio si aplica.
8. **Evidence policy** — qué evidencia puede solicitar (referencia a queries certificadas de `queries/`), qué clasificación de sensibilidad espera recibir (post-sanitización), y que nunca solicita bind values ni datos de aplicación salvo excepción de política.
9. **Collaboration/delegation rules** — a qué otros agentes puede escalar o delegar, y bajo qué condición (ej. hallazgo de causa raíz cruzada → `incident-root-cause-analyst`; recomendación accionable → `change-advisor`).
10. **Context/token policy** — presupuesto aproximado de contexto por invocación, política de evidencia-por-referencia, prohibición de reenviar historial completo.
11. **Confidence rules** — cómo se expresa confianza (`FACT / OBSERVATION / HYPOTHESIS / PROBABLE_CAUSE / CONFIRMED_ROOT_CAUSE / UNDETERMINED`, ver `docs/CONTRACTS.md#rca-model` más abajo) y cuándo declara `UNDETERMINED` por falta de evidencia en vez de forzar una conclusión.
12. **Escalation rules** — cuándo debe detenerse y pedir al orquestador otro agente/skill o señalar al DBA que falta evidencia/acceso.
13. **Documentation obligations** — qué debe quedar registrado en `analysis/ANA-*` (findings.md, evidence.md, recommendations.md como mínimo).
14. **Security constraints** — reafirmación de identidad `ESTACK_DIAG_*`, prohibición de credenciales privilegiadas, prohibición de recibir/emitir secretos.
15. **Tests** — referencia a los casos en `tests/` que validan a este agente (contrato, seguridad, activación mínima).
16. **Evolution policy** — cómo se propone un cambio a este agente (`/change agent`), quién puede aprobarlo.

Ningún agente puede operar fuera de su contrato: si el orquestador pide algo fuera de `responsibilities`/`allowed_skills`, el agente debe rechazarlo y señalar el agente correcto o proponer `/change agent`.

**Materialización del contrato**: las 16 secciones anteriores viven, por defecto, en un único `agents/<id>.md` (o `agents/<id>/AGENT.md` para un agente profundizado por fase). Cuando la complejidad de un agente lo justifica, el contrato puede materializarse en archivos YAML estructurados independientes (`manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`) con `AGENT.md` reducido a documento narrativo que referencia, nunca duplica, esos campos — patrón introducido en Fase 3 Completion & Portability Hardening para `oracle-performance-analyst` (ver `docs/PHASE_3_COMPLETION_HARDENING.md#gap-3--agent-contract-materialization`). No es la convención por defecto para agentes nuevos; `agents/REGISTRY.md` siempre indica el path canónico real de cada agente.

---

## Skill Contract

Todo skill declara, en `skills/<dominio>/<skill>.md`, frontmatter YAML + secciones:

```yaml
name: string                       # kebab-case, único DENTRO del dominio
display_name: string               # nombre corto para UI/documentación — NUNCA usado como identificador
id: dominio/skill                  # ej. performance/wait-events — ver regla de canonicidad abajo
version: semver
domain: string
status: candidate|under_review|active|deprecated|retired
```

### Regla de identificador canónico (Foundation Hardening)

> `skill_id` must always be globally unique and domain-qualified.

- `id` es **siempre** `dominio/skill` (ej. `oracle/temp`, `performance/temp`, `capacity/temp`) — nunca un nombre corto suelto (`temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io`, ...). Nombres cortos como esos son ambiguos por diseño: existen legítimamente en múltiples dominios (`oracle/temp` ≠ `performance/temp` ≠ `capacity/temp`) y **nunca** pueden usarse solos como identificador operativo, en `Allowed skills` de un agente, en `Related skills`, ni en ninguna referencia cruzada.
- `display_name` (opcional) es el único lugar donde un nombre corto es válido — sólo para presentación (UI, títulos de reporte), nunca para lookup/enrutamiento.
- Todo `id` debe ser único **globalmente** en `skills/REGISTRY.md`, no sólo dentro de su dominio — el registro es el catalogo canónico de verdad y toda referencia (`Allowed skills` de un agente, `Skills` de un workflow, `Related skills` de otro skill) debe usar el `id` completo tal como aparece ahí.
- Toda referencia a un skill inexistente en `skills/REGISTRY.md` es una violación de contrato — ver `tests/test_no_ambiguous_skill_references.sh`.

Validado por `tests/test_skill_ids_are_globally_unique.sh`, `tests/test_skill_ids_are_domain_qualified.sh`, `tests/test_no_ambiguous_skill_references.sh`.

Secciones obligatorias:

1. **Purpose** — qué pregunta diagnóstica responde este skill, en 1-3 líneas.
2. **Supported Oracle versions** — lista explícita; si una versión tiene comportamiento distinto, se anota.
3. **Supported OS/platforms** — lista explícita o "todas" si es realmente agnóstico (raro).
4. **Supported architectures** — Standalone/RAC/RAC One Node, NON-CDB/CDB/PDB, ASM/Filesystem, Primary/Standby, según aplique.
5. **Prerequisites** — discovery previo requerido (ej. "requiere `oracle-discovery-analyst` haya confirmado versión y rol").
6. **Required evidence** — queries certificadas obligatorias de `queries/` (por `query_id`).
7. **Optional evidence** — queries certificadas que mejoran la confianza pero no son obligatorias.
8. **Read-only operations** — enumeración explícita de lo que este skill lee.
9. **Forbidden operations** — recordatorio explícito de que este skill no ejecuta nada; sólo lee y, cuando corresponde, genera texto de comando para ejecución humana.
10. **Decision logic** — cómo pasa de evidencia a hallazgo: umbrales, comparaciones, patrones reconocidos. Debe ser determinístico y auditable, no "usar criterio".
11. **Confidence model** — cómo asigna `FACT/OBSERVATION/HYPOTHESIS/PROBABLE_CAUSE/CONFIRMED_ROOT_CAUSE/UNDETERMINED` a cada hallazgo.
12. **Output schema** — estructura exacta del resultado (findings con evidence_refs, severidad, confidence).
13. **Related skills** — otros skills con los que se correlaciona típicamente.
14. **Escalation** — cuándo el skill debe indicar que se necesita otro skill/agente o más evidencia.
15. **Data sensitivity** — qué tan sensible es la evidencia que maneja (según `sanitizers/data-classification-policy.md`) y qué campos espera recibir ya enmascarados.
16. **Context budget** — tamaño aproximado de evidencia/tokens que este skill necesita, para que el orquestador dimensione el Task Package.
17. **Tests** — casos en `tests/` que validan este skill.
18. **Documentation requirements** — qué debe aportar a `findings.md`/`recommendations.md` del análisis.
19. **Evolution via `/change`** — cómo se propone una versión nueva del skill.

No se crean skills vacíos: todo skill activo en el registro (`status: active`) debe tener las 19 secciones rellenas con contenido real, no placeholders.

---

## Workflow Contract

Todo workflow declara, en `workflows/<nombre>.md`:

```yaml
name: string
version: semver
status: candidate|under_review|active|deprecated|retired
```

Secciones obligatorias:

1. **Trigger/intent** — qué comando(s) o intención del DBA activa este workflow.
2. **Prerequisites** — qué debe existir antes de correr (ej. target identificado, acceso read-only configurado).
3. **Discovery requirements** — qué discovery mínimo se exige antes de invocar especialistas (referencia a `oracle-discovery-analyst`).
4. **Minimum agents** — lista cerrada de agentes que **siempre** se activan para este workflow.
5. **Optional agents** — agentes que se activan sólo si el discovery o hallazgos tempranos lo justifican, con la condición explícita.
6. **Activation conditions** — reglas explícitas (si X entonces se activa agente/skill Y) que implementan "activar el mínimo número de agentes necesario".
7. **Skills** — skills mínimos invocados directamente por el workflow (fuera de los que cada agente decide internamente).
8. **Evidence required** — queries certificadas mínimas para completar el workflow.
9. **Stop conditions** — cuándo el workflow se detiene (evidencia insuficiente, target no accesible en modo read-only, ambigüedad de identidad del target).
10. **Confidence threshold** — confianza mínima para presentar una conclusión como `PROBABLE_CAUSE`/`CONFIRMED_ROOT_CAUSE`; por debajo, se reporta como `HYPOTHESIS`/`UNDETERMINED`.
11. **Escalation** — a qué workflow/agente se escala si el resultado excede el alcance (ej. `/healthcheck` que encuentra indicios de incidente activo escala a `/incident`).
12. **Documentation output** — qué archivos de `analysis/ANA-*` produce como mínimo.
13. **Token/context budget** — presupuesto total del workflow, suma acotada de los presupuestos de sus agentes/skills.
14. **Security constraints** — reafirmación read-only y de identidad aplicable al workflow completo.
15. **Gates** (Foundation Hardening) — bloque `gates:` evaluado **antes** de activar cualquier collector, en este orden fijo:

```yaml
gates:
  version:      # ¿la versión Oracle del target soporta este workflow/dominio? (config/capability-matrix.yaml)
  architecture: # ¿la arquitectura (RAC/Standalone, CDB/PDB, ASM/Filesystem, Primary/Standby) aplica?
  environment:  # ¿el target está en config/allowed-targets.local.yaml?
  license:      # ¿alguna capability requerida es LICENSE_RESTRICTED sin alternativa?
  privilege:    # ¿ESTACK_DIAGNOSTIC_ROLE alcanza para la evidencia requerida?
  security:     # ¿alguna query requerida está bloqueada por policies/forbidden-operations.md?
  cost:         # ¿alguna query requerida excede el cost_class permitido por policies/query-cost-policy.md para este workflow?
  evidence:     # ¿hay evidencia cacheada reutilizable, o hace falta recolectar?
```

Principio: **activar el mínimo número de agentes necesario.** Un workflow que activa un agente fuera de "Minimum agents" sin que se cumpla una "Activation condition" documentada es una violación de contrato. Los `gates` formalizan esto: si `version`/`architecture` ya descartan un agente (ej. `oracle-rac-analyst` sobre un target `instance_mode = single`), **no se activa en absoluto** — no se activa y luego se descubre incompatible (ver `docs/CONTRACTS.md#context-token-model`, pipeline DISCOVERY → CAPABILITY FILTER → AGENT FILTER → SKILL FILTER → CONTEXT PACKAGE). Un gate que falla produce un `capability_status` (ver `Capability Status Model` abajo), nunca un fallo silencioso.

---

## Query Contract v2 (Foundation Hardening)

> Breaking change respecto a v1 (Fase 1). Toda query certificada migró a este schema; ver `CHANGELOG.md`.

Toda entrada del catálogo certificado (`queries/<id>.md` y su fila en `queries/REGISTRY.md`) declara como mínimo:

```yaml
query_id:                    # estable, ej. Q-TBS-USAGE-001
version:                     # semver de la ENTRADA de catálogo (independiente del version del e-stack)

domain:                      # oracle|performance|rac|asm|dataguard|multitenant|rman|network|os|capacity
purpose:                     # una línea

supported_oracle_versions: []   # ej. [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: []                 # ej. [todas] o lista explícita
supported_architectures: []      # Standalone/RAC/RAC One Node según aplique

container_scope: NON_CDB_ONLY|CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NOT_APPLICABLE
database_role_scope: PRIMARY|STANDBY|ANY|NOT_APPLICABLE
open_mode_scope: []           # opcional (Compatibility Hardening, sección 19) — subconjunto de
                               # [READ WRITE, READ ONLY, MOUNTED, ANY]; se declara sólo cuando el
                               # resultado de la query es incorrecto/no representativo en algún
                               # open_mode que database_role_scope por sí solo no excluye — ver abajo

objects_accessed: []          # vistas/comandos exactos (ej. DBA_TABLESPACES, V$ASM_DISKGROUP)
privileges_required: []       # ej. [SELECT_CATALOG_ROLE] o vista concreta del ESTACK_DIAGNOSTIC_ROLE

risk_class: R0                # seguridad: ver nota abajo — NO confundir con cost_class
cost_class: LOW|MEDIUM|HIGH|BLOCKED   # impacto/costo de ejecución — ver policies/query-cost-policy.md

timeout_seconds:
max_rows:
max_output_bytes:

sensitivity:                  # LOW|MEDIUM|HIGH — ver sanitizers/data-classification-policy.md
sanitization_required: true   # casi siempre true; false sólo si el objeto no puede contener nada enmascarable

license_requirements: none    # "none" o lista de features potencialmente licenciadas (ver policies/licensing-awareness-policy.md)

execution_mode: READ_ONLY     # constante — el catálogo no admite otro valor

tests: []                     # referencia a tests/ que validan esta entrada
status: candidate|active|deprecated
```

### `container_scope`

`NON_CDB_ONLY` (sólo aplica fuera de multitenant) · `CDB_ROOT_ONLY` (sólo a nivel CDB$ROOT — la presencia de `CON_ID` en la vista nunca implica por sí sola que ejecutar desde otro contenedor sea seguro, ver `docs/CDB_PDB_QUERY_MODEL.md`) · `PDB_ONLY` (dentro de un PDB específico) · `ANY_CONTAINER` (válida en cualquiera de los tres) · `NOT_APPLICABLE` (la query no tiene relación con tenancy, ej. una query de OS).

**Nota de nomenclatura (Fase 6 — Multitenant)**: los valores `NON_CDB`/`CDB_ROOT`/`PDB` de versiones anteriores de este contrato se renombraron a `NON_CDB_ONLY`/`CDB_ROOT_ONLY`/`PDB_ONLY` para eliminar la ambigüedad entre "esta query sólo aplica en este contenedor" y una lectura más laxa de "este es el contenedor típico". Ningún query materializado antes de Fase 6 usaba los valores bareword (`CDB_ROOT`/`PDB`/`NON_CDB`) — el catálogo Oracle Core corrigió esos casos en Compatibility Hardening (Fase 2) hacia `ANY_CONTAINER`, así que el renombrado no requirió migrar ninguna query existente, sólo las 15 nuevas `queries/multitenant/*`.

### `database_role_scope`

`PRIMARY` (sólo válida contra un Primary) · `STANDBY` (sólo válida contra un Physical/Active Data Guard Standby) · `ANY` (válida en ambos) · `NOT_APPLICABLE` (no depende del rol, ej. identidad/OS).

### `open_mode_scope` (Compatibility Hardening)

Campo **opcional** — se declara únicamente cuando `database_role_scope` no basta para excluir un estado de apertura donde el resultado es incorrecto o no representativo (la mayoría de las queries de sólo-metadata/flags son válidas en cualquier `open_mode` y omiten este campo). Valores: `READ WRITE` · `READ ONLY` · `MOUNTED` · `ANY`. Ejemplo real: `Q-DBA-TBS-USAGE-001` sobre un target `MOUNTED` — `DBA_FREE_SPACE`/`DBA_DATA_FILES` no reflejan uso real de espacio mientras la base no está abierta; el agente que consume esa evidencia degrada `confidence: UNDETERMINED` en vez de bloquear la query (ver `tests/fixtures/19c-physical-standby.yaml`, hallazgo `tablespaces`).

### `risk_class` vs. `cost_class` — no confundir

- **`risk_class`** mide seguridad: qué tan sensible/peligroso sería que esta query se ejecutara con una identidad o alcance incorrecto. En Fase 1/Hardening todo el catálogo certificado es `R0` (read-only, `ESTACK_DIAGNOSTIC_ROLE` de mínimo privilegio, sin acceso a datos de aplicación) — `R1`/`R2` quedan reservados para niveles futuros de sensibilidad si el catálogo los requiere, vía `/change security`.
- **`cost_class`** mide impacto operacional/de performance sobre el ambiente objetivo (`LOW|MEDIUM|HIGH|BLOCKED`) — ver `policies/query-cost-policy.md`. Una query puede ser perfectamente segura (`risk_class: R0`) y aun así costosa (`cost_class: HIGH`), por ejemplo ASH sobre una ventana amplia en un cluster grande.

Toda query certificada es de sólo lectura por construcción (`execution_mode: READ_ONLY`): si el verbo no es `SELECT`/`get`/`status`/`show`/equivalente de lectura, no puede entrar al catálogo. Una consulta nueva no certificada puede ser **generada como texto** por Claude para revisión y ejecución manual del DBA — nunca ejecutada automáticamente por el e-stack. Toda incorporación o modificación de una entrada certificada sigue `/change query`, validando además contra `docs/CAPABILITY_MATRIX.md` (ver `EVOLUTION.md#13-change-compatibility`).

---

## Context/Token Model

> MULTI-AGENT DOES NOT MEAN MULTI-CONTEXT.

**Task Package** (orquestador → especialista), mínimo:

```yaml
task_id: string
target_summary: string        # referencia a discovery cacheado, no evidencia cruda
question: string
relevant_evidence_refs: [EVD-...]
constraints: {}
expected_output: string
```

**Result Package** (especialista → orquestador), mínimo:

```yaml
findings: [...]
evidence_refs: [EVD-...]
hypotheses: [...]
confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|UNDETERMINED
recommendations: [...]
next_skill_or_agent: string|null   # sólo si es necesario
```

Reglas: activación mínima de agentes; contexto mínimo; evidencia por referencia (nunca duplicada inline); sin propagación de historial completo; sin evidencia duplicada entre agentes (se reutiliza el `EVD-*` ya recolectado); preprocesamiento local antes de que cualquier evidencia entre al Task/Result Package; presupuestos de tokens/contexto declarados por agente/skill/workflow; cache de discovery y de evidencia por sesión/target; reutilización de hallazgos existentes antes de re-solicitar evidencia.

### Pipeline de activación (Foundation Hardening)

```
DISCOVERY
  → CAPABILITY FILTER   (config/capability-matrix.yaml + version-awareness → qué es SUPPORTED/PARTIALLY_SUPPORTED aquí)
    → AGENT FILTER      (workflows/*.md#gates → qué agentes aplican a esta versión/arquitectura/rol)
      → SKILL FILTER    (Allowed skills del agente ∩ skills compatibles con el ambiente)
        → CONTEXT PACKAGE (Task Package mínimo, sólo para lo que sobrevivió los filtros)
```

Nunca `activate agent → discover unsupported → terminate` cuando el discovery ya cacheado permite saberlo de antemano — eso es exactamente el desperdicio de contexto que este pipeline evita. Si `oracle-operations-orchestrator` ya sabe (por `core/context-discovery`) que el target es standalone, `oracle-rac-analyst` ni siquiera entra al Agent Filter.

Métricas conceptuales que el orquestador reporta en su Result Package (no requieren un contador de tokens real en Fase 1 — el contrato y la métrica se definen ahora; el cálculo exacto se conecta cuando la plataforma exponga una API confiable):

```yaml
agents_skipped_by_capability: int
skills_skipped_by_version: int
skills_skipped_by_license: int
queries_skipped_by_cost: int
tokens_avoided: int|null       # null si no hay forma fiable de estimarlo aún
```

---

## Capability Status Model (Foundation Hardening)

No se permiten fallos silenciosos. Toda capability (agente, skill o query) que no pueda ejecutarse tal como se pidió devuelve uno de estos estados, nunca simplemente "no hice nada":

```text
SUPPORTED               — la capability se ejecutó sin restricciones
PARTIALLY_SUPPORTED     — se ejecutó con alcance reducido (ej. versión soportada parcialmente)
UNSUPPORTED             — la feature Oracle/OS no existe en este ambiente (ej. multitenant en 10g)
LICENSE_RESTRICTED      — depende de una feature potencialmente no licenciada y no se pudo confirmar
INSUFFICIENT_PRIVILEGES — ESTACK_DIAGNOSTIC_ROLE no alcanza para la evidencia requerida
INSUFFICIENT_EVIDENCE   — la evidencia recolectada no permite concluir con confianza suficiente
POLICY_BLOCKED          — policies/ bloquea la operación (ej. cost_class excede lo permitido por el workflow)
ENVIRONMENT_UNKNOWN     — el discovery no pudo determinar lo necesario para evaluar los demás estados
```

Cada estado se reporta con:

```yaml
capability_status: SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED|LICENSE_RESTRICTED|INSUFFICIENT_PRIVILEGES|INSUFFICIENT_EVIDENCE|POLICY_BLOCKED|ENVIRONMENT_UNKNOWN
reason: string           # por qué
impact: string           # qué parte del análisis queda incompleta por esto
alternative: string|null # ruta alternativa si existe (ej. "usar workflow NON-CDB")
required_action: string|null   # ej. LICENSE_CHECK_REQUIRED
```

Ejemplos:

```yaml
capability_status: UNSUPPORTED
reason: Oracle Multitenant is not available on this database/version.
impact: Container-level analysis cannot be performed.
alternative: Use NON-CDB workflow.
required_action: null
```

```yaml
capability_status: LICENSE_RESTRICTED
reason: Required feature may depend on Oracle licensing.
impact: Automated evidence collection is blocked.
alternative: Use non-licensed evidence path (e.g. Statspack instead of AWR).
required_action: LICENSE_CHECK_REQUIRED
```

Detalle completo y ejemplos de los 8 estados: [`policies/capability-degradation-policy.md`](../policies/capability-degradation-policy.md). Validado por `tests/test_capability_*.sh` (uno por estado).

---

## RCA Model

Estados de una afirmación, de menor a mayor certeza (nunca se confunde observación con causa):

`FACT → OBSERVATION → HYPOTHESIS → PROBABLE_CAUSE → CONFIRMED_ROOT_CAUSE`, con `UNDETERMINED` como salida válida cuando la evidencia no alcanza.

Flujo: `SYMPTOM → CONTEXT → EVIDENCE → HYPOTHESES → VALIDATION → RCA → IMPACT → RECOMMENDATION → CHANGE PROPOSAL → DOCUMENTATION`. Si falta evidencia en cualquier paso, se indica explícitamente en vez de saltarlo.

---

## Evidence Model

Todo `evidence_id` (`EVD-*`) registra: `evidence_id, analysis_id, timestamp, target, collector, source, classification (raw|sanitized|derived), sensitivity, hash (si aplica), retention metadata`. `evidence/raw` nunca se modifica; los agentes trabajan preferentemente con `sanitized`/`derived`. Trazabilidad obligatoria: `EVIDENCE (EVD-) → FINDING (FND-) → RECOMMENDATION (REC-) → CHANGE PROPOSAL (CHG-)`, todo bajo un `ANA-*` (o `INC-*` si es un incidente).
