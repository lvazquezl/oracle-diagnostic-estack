# EVOLUTION.md — `/change` (autocrecimiento gobernado)

## Principio

El e-stack puede proponerse cambios y construir candidatos, pero **no promueve conocimiento ni capacidades críticas sin revisión humana**.

## Subcomandos

- `/change skill` — nuevo skill o modificación de uno existente
- `/change agent` — nuevo agente o modificación de contrato
- `/change query` — nueva query/comando certificado o modificación del catálogo
- `/change workflow` — nuevo workflow o modificación de uno existente
- `/change policy` — cambio de política de seguridad/datos/rate-limiting/licensing
- `/change knowledge` — promoción de un knowledge candidate a `knowledge/`
- `/change compatibility` — ampliación de version-awareness/platform-awareness
- `/change documentation` — nuevo template o cambio de uno existente
- `/change security` — cambio con impacto directo en el modelo de amenazas
- `/change parser` — nuevo tipo de reporte de performance soportado (ej. Exadata AWR, RAC AWR multi-instancia consolidado) o extensión de un parser existente (`parsers/performance/*.py`)

Implementación: [`.claude/commands/change.md`](.claude/commands/change.md), orquestado por [`estack-evolution-architect`](agents/estack-evolution-architect.md).

## Flujo obligatorio

```
DETECT GAP
  → CHANGE REQUEST
    → GAP ANALYSIS
      → IMPACT ANALYSIS
        → PROPOSAL
          → IMPLEMENT
            → TEST
              → SECURITY VALIDATION
                → REGRESSION VALIDATION
                  → DOCUMENT
                    → HUMAN REVIEW
                      → PROMOTE
```

Ningún paso se puede saltar. Un cambio que falla SECURITY VALIDATION o REGRESSION VALIDATION vuelve a IMPLEMENT; nunca se promueve sobre un fallo.

## Detalle por etapa

| Etapa | Responsable | Salida |
|---|---|---|
| DETECT GAP | Cualquier agente, o el DBA | Nota de gap: qué falta, por qué, evidencia de la necesidad |
| CHANGE REQUEST | `estack-evolution-architect` | `CHG-REQ-*` con tipo (`skill\|agent\|query\|workflow\|policy\|knowledge\|compatibility\|documentation\|security`) |
| GAP ANALYSIS | `estack-evolution-architect` (skill `change/gap-analysis`) | Qué contrato/registro se ve afectado, qué no existe hoy — para `skill`/`agent`/`query` verifica además que el `skill_id`/`query_id` propuesto sea único y domain-qualified (`skills/REGISTRY.md`, `queries/REGISTRY.md`) |
| IMPACT ANALYSIS | `estack-evolution-architect` + agente de dominio afectado | Riesgo, compatibilidad hacia atrás, superficie de seguridad, agentes/skills que consumen el elemento, impacto en `config/capability-matrix.yaml` (cobertura de versión/dominio), impacto de licenciamiento si aplica, `cost_class` propuesto si es una query |
| PROPOSAL | `estack-evolution-architect` | Draft del artefacto (manifest de agente/skill, entrada de catálogo de query siguiendo Query Contract v2, workflow con `gates:`, policy) siguiendo su Contract |
| IMPLEMENT | `estack-evolution-architect` | Archivo(s) creados/modificados en el repo (no en producción) |
| TEST | `estack-evolution-architect` | Ejecución de `tests/` relevantes (seguridad, contrato, trazabilidad, IDs canónicos, Query Contract v2, capability status, capability matrix) |
| SECURITY VALIDATION | `oracle-security-analyst` (revisión) | Confirmación de que no introduce operación prohibida ni fuga de datos |
| REGRESSION VALIDATION | `estack-evolution-architect` | Confirmación de que agentes/skills/queries existentes siguen pasando sus tests |
| DOCUMENT | `technical-documentation-manager` | Actualización de `CHANGELOG.md`, versión semántica del elemento, changelog local del dominio |
| HUMAN REVIEW | DBA/arquitecto humano | Aprobación explícita — obligatoria para cualquier promoción |
| PROMOTE | `estack-evolution-architect` (tras aprobación) | El artefacto pasa de `status: candidate` a `status: active` en su registro |

## Versionado y compatibilidad

- Cada agente, skill, query, workflow y policy lleva `version` semántica (`MAJOR.MINOR.PATCH`).
- `MAJOR`: cambio incompatible (contrato de entrada/salida, versiones/plataformas soportadas se reducen).
- `MINOR`: nueva capacidad compatible hacia atrás.
- `PATCH`: corrección sin cambio de contrato.
- Se preserva compatibilidad hacia atrás cuando es razonable; cuando no lo es, el `CHANGELOG.md` lo declara explícitamente como breaking change y el registro correspondiente marca el elemento anterior como `deprecated`.

## Estados de un artefacto

`candidate → under_review → active → deprecated → retired`

Ningún artefacto en `candidate` o `under_review` puede ser invocado por el orquestador en producción diagnóstica normal — sólo en modo de prueba explícito del propio `/change`.

## Knowledge curation

`knowledge-curator` convierte resoluciones validadas (de un `INC-*` o `ANA-*` cerrado) en `knowledge candidate` bajo `knowledge/errors/<dominio>/`. La promoción a conocimiento activo sigue el mismo flujo `/change knowledge` con HUMAN REVIEW.

## 13. `/change compatibility` — validaciones obligatorias (Foundation Hardening)

`/change skill`, `/change query` y `/change compatibility` validan, además del flujo estándar de 12 pasos:

- **Canonical IDs**: el `skill_id`/`query_id` propuesto es único globalmente y domain-qualified (`tests/test_skill_ids_are_globally_unique.sh`, `tests/test_skill_ids_are_domain_qualified.sh`).
- **Capability Matrix**: `config/capability-matrix.yaml` y `docs/CAPABILITY_MATRIX.md` se actualizan en el mismo cambio si el artefacto amplía cobertura de un dominio×versión — nunca quedan desincronizados (`tests/test_capability_matrix_registry_consistency.sh`).
- **Version coverage**: el artefacto declara `supported_oracle_versions`/`container_scope`/`database_role_scope` (queries) o las secciones equivalentes (skills/agentes) — no se certifica nada sin version-awareness explícito.
- **Licensing impact**: si el artefacto depende de una feature de `policies/licensing-awareness-policy.md`, `license_requirements` se declara y `docs/CAPABILITY_MATRIX.md` refleja `LICENSE_DEPENDENT` donde corresponda.
- **Cost class**: toda query nueva declara `cost_class` (nunca `BLOCKED` — eso significaría que no debería certificarse) y su justificación (`policies/query-cost-policy.md`).
- **Query Contract**: toda query nueva cumple el schema completo v2 (`docs/CONTRACTS.md#query-contract-v2-foundation-hardening`) — `tests/test_query_contract_requires_*.sh`.
- **Regression impact**: `REGRESSION VALIDATION` confirma que artefactos existentes que referencian el elemento modificado (`Allowed skills` de agentes, `Skills`/`Evidence required` de workflows) siguen siendo válidos tras el cambio.

Toda incorporación de una nueva versión Oracle entra específicamente por `/change compatibility` y actualiza, en el mismo cambio: `config/capability-matrix.yaml`, las reglas de versión en `policies/version-awareness-policy.md`, las queries afectadas, los tests relevantes, y la documentación (`docs/CAPABILITY_MATRIX.md`).

### `/change compatibility` — checklist obligatorio (Oracle Core Compatibility Hardening)

Ninguna versión Oracle nueva (ni un ajuste de rango sobre una existente) se marca `SUPPORTED`/`COMPATIBLE` sin que el mismo cambio incluya, todos, no un subconjunto:

1. **Dictionary delta**: `compatibility/oracle-dictionary/views.yaml` actualizado con toda vista/columna nueva realmente usada y su `min_version` real (fuente: documentación oficial Oracle — nunca inventada, ver `docs/QUERY_VARIANTS.md#future-proof-version-policy`).
2. **Query variants**: si la nueva versión introduce una diferencia de columnas/vistas frente a variantes existentes, se crea un variant nuevo (`docs/QUERY_VARIANTS.md#query-variant-contract`) — nunca se extiende el `max` de un variant existente para cubrir una versión no validada contra el dictionary.
3. **Compatibility matrix**: `config/query-compatibility-matrix.yaml` refleja el/los variant(s) afectados y su `validation_status`.
4. **Fixtures**: al menos un fixture (`tests/fixtures/*.yaml`) representando la nueva versión/arquitectura, con `architecture`/`container`/`role`/`open_mode` (`tests/test_documented_support_matches_query_variants.sh` y equivalentes la consumen).
5. **Tests**: el test de Resolver por versión correspondiente (`tests/test_query_variant_resolver_<version>.sh`) existe y pasa; si no existe uno para la nueva versión, se crea siguiendo el patrón de los 7 existentes (10g–23ai).
6. **Skills**: `skills/**/manifest.yaml`/`SKILL.md` que dependan de la query actualizan su `supported_oracle_versions` sólo hasta donde el Resolver realmente puede seleccionar una variante — nunca declarar soporte que el catálogo de variantes no respalda.
7. **Docs**: `docs/CAPABILITY_MATRIX.md` y, si aplica, `docs/PHASE_2_COMPATIBILITY_HARDENING.md` (o el documento de hardening vigente) referencian el cambio.

Ver también sección "Future-proof version policy" en `docs/QUERY_VARIANTS.md` para el tratamiento de `latest` y versiones Oracle aún no integradas.

## 15. `/change parser` — checklist obligatorio (Fase 3 Completion & Portability Hardening)

Ningún tipo de reporte nuevo (ni una sección nueva sobre un parser existente) se marca `SUPPORTED`/`PARTIALLY_SUPPORTED` sin que el mismo cambio incluya, todos, no un subconjunto:

1. **Parser**: implementación en `parsers/performance/<tipo>_parser.py` (Python 3, sólo librería estándar) que devuelve el envelope común `ParsedReport` (`parsers/performance/common.py`) — nunca un formato ad-hoc paralelo.
2. **Type detector**: `parsers/performance/type_detector.py` reconoce el nuevo tipo por firma de contenido, nunca por extensión de archivo; si la firma puede confundirse con un tipo existente, el orden de chequeo se documenta explícitamente en el propio detector.
3. **Security**: el nuevo parser no llama `eval`/`exec`/`subprocess`/`os.system`/`compile()` sobre contenido del reporte — extendido en `tests/test_parser_does_not_execute_embedded_instructions.sh`; ninguna sección extrae SQL text ni bind values (`Sanitizer.drop_sql_text()`).
4. **Fixtures**: al menos un fixture representativo en `tests/fixtures/reports/`, y si el tipo es propenso a reportes parciales/malformados, un fixture adicional de ese caso (ver `statspack-partial.txt`/`empty-report.txt`/`*-malformed.txt` como patrón).
5. **Tests**: detección de tipo, extracción de cada sección nueva, y (si aplica) truncamiento por `SizeLimitPolicy` — siguiendo el patrón de los tests `test_statspack_*`/`test_awr_*`/`test_addm_*`/`test_execution_plan_*` existentes.
6. **Skill**: el `manifest.yaml`/`SKILL.md` del skill correspondiente declara el parser en `optional_evidence` (`report_parser: parsers/performance/<tipo>_parser.py`) y, si el skill ya tenía un capability map por sección (ver `skills/performance/statspack-analysis/SKILL.md#statspack-capability-map`), se actualiza — nunca se finge cubierta una sección que el parser concreto no extrae.
7. **Capability matrix**: `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` reflejan la cobertura real, por sección si corresponde — nunca `SUPPORTED` global cuando sólo algunas secciones lo están.
8. **Docs**: `docs/PHASE_3_COMPLETION_HARDENING.md#report-ingest-architecture` (o el documento de hardening vigente que lo suceda) referencia el tipo/sección nueva.
