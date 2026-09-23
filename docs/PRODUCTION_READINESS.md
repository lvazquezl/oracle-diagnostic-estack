# Production Readiness — alcance real y criterios

Este documento define **qué significa «listo»** para el Oracle Diagnostic E-Stack y cómo se decide con evidencia. No certifica ningún entorno Oracle: la Fase 14 entrega el marco de decisión, no adaptadores reales. Complementa [`PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md`](PHASE_14_PRODUCTION_READINESS_GOVERNANCE.md), [`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md), [`SECURITY_AND_PRIVACY.md`](SECURITY_AND_PRIVACY.md), [`RELEASE_AND_ROLLBACK.md`](RELEASE_AND_ROLLBACK.md), [`GOVERNANCE_AND_EVOLUTION.md`](GOVERNANCE_AND_EVOLUTION.md) y [`PILOT_ACCEPTANCE_CHECKLIST.md`](PILOT_ACCEPTANCE_CHECKLIST.md).

> READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY · EVIDENCE FIRST. Nada de lo descrito aquí ejecuta, aprueba, publica ni despliega por sí mismo.

## Alcance real

| Capa | Estado real hoy |
|---|---|
| Servidor MCP local por stdio (`python -m mcp_gateway`) | Implementado y probado con **fixtures sintéticos** (`TESTED_WITH_SYNTHETIC_FIXTURES`) |
| Adaptador `fixture` | Único operativo; no observa nada real |
| Adaptador `oracle_sql` | `DISABLED`: sin driver, sin camino de conexión |
| Adaptadores `oracle_diag_file`, `os_readonly` | `CONTRACT_ONLY`: contrato declarado, sin implementación |
| Motores RCA (Fase 11), asesoría/documentación/conocimiento (Fase 12), capacidad (Fase 10) | Implementados y probados con datos sintéticos |
| Queries certificadas | Certificadas **estáticamente** (R0, sólo lectura, contrato); nunca ejecutadas contra una base real |
| Agentes y skills | Contratos de instrucción para el modelo; sólo los respaldados por un motor o parser tienen pruebas ejecutables |
| Entornos Oracle reales (lab o producción) | `NOT_INTEGRATION_TESTED` — ningún piloto, ningún registro de piloto |

La fuente única de verdad es [`config/production-readiness-registry.json`](../config/production-readiness-registry.json), verificada contra el código con `python -m release_readiness registry-check`. Resumen del registro actual:

| Tipo de componente | Cantidad |
|---|---|
| adapter | 4 |
| mcp_tool | 5 |
| collector | 12 |
| engine | 5 |
| agent | 18 |
| domain | 20 |
| skill_domain | 16 |

Distribución de madurez: `TESTED_WITH_SYNTHETIC_FIXTURES` 50, `CONTRACT_ONLY` 29, `DISABLED` 1; ningún componente en `PILOT_VALIDATED`, `CERTIFIED` ni `UNSUPPORTED` a nivel de registro (la incompatibilidad por versión o licencia se resuelve por destino en tiempo de ejecución, no en el registro).

## Estados de madurez

Cada estado es una **afirmación verificable**; el verificador rechaza cualquier afirmación sin su evidencia (`release_readiness/registry.py`, definiciones en `release_readiness/common.py`).

| Estado | Definición | Evidencia exigida |
|---|---|---|
| `UNSUPPORTED` | No soportado (la característica no existe en el destino o el E-Stack no la cubre) | motivo (`reason`) |
| `DISABLED` | Existe o está declarado pero **no puede ejecutarse**: no hay flag, variable de entorno ni argumento que lo active | motivo (`reason`) |
| `CONTRACT_ONLY` | Especificado y certificado estáticamente; nunca ejecutado contra un destino real | — |
| `TESTED_WITH_SYNTHETIC_FIXTURES` | Ejecutado por pruebas automáticas con datos sintéticos | ≥ 1 script `tests/test_*.sh` existente |
| `PILOT_VALIDATED` | Validado en un entorno **no productivo representativo** aprobado | registro de piloto válido con archivos de evidencia verificables por hash |
| `CERTIFIED` | `PILOT_VALIDATED` + aceptación formal del administrador | registro de piloto con aceptación |

Reglas adicionales: el estado de un adaptador debe **coincidir** con lo que el código informa (`VERIFIED_FIXTURE`→`TESTED_WITH_SYNTHETIC_FIXTURES`, `CONTRACT_ONLY`→`CONTRACT_ONLY`, `DISABLED`→`DISABLED`, `VERIFIED_LAB`→`PILOT_VALIDATED`); declarar más es `REG_MATURITY_OVERSTATED` y declarar menos es `REG_MATURITY_STALE`. La disponibilidad en la matriz de capacidades ([`CAPABILITY_MATRIX.md`](CAPABILITY_MATRIX.md)) mide cobertura del marco por versión; **no** equivale a certificación de un entorno.

### Compatibilidad por versión efectiva

Las versiones se resuelven **numéricamente** (`mcp_gateway/versions.py`): `9.2` < `10.1` y `11.2.0.10` > `11.2.0.4`; una versión con parche o RU pertenece a su familia por el número mayor (`19.0.0.0.0` → `19c`). `latest`, cadenas vacías, mayores fuera de tabla y dígitos no ASCII resuelven a «desconocida» y **nunca** se asumen soportadas: el destino queda `ENVIRONMENT_UNKNOWN`/`UNSUPPORTED` y no se intenta ninguna consulta. Un colector sin metadatos de versión soporta **cero** versiones (fail closed).

## Criterios por entorno

| Entorno | Qué es | Criterios para operar | Cómo se verifica |
|---|---|---|---|
| Desarrollo / revisión de código | Checkout con fixtures | El árbol pasa las pruebas focalizadas | `bash tests/test_p14_release_gate.sh` |
| **Release de framework** | Publicar el repositorio etiquetado como *fixture-only* | Gate de release `PASS` + regresión completa con identidad de árbol `VERIFIED` + `git diff --check` limpio + revisión humana | `python -m release_readiness gate` con paquete de evidencias |
| **Piloto local con fixtures** | Claude Code + gateway local con datos sintéticos, para aprender el flujo | Release `PASS` + cadena de fixtures probada + documentos y gobierno válidos | `READY_FOR_LOCAL_FIXTURE_PILOT` |
| **Piloto de entorno real (no productivo)** | Un adaptador real, un destino aprobado | Subproyecto separado aprobado, adaptador real implementado y revisado, permisos de sólo lectura validados, saneamiento en el límite, aceptación del administrador | `READY_FOR_REAL_ENVIRONMENT_PILOT` (hoy `NO`) |
| Producción | — | **Fuera de alcance**: ningún componente está habilitado ni certificado para producción | — |

## Tres decisiones de preparación

El gate calcula tres respuestas independientes (`release_readiness/gate.py`); ninguna se afirma a mano.

| Decisión | Se cumple cuando | Valor actual |
|---|---|---|
| `READY_FOR_RELEASE` | todas las comprobaciones estáticas pasan **y** el paquete de evidencias verifica `PASS` con identidad de árbol `VERIFIED` | depende de la corrida de evidencia de la fase |
| `READY_FOR_LOCAL_FIXTURE_PILOT` | release `PASS` + herramientas, colectores, adaptador `fixture` y motores 11/12/13 en `TESTED_WITH_SYNTHETIC_FIXTURES` + gateway, documentación y gobierno verificados | depende de la corrida de evidencia de la fase |
| `READY_FOR_REAL_ENVIRONMENT_PILOT` | release `PASS` + un adaptador real en `PILOT_VALIDATED`/`CERTIFIED` con registro de piloto válido + estado de código `VERIFIED_LAB` + un destino real habilitado | **`NO`** |

Causas del `NO` (bloqueos que el gate lista): `ADAPTER_oracle_sql_IS_DISABLED`, `ADAPTER_oracle_diag_file_IS_CONTRACT_ONLY`, `ADAPTER_os_readonly_IS_CONTRACT_ONLY`, `NO_ADAPTER_AT_PILOT_VALIDATED_OR_CERTIFIED`, `NO_APPROVED_TARGET_ENVIRONMENT_ENABLED`, `NO_REAL_ENVIRONMENT_INTEGRATION_EVIDENCE`. El plan para levantarlos está en [`PILOT_ACCEPTANCE_CHECKLIST.md`](PILOT_ACCEPTANCE_CHECKLIST.md). Un release de framework puede publicarse con el piloto real en `NO`, siempre etiquetado como fixture-only.

## Límites conocidos

- La plataforma validada es Windows con Git Bash y Python 3.13; Linux y macOS no se probaron (RSK-007).
- El transporte stdio local no autentica a la persona; las aprobaciones son declaraciones estructurales (RSK-002, RSK-003).
- «MCP local» no significa «modelo local»: la evidencia saneada puede salir del equipo según el producto cliente (RSK-005).
- Los riesgos residuales completos, con responsable por rol y condición de cierre, están en [`config/governance/risk-register.json`](../config/governance/risk-register.json).
