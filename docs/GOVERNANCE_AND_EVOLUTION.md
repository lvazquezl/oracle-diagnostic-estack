# Governance and Evolution — roles, ciclo de vida, excepciones y conocimiento

Cómo cambia el E-Stack de forma controlada (agentes, skills, queries, workflows, políticas, conocimiento, adaptadores, herramientas MCP, documentación). Extiende el flujo `/change` de [`EVOLUTION.md`](../EVOLUTION.md) y el plano B de la Fase 12 (`build_estack_change`) con un **ciclo de vida verificable**, segregación de funciones, excepciones acotadas y un registro de riesgos. Contexto: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md), [`RELEASE_AND_ROLLBACK.md`](RELEASE_AND_ROLLBACK.md), [`SECURITY_AND_PRIVACY.md`](SECURITY_AND_PRIVACY.md).

> Aprobación humana obligatoria para releases, permisos, despliegue, promoción de conocimiento, cambios de alcance, compatibilidad y excepciones. Ningún auto-commit, auto-merge, auto-push, auto-tag, auto-deploy ni autopromoción; ninguna herramienta crea una aprobación.

## Roles

Los roles se asignan por **rol**, no por persona (el registro no guarda nombres). RACI ligero: **R** ejecuta/propone, **A** decide, **C** es consultado, **I** informado.

| Actividad | estack-maintainer | dba-lead | security-reviewer | release-manager | Agentes de apoyo |
|---|---|---|---|---|---|
| Proponer un cambio | R | C | C | I | `estack-evolution-architect` (análisis de brecha e impacto) |
| Implementar y probar | R | C | C | I | — |
| Validación de seguridad | C | C | A | I | `oracle-security-analyst` |
| Revisar compatibilidad y licencias | C | A | C | I | `oracle-discovery-analyst`, `change-advisor` |
| Aprobar un cambio | C | C | C | A | — |
| Publicar / etiquetar | C | I | I | A (ejecuta una persona) | — |
| Excepciones y riesgo aceptado | C | C | A | A | — |
| Curaduría y promoción de conocimiento | C | A (contenido) | C | I | `knowledge-curator` |
| Documentar | R | C | C | I | `technical-documentation-manager` |

Los **agentes asisten y proponen; nunca deciden ni aprueban**. `estack-evolution-architect` gobierna el flujo, `change-advisor` produce asesoría de cambio (`NOT_EXECUTED_BY_ESTACK`), `knowledge-curator` gestiona candidatos y `technical-documentation-manager` documenta; no se clonan roles ni se crean agentes para esta fase (*agents for domains, skills for tasks*).

**Segregación de funciones:** quien propone no puede revisar ni aprobar el mismo cambio. Cuando la organización sea demasiado pequeña, la excepción se registra como tal (véase Excepciones), no se omite.

## Ciclo de vida

```text
PROPOSED → REVIEWED → APPROVED → RELEASED → DEPRECATED → RETIRED        (REVIEWED puede volver a PROPOSED)
```

Un registro de ciclo de vida (`config/governance/lifecycle-records.json`) lleva propietario (por rol), fuentes, referencias de evidencia, compatibilidad (versiones de Oracle, plataformas, cambio incompatible), versión semántica, historial y fecha de **revalidación** (caducidad). `python -m release_readiness governance-check` valida:

| Regla | Hallazgo si se incumple |
|---|---|
| sólo transiciones de un paso legales; el historial parte de `PROPOSED` por quien propone, con fechas no decrecientes, y termina en el estado actual | `GOV_TRANSITION_ILLEGAL`, `GOV_HISTORY`, `GOV_HISTORY_STATE_MISMATCH` |
| el revisor/aprobador **no** es quien propone | `GOV_SELF_APPROVAL` |
| desde `APPROVED` hay un registro de revisión; su verificación es siempre `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED` | `GOV_REVIEW_MISSING`, `GOV_VERIFICATION_OVERSTATED` |
| desde `RELEASED` hay referencia al gate de release y evidencias | `GOV_RELEASE_GATE_REF_MISSING`, `GOV_EVIDENCE_MISSING_FOR_RELEASE` |
| la fecha de revalidación no ha vencido para `APPROVED`/`RELEASED` | `GOV_REVALIDATION_OVERDUE` |
| un registro no puede contener una decisión antes de `APPROVED` | `GOV_REVIEW_PREMATURE` |

Estado actual: el registro `GOV-P14-001` (herramientas de release de la Fase 14) está en **`PROPOSED`**; no se fabricó ninguna revisión ni aprobación. Una aprobación local es una declaración estructural, no una autenticación (RSK-003).

## Cambio normal, urgente y excepción

| Clase | Cuándo | Ruta | Requisitos adicionales |
|---|---|---|---|
| **Normal** | cambio planificado | `PROPOSED → REVIEWED → APPROVED → RELEASED` con `/change` completo (implementación, pruebas, validación de seguridad y regresión, documentación, revisión humana) | — |
| **Urgente** | corrección que no puede esperar el ciclo normal | la misma ruta y **la misma aprobación**; sólo se acelera el calendario | justificación escrita y fecha límite de **revisión posterior** (`GOV_URGENT_INCOMPLETE`, `GOV_URGENT_POST_REVIEW_OVERDUE`); un cambio urgente **nunca** habilita una acción automática sobre Oracle |
| **Excepción** | desviación puntual de una regla (por ejemplo, una segregación de funciones no viable) | registro con clase `EXCEPTION` | ver Excepciones |

Todo cambio operativo sobre Oracle es un plan `NOT_EXECUTED_BY_ESTACK`: pasos para administrador, prerrequisitos, verificación y reversa manual; no existe botón ni herramienta que lo ejecute. El `change-advisor` consume referencias RCA/REC/CHG sin elevar hipótesis inconclusas a hechos.

## Excepciones

Una excepción exige: identificador de riesgo en el registro (`RSK-…`), alcance, **controles compensatorios**, un aprobador **distinto** de quien la solicita y una **caducidad** de como máximo 90 días desde la decisión. Vencida, es un hallazgo (`GOV_EXCEPTION_EXPIRED`) que bloquea el release hasta renovarla con una nueva revisión o cerrarla. Una excepción no cambia estados de madurez ni habilita adaptadores.

Registro de riesgos (`config/governance/risk-register.json`): cada riesgo tiene probabilidad, impacto, estado, responsable **por rol**, mitigación y **condición de cierre**; un riesgo aceptado exige rol, fecha y caducidad. El registro actual lista los riesgos residuales RSK-001 a RSK-009.

## Conocimiento

Ciclo del conocimiento (Fase 12): `CANDIDATE → … → APPROVED → PUBLISHED`, con control de calidad, revisión de duplicados/conflictos y transiciones atadas a una autorización humana **externa** al digest y versión vigentes.

- La promoción de incidentes y RCA a la base de conocimiento exige **control de calidad, ausencia de datos sensibles y aprobación humana**.
- Una hipótesis **nunca** se convierte en causa confirmada por repetición: sólo el motor RCA, con evidencia de soporte y sin contradicciones críticas, puede confirmar, y el candidato de conocimiento lo hereda tal cual.
- Cada entrada conserva fuentes, evidencia, propietario, versión semántica, compatibilidad y fecha de revalidación; el conocimiento caducado o incompatible se depreca (`DEPRECATED`) y luego se retira (`RETIRED`) por el mismo proceso.
- La curaduría nunca se autopromueve: `knowledge-curator` propone y prepara; una persona decide.

## Validación automática

```bash
python -m release_readiness governance-check
python -m release_readiness registry-check
```

Ambos devuelven 0 sólo sin hallazgos. Pruebas: `tests/test_p14_governance.sh` (ciclo de vida, segregación, excepciones, riesgos e integración con el plano B de la Fase 12).
