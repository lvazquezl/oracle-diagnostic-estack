# ARCHITECTURE.md

## 1. Vista general

```
DBA Workstation
  → Claude Code (routing, agents, skills, commands)
    → E-Stack (this repo: contracts, policies, workflows, knowledge, documentation)
      → MCP Diagnostic Gateway (LOCAL, semantic read-only tools only)
        → Security / Data Sanitization Layer (LOCAL)
          → Certified Read-Only Collectors
            → Oracle / RAC / GI / ASM / Data Guard / OS
```

- Todo corre en la estación de trabajo del DBA. No hay componente que se ejecute con privilegios elevados fuera del alcance del propio DBA.
- El modelo (Claude) nunca tiene una vía directa a Oracle/OS: siempre pasa por el Gateway → Sanitizer → Collector, y sólo ve evidencia ya sanitizada.
- La capa de Sanitización es **local y obligatoria** — nada crudo cruza hacia el modelo salvo que la política lo permita explícitamente.

## 2. Planos del sistema

| Plano | Responsabilidad | Puede escribir? |
|---|---|---|
| Orchestration Plane (`oracle-operations-orchestrator` + agentes especialistas) | Interpretar la solicitud, seleccionar agentes/skills mínimos, correlacionar, redactar hallazgos y recomendaciones | No |
| MCP Diagnostic Gateway (`mcp/`) | Exponer tools semánticas certificadas (`get_*`) sobre Oracle/OS | No — sólo lectura, catálogo cerrado |
| Sanitization Layer (`sanitizers/`) | Clasificar (KEEP/MASK/HASH/TOKENIZE/DROP) y minimizar evidencia antes de enviarla al modelo | No |
| Collector Plane (`collectors/`) | Ejecutar las queries/comandos certificados del catálogo (`queries/`) contra el ambiente real | No — certificados read-only, con timeout/max-rows |
| Evidence Plane (`evidence/`, `analysis/`) | Almacenar evidencia raw/sanitized/derived y el registro de análisis con trazabilidad EVD→FND→REC→CHG | No aplica (almacenamiento) |
| Change Advisor Plane (`change-advisor`, `policies/`) | Convertir recomendaciones en propuestas de cambio con comandos para ejecución HUMANA | No — nunca ejecuta |
| Documentation Plane (`technical-documentation-manager`, `templates/`, `reports/`) | Generar Markdown automático y binarios bajo demanda | No aplica |
| Evolution Plane (`estack-evolution-architect`, `/change`) | Gestionar el crecimiento gobernado del stack | No sin revisión humana |

**No existe Execution Plane.** Es una decisión de diseño explícita: no hay tool, agente ni skill capaz de mutar Oracle, GI, ASM, OS, red o almacenamiento.

## 3. Flujo de una solicitud

1. DBA invoca un comando (`/healthcheck`, `/diagnose`, etc.) en Claude Code.
2. `oracle-operations-orchestrator` resuelve el Workflow Contract correspondiente en `workflows/`.
3. Si no hay contexto de discovery cacheado para el target, se invoca `oracle-discovery-analyst`.
4. **Capability Filter** (Foundation Hardening): el orquestador cruza el discovery contra `config/capability-matrix.yaml` y los `gates:` del workflow (`docs/CONTRACTS.md#workflow-contract`) — versión, arquitectura, licencia, privilegio, seguridad, costo, evidencia — antes de considerar ningún agente. Un agente/skill que el discovery ya descarta (ej. `oracle-rac-analyst` sobre un target standalone) ni siquiera entra al siguiente paso; se registra como `agents_skipped_by_capability`/`skills_skipped_by_version` en vez de activarse y fallar después.
5. **Agent Filter / Skill Filter**: de lo que sobrevive el Capability Filter, el orquestador arma un **Task Package** mínimo por agente especialista requerido (ver `docs/CONTRACTS.md`).
6. Cada especialista solicita evidencia al Gateway vía queries certificadas (`queries/`), nunca SQL/shell libre; el gate `cost` (`policies/query-cost-policy.md`) decide si una query `HIGH` se ejecuta automáticamente o se limita/pospone.
7. El Gateway invoca el Collector correspondiente; el resultado pasa por el Sanitizer antes de volver.
8. El especialista produce un **Result Package** (findings, evidence_refs, hypotheses, confidence, recommendations, `capability_status` si algo no se pudo ejecutar — ver `docs/CONTRACTS.md#capability-status-model`) y lo devuelve al orquestador — no historial completo.
9. El orquestador consolida (incluyendo todo `capability_status` no-`SUPPORTED`), y `technical-documentation-manager` registra `analysis/ANA-YYYYMMDD-NNN/` automáticamente.
10. Si hay una recomendación accionable, `change-advisor` construye una propuesta de cambio (`CHG-*`) para ejecución manual.
11. Entregables binarios sólo se generan si el DBA los pide explícitamente vía `/document`.

## 4. Estructura del repositorio

```
oracle-diagnostic-estack/
  CLAUDE.md                 Punto de entrada de comportamiento (compacto)
  README.md, ARCHITECTURE.md, SECURITY.md, EVOLUTION.md, DISTRIBUTION.md, CHANGELOG.md
  agents/                   Manifests de los 18 agentes (Agent Contract)
  skills/<dominio>/         Skills por dominio (Skill Contract) + REGISTRY.md
  commands/                 Especificación conceptual de cada slash command
  .claude/commands/         Implementación real de los slash commands en Claude Code
  workflows/                Workflow Contracts por comando/escenario
  queries/                  Catálogo certificado de queries/comandos read-only + REGISTRY.md
  collectors/               Especificación de collectors certificados por plataforma
  mcp/                      Diseño del MCP Diagnostic Gateway local + tool manifest
  sanitizers/               Política y reglas de clasificación/redacción de evidencia
  policies/                 Seguridad, identidades, operaciones prohibidas, licensing, rate limiting
  playbooks/                Playbooks de diagnóstico representativos
  knowledge/errors/         Taxonomía de conocimiento de errores ORA/TNS/RMAN/CRS
  evidence/{raw,sanitized,derived}/  Evidencia por análisis (no versionada; ver .gitignore)
  analysis/                 Registro Markdown automático de cada análisis (ANA-*)
  reports/                  Entregables binarios generados bajo demanda (no versionados)
  templates/                Plantillas corporativas para DOCX/XLSX/PDF/PPTX
  config/                   Configuración local (targets permitidos, ambiente, e-stack)
  scripts/                  Bootstrap y validación de estación de trabajo
  parsers/performance/      Parsers locales de reportes (AWR/Statspack/ADDM/Execution Plan) — Python 3, sólo stdlib
  parsers/rac/              Parsers locales de salida de collectors GI/Clusterware/ASM/red — Python 3, sólo stdlib
  tests/                    Quality gates de seguridad, contratos y trazabilidad
  docs/                     Contratos definitivos y documentación complementaria
  .gitattributes            Política de line endings (LF forzado en *.sh/*.py/*.yaml/*.md)
```

## 5. Decisiones arquitectónicas (Fase 1)

1. **No Execution Plane.** Ninguna tool MCP recibe SQL/shell arbitrario ni verbos de escritura. Ver `policies/forbidden-operations.md` y `tests/`.
2. **Identidades separadas.** El e-stack usa siempre `ESTACK_DIAG_*` (read-only, catálogo de vistas/privilegios mínimos). La identidad DBA humana nunca es visible ni usable por el modelo. Ver `policies/identity-model.md`.
3. **Sanitización local obligatoria antes de tocar el modelo.** Ningún raw data cruza esa frontera salvo excepción de política explícita y documentada.
4. **Catálogo certificado cerrado con extensión gobernada.** Toda query nueva nace como propuesta (`/change query`) — si no está certificada, Claude puede *generarla* como texto para que el DBA la revise y ejecute manualmente, nunca ejecutarla.
5. **Multi-agente ≠ multi-contexto.** Orquestación por Task/Result Package con evidencia por referencia; nunca se reenvía el historial completo entre agentes.
6. **Documentación Markdown automática, binarios bajo demanda.** Evita duplicar el análisis y mantiene trazabilidad EVD→FND→REC→CHG entre formatos.
7. **Version-awareness y platform-awareness como principio transversal**, no como feature aislada: todo query/skill declara versiones/plataformas soportadas y ningún agente asume que una vista/columna/comando existe en todas.
8. **Comandos de Claude Code como interfaz real.** Los slash commands de la sección 18 del prompt maestro se implementan como comandos reales en `.claude/commands/`, cada uno resolviendo a un Workflow Contract en `workflows/`.
9. **Catálogo de tools MCP extendido más allá de las 14 nombradas explícitamente** en el prompt original, para cubrir RMAN/backup, security posture y capacity trending que los agentes 7.9/7.11/7.13 requieren — misma disciplina de certificación (ver `mcp/tool-manifest.md`).
10. **Runtime de Fase 1 es de diseño/contrato, no de ejecución viva.** El Gateway MCP, los collectors reales y los generadores de documentos binarios se implementan en fases posteriores (7 y 9); Fase 1 entrega contratos, catálogo, políticas y tests estáticos que validan que nada de lo definido permite escritura.
11. **Identificadores de skill siempre domain-qualified** (Foundation Hardening). `skill_id` es siempre `dominio/skill`, nunca un nombre corto suelto — cierra la ambigüedad de nombres como `temp`/`undo`/`sga`/`pga`/`services`/`memory`/`io` que existen legítimamente en varios dominios. Ver `docs/CONTRACTS.md#skill-contract`, `skills/REGISTRY.md`.
12. **Costo y seguridad son dimensiones separadas** (Foundation Hardening). `risk_class` (seguridad — Fase 1/Hardening: todo el catálogo es `R0`) y `cost_class` (impacto operacional — `LOW/MEDIUM/HIGH/BLOCKED`) nunca se confunden. Ver `policies/query-cost-policy.md`, Query Contract v2 en `docs/CONTRACTS.md`.
13. **Capability Filter antes de Agent Filter** (Foundation Hardening). El pipeline `DISCOVERY → CAPABILITY FILTER → AGENT FILTER → SKILL FILTER → CONTEXT PACKAGE` evita activar un agente que el discovery ya sabe que es incompatible — nunca `activate → discover unsupported → terminate`. Ver `docs/CONTRACTS.md#pipeline-de-activación-foundation-hardening`, `config/capability-matrix.yaml`.
14. **No se permiten fallos silenciosos** (Foundation Hardening). Toda capability que no se ejecuta como se pidió devuelve uno de 8 estados formales (`SUPPORTED…ENVIRONMENT_UNKNOWN`) con `reason/impact/alternative/required_action`. Ver `docs/CONTRACTS.md#capability-status-model`, `policies/capability-degradation-policy.md`.
15. **Target Profile como fuente única de identidad de ambiente** (Fase 2 — Oracle Core). `oracle-discovery-analyst` publica un schema fijo y versionado (`docs/TARGET_PROFILE.md`); ningún especialista posterior vuelve a determinar versión/arquitectura/rol por su cuenta. Ver `agents/oracle-discovery-analyst/AGENT.md#discovery-sequence`.
16. **Agentes profundizados por fase viven en carpeta, no en archivo plano** (Fase 2, extendido en Fase 3). `agents/<id>/AGENT.md` para agentes con documentación extensa (`oracle-discovery-analyst`, `oracle-dba-analyst`, `oracle-performance-analyst`); el resto permanece `agents/<id>.md` hasta que su fase los profundice — extensión aditiva, `agents/REGISTRY.md` sigue siendo la fuente de verdad del path canónico.
17. **Licensing Gate como paso explícito del pipeline de activación, no una verificación ad-hoc** (Fase 3 — Oracle Performance). Toda capability que dependa de Diagnostics/Tuning Pack/Active Data Guard pasa por una secuencia fija (`Capability requested → Version check → Architecture check → License gate → Privilege gate → Cost gate → Evidence collection`) antes de recolectar evidencia; sin confirmación, cae a una ruta alternativa MENOS restringida, nunca a una más restringida. Ver `agents/oracle-performance-analyst/AGENT.md#licensing-rules`, `policies/licensing-awareness-policy.md`.
18. **Ingesta de reportes como pipeline local determinista, nunca como instrucciones** (Fase 3 Completion & Portability Hardening). `FILE → TYPE DETECTOR → LOCAL PARSER → STRUCTURED REPORT → SANITIZER → EVIDENCE → SKILL → AGENT`, implementado en `parsers/performance/` (Python 3, sólo librería estándar, ningún `eval`/`exec`/`subprocess`/`os.system` sobre contenido de reporte). El contenido del reporte es siempre DATA — nunca se interpreta como instrucción, verificado con fixture de intento de inyección (`tests/fixtures/reports/addm-injection-attempt.txt`) y test estático (`tests/test_parser_does_not_execute_embedded_instructions.sh`). Estados de error normalizados (`SUCCESS/PARTIAL/UNSUPPORTED_FORMAT/UNKNOWN_REPORT_TYPE/MALFORMED_REPORT/EMPTY_REPORT/SANITIZATION_FAILED`), límites de tamaño configurables (`SizeLimitPolicy`), trazabilidad por SHA-256 del archivo fuente. SQL text/bind values nunca se extraen. Ver `docs/PHASE_3_COMPLETION_HARDENING.md#report-ingest-architecture`.
19. **Contrato de agente materializado en archivos estructurados cuando la profundidad lo justifica** (Fase 3 Completion & Portability Hardening, `oracle-performance-analyst` v4.0.0). `manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml` como fuente de verdad estructurada; `AGENT.md` queda como documento narrativo que referencia, nunca duplica, esos campos. Excepción deliberada a la convención de Fase 2/3 de un único `AGENT.md` — no aplicado retroactivamente a otros agentes sin justificación equivalente.
20. **Line endings LF forzados independientemente del `core.autocrlf` local** (Fase 3 Completion & Portability Hardening). `.gitattributes` fuerza `eol=lf` en `*.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md`; `tests/test_no_crlf_in_shell_scripts.sh` falla el build si cualquier `*.sh`/`*.bash` contiene CRLF. Ver `docs/PHASE_3_COMPLETION_HARDENING.md#line-ending-policy`.
21. **Grid Infrastructure absorbido por `oracle-rac-analyst`, sin agente separado** (Fase 4 — RAC/GI/ASM/Network). *Agents for domains, skills for tasks*: GI vive en el dominio `rac` con prefijo `gi-` (`rac/gi-scan`, `rac/gi-ocr-status`, etc.), nunca un `oracle-gi-analyst` independiente — evita fragmentar un dominio de cluster único en dos agentes que necesitarían coordinarse constantemente. Ver `docs/RAC_DIAGNOSTIC_MODEL.md#gi-absorbido-no-un-agente-separado`.
22. **Collector Contract para comandos no-SQL, paralelo al Query Contract** (Fase 4). `crsctl`/`srvctl`/`olsnodes`/`ocrcheck`/`lsnrctl`/`asmcmd`/`oifcfg` nunca se exponen como shell arbitrario — cada uno mapea a un `collector_id` semántico con `command_family` fijo, `side_effect_class: READ_ONLY` obligatorio (o `BLOCKED` si no puede garantizarse), parseado localmente por `parsers/rac/*.py` antes de llegar al modelo. Ver `docs/GI_READONLY_COLLECTORS.md`.
23. **Recurso Clusterware vs. conectividad: mismo nombre de entidad (SCAN/VIP/listener), dos dominios sin duplicación de recolección** (Fase 4). `oracle-rac-analyst` (`rac/gi-scan`) ve el *estado del recurso*; `oracle-network-analyst` (`network/scan`) ve la *conectividad*. Ningún dato se recolecta dos veces — cada agente cita al otro por `evidence_refs`. Ver `docs/RAC_DIAGNOSTIC_MODEL.md#boundary-con-oracle-network-analyst`.

## 6. Referencias

`SECURITY.md` (modelo de amenazas y controles), `EVOLUTION.md` (`/change`), `docs/CONTRACTS.md` (Agent/Skill/Workflow/Query Contract definitivos), `docs/CAPABILITY_MATRIX.md` + `config/capability-matrix.yaml` (cobertura por dominio × versión), `policies/query-cost-policy.md`, `policies/capability-degradation-policy.md`, `policies/version-awareness-policy.md`, `docs/TARGET_PROFILE.md` (identidad de ambiente, Fase 2), `docs/PHASE_2_ORACLE_CORE.md`, `docs/PHASE_3_ORACLE_PERFORMANCE.md`, `docs/QUERY_VARIANTS.md`, `docs/ORACLE_READONLY_PRIVILEGES.md`, `policies/discovery-cache-policy.md`, `policies/licensing-awareness-policy.md`.
