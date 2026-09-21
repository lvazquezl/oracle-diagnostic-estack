# Pilot Acceptance Checklist — piloto local con fixtures vs piloto de entorno real

Lista de aceptación para decidir **si un piloto puede empezar** y **cuándo puede darse por aceptado**. Distingue dos pilotos con condiciones muy distintas. Contexto: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md), [`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md), [`SECURITY_AND_PRIVACY.md`](SECURITY_AND_PRIVACY.md), [`GOVERNANCE_AND_EVOLUTION.md`](GOVERNANCE_AND_EVOLUTION.md).

> Este documento **no** contiene procedimientos operativos de conexión a Oracle: los adaptadores reales están `DISABLED`/`CONTRACT_ONLY` y no existe ninguna implementación que documentar. Las precondiciones del piloto real son requisitos para **aprobar un subproyecto**, no instrucciones de ejecución.

## Piloto local con fixtures

Objetivo: que un DBA o administrador conozca el flujo de trabajo con Claude Code y el gateway local **con datos sintéticos**. No observa nada real y no produce conclusiones sobre ningún ambiente.

Precondiciones (todas verificables):

- [ ] `python -m release_readiness gate --evidence <EVIDENCE_DIR_OUTSIDE_REPO>` da `PASS` con identidad de árbol `VERIFIED` para el commit que se va a usar ([`RELEASE_AND_ROLLBACK.md`](RELEASE_AND_ROLLBACK.md)).
- [ ] El gate informa `READY_FOR_LOCAL_FIXTURE_PILOT: YES`.
- [ ] Equipo y cuenta de sistema dedicados de mínimo privilegio; el repositorio y el directorio de evidencias sólo accesibles a quienes lo necesitan.
- [ ] Los participantes entienden y aceptan que: los datos son sintéticos, «MCP local» no es «modelo local» y la evidencia saneada puede salir del equipo según el cliente ([`SECURITY_AND_PRIVACY.md`](SECURITY_AND_PRIVACY.md)).
- [ ] La configuración de Claude Code la hace el propio usuario, sin credenciales ni cadenas de conexión ([`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md#instalación-local)).

Aceptación del piloto local:

- [ ] Se recorrieron `list_capabilities`, `describe_collector`, `collect`, `get_evidence` y `analyze_incident` con los destinos sintéticos.
- [ ] Se observaron las denegaciones esperadas: destino deshabilitado, versión desconocida, licencia sin confirmar, privilegios insuficientes y argumento fuera del esquema.
- [ ] Ninguna salida contenía secretos, rutas personales ni SQL; la asesoría de cambio figuró como `NOT_EXECUTED_BY_ESTACK`.
- [ ] Se registraron hallazgos y sugerencias por el canal de `/change`, sin modificar el repositorio de forma directa.

## Piloto de entorno real

Objetivo: probar **un** adaptador real de sólo lectura contra **un** entorno **no productivo representativo**. Hoy **no puede iniciarse**: falta el adaptador, el destino aprobado y las autorizaciones. `READY_FOR_REAL_ENVIRONMENT_PILOT` debe seguir en `NO` hasta que todo lo siguiente exista y esté evidenciado.

Precondiciones para aprobar el subproyecto (decisiones humanas, cada una con su evidencia):

- [ ] Alcance y responsables: propietario del entorno, administrador Oracle, revisor de seguridad y responsable de release, por rol.
- [ ] Plataforma y versión objetivo (familia y actualización, CDB/non-CDB, RAC/ASM/Data Guard) y matriz de compatibilidad aprobada.
- [ ] Superficie exacta de consultas o archivos: sólo colectores certificados; ningún SQL ni comando libre.
- [ ] Credencial de diagnóstico **mínima y de sólo lectura**, creada y custodiada **fuera** del E-Stack; ningún `SYSDBA`/`SYSASM`/root/sudo; sin secretos en el repositorio ni en el chat.
- [ ] Licencias confirmadas por escrito para lo que se use (por ejemplo Diagnostics Pack, Active Data Guard); lo no confirmado permanece `LICENSE_RESTRICTED`.
- [ ] Red: rutas y reglas aprobadas por la organización; el gateway no abre puertos ni contacta destinos no autorizados.
- [ ] Volumen y ventana: límites de filas, tiempo y frecuencia aprobados.
- [ ] Acceso a un entorno de prueba **no productivo** y representativo, con datos que la organización acepte usar.
- [ ] Un adaptador real implementado y **revisado por `/change`**, que ejecute sólo el SQL certificado inmutable con parámetros tipados, verifique identidad/rol/contenedor/versión de la sesión y aborte ante cualquier contexto inesperado.

Aceptación (todo debe cumplirse y quedar en un **registro de piloto** con archivos de evidencia verificables por hash; el registro lo valida `release_readiness`):

- [ ] Prueba controlada de integración contra el entorno no productivo (`integration_run_id` de una corrida verificada).
- [ ] Validación de que los privilegios son de sólo lectura (`readonly_privileges_validated`).
- [ ] Validación del saneamiento **en el límite** con salidas reales anonimizadas (`sanitization_boundary_validated`).
- [ ] Comparación de los fixtures con salidas reales y ajuste documentado.
- [ ] Aceptación formal del administrador (`administrator_acceptance`, verificación estructural; la identidad se comprueba fuera del E-Stack).
- [ ] Los estados en el registro pasan a `PILOT_VALIDATED` o `CERTIFIED` y el estado de código del adaptador a `VERIFIED_LAB`, mediante un cambio de código revisado.

## Bloqueos

Estado actual del piloto real, tal como lo calcula el gate:

| Bloqueo | Causa | Plan para levantarlo |
|---|---|---|
| `ADAPTER_oracle_sql_IS_DISABLED` | sin driver ni camino de conexión | subproyecto aprobado de adaptador de sólo lectura |
| `ADAPTER_oracle_diag_file_IS_CONTRACT_ONLY` | sólo contrato | implementación revisada del lector de archivos de diagnóstico |
| `ADAPTER_os_readonly_IS_CONTRACT_ONLY` | sólo contrato | implementación revisada de colectores semánticos del SO |
| `NO_ADAPTER_AT_PILOT_VALIDATED_OR_CERTIFIED` | ninguna evidencia de piloto | completar la aceptación anterior |
| `NO_APPROVED_TARGET_ENVIRONMENT_ENABLED` | no hay destino real habilitado | aprobación humana del destino y de la credencial mínima |
| `NO_REAL_ENVIRONMENT_INTEGRATION_EVIDENCE` | nunca se probó contra un entorno real | integración controlada en no productivo |

Un release de marco **fixture-only** puede publicarse con estos bloqueos vigentes; lo que no puede hacerse es presentarlo como preparado para producción. Los riesgos asociados (RSK-001, RSK-008, RSK-009) están en [`config/governance/risk-register.json`](../config/governance/risk-register.json).
