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
