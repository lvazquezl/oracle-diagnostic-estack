# Operations Runbook — gateway local y herramientas de release

Runbook para operar el **gateway MCP local** (`mcp_gateway`, fixtures sintéticos) y las herramientas de release (`release_readiness`). Ningún procedimiento de este documento toca una base de datos Oracle, un host administrado ni la red. Los adaptadores reales están `DISABLED`/`CONTRACT_ONLY`, por lo que **no existe** un runbook de conexión real (ver [`PILOT_ACCEPTANCE_CHECKLIST.md`](PILOT_ACCEPTANCE_CHECKLIST.md)).

Contexto: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md) · [`SECURITY_AND_PRIVACY.md`](SECURITY_AND_PRIVACY.md) · [`PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md`](PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md).

## Instalación local

Requisitos: Python ≥ 3.10 (validado con 3.13), Git y Bash, sin dependencias de terceros ni acceso a red. Validado sólo en Windows con Git Bash.

1. Obtenga el repositorio en el commit o tag que un humano aprobó, sobre un equipo y una cuenta de sistema **dedicados y de mínimo privilegio**.
2. Compruebe que arranca y qué versión es:

```bash
python -m mcp_gateway --version
```

3. Compruebe la identidad del árbol (fingerprint SHA-256 de los archivos del proyecto) y regístrela:

```bash
python -m release_readiness snapshot
```

4. Ejecute el gate estático (no toca nada; sin paquete de evidencias el veredicto de release es `INCONCLUSIVE`, y es lo esperado):

```bash
python -m release_readiness gate --format markdown
```

5. Conecte Claude Code **usted mismo**: imprima el ejemplo, cópielo a su configuración MCP y sustituya el marcador de ruta por la de su checkout. El repositorio nunca modifica su configuración.

```bash
python -m mcp_gateway --print-claude-config
```

No ponga credenciales, cadenas de conexión ni rutas de wallets en esa configuración: el gateway no las acepta y las rechaza al cargar el catálogo de destinos.

### Límites configurables (sólo a la baja)

Los límites pueden **reducirse**; el techo es el valor integrado y cualquier valor fuera de rango impide el arranque (código de salida 2, salida estándar vacía). Ninguna variable de entorno cambia límites, adaptadores ni política.

| Bandera | Rango | Efecto |
|---|---|---|
| `--operation-timeout` | 0.1 – 15 s | plazo duro por operación de adaptador |
| `--max-session-calls` | 1 – 200 | llamadas a herramientas por sesión |
| `--max-rows` | 1 – 200 | filas por recolección |
| `--max-message-bytes` | 1024 – 1048576 | tamaño máximo de un mensaje JSON-RPC |

```bash
python -m mcp_gateway --max-rows 20 --max-session-calls 50 --operation-timeout 5 --max-message-bytes 65536
```

## Healthcheck

| Qué comprobar | Cómo | Resultado sano |
|---|---|---|
| El proceso arranca | `python -m mcp_gateway --version` | imprime nombre y versiones de protocolo, código 0 |
| Superficie MCP real | `python -m release_readiness gate` → `C03_MCP_SURFACE` | `PASS`: 5 herramientas cerradas, denegaciones correctas, stdout sólo protocolo |
| Adaptadores reales apagados | `C04_REAL_ADAPTERS_NOT_ENABLED` | `PASS` |
| Registro coherente con el código | `python -m release_readiness registry-check` | lista de hallazgos vacía, código 0 |
| Gobierno válido | `python -m release_readiness governance-check` | lista de hallazgos vacía, código 0 |

Una comprobación que no puede establecerse (tiempo agotado, sin salida) es `INCONCLUSIVE`, nunca «sano».

## Observabilidad y logging

| Aspecto | Política |
|---|---|
| Canales | `stdout` = **sólo** mensajes del protocolo MCP; `stderr` = registro de auditoría y errores de arranque |
| Niveles | un único nivel operativo: registros de auditoría de llamadas y un texto fijo si el arranque se rechaza; `--audit off` los silencia |
| Contenido | claves fijas (`ts_utc`, `tool_id`, `collector_id`, `target_token`, `status`, `error_code`, `duration_ms`, `request_id`, `session`); **nunca** argumentos, evidencia, SQL, rutas ni excepciones |
| Redacción | los mensajes de error son una tabla fija y no reflejan la entrada; los identificadores de destino salen como tokens por sesión |
| Ubicación | el gateway **no escribe archivos**: si desea conservar el registro, redirija `stderr` a un directorio con permisos restringidos, fuera del repositorio |
| Rotación y retención | las realiza el sistema operativo o el operador sobre el archivo redirigido; se recomienda ≤ 30 días y borrado manual aprobado (véase Retención y borrado) |
| Telemetría | ninguna; no hay envío de datos a servicios externos |

## Recuperación del gateway

El gateway es un proceso local sin estado persistente: la evidencia saneada vive sólo en memoria y se pierde al terminar el proceso (comportamiento deliberado).

| Situación | Acción | Resultado esperado |
|---|---|---|
| El cliente cierra la conexión (EOF) | ninguna | el proceso termina con código 0 |
| El proceso se cae o se detiene | el cliente MCP lo relanza | nueva sesión limpia; las referencias `EVR-*` de la sesión anterior dejan de resolverse (`E_EVIDENCE_NOT_FOUND`) |
| Arranque rechazado (código 2, texto fijo) | revise `--targets`, `--fixtures-dir` y los límites; restaure la configuración desde el repositorio | tras corregir, arranca normal |
| Catálogo de destinos alterado | `git status` y `git diff` sobre `mcp_gateway/config/`; restaure con el flujo de reversa manual de [`RELEASE_AND_ROLLBACK.md`](RELEASE_AND_ROLLBACK.md) | arranque limpio |
| Tiempo agotado de un adaptador | el gateway responde `E_TIMEOUT` y sigue atendiendo; no reintenta | sin reintentos indefinidos |

Recuperación de artefactos propios: la configuración y los datos derivados viven en el repositorio (Git es el respaldo); las copias de evidencias se guardan fuera del repositorio y se respaldan según su política de retención. No se ejecutan reinicios, respaldos ni restauraciones de Oracle.

## Rotación y revocación de credenciales

El E-Stack **no almacena, solicita ni transmite credenciales**: el gateway rechaza destinos con material de conexión y ningún argumento de herramienta las admite. Cuando exista un adaptador real aprobado, la cuenta de diagnóstico y sus secretos se administrarán **fuera del E-Stack** (gestor de secretos y proceso de la organización). Para revocar el acceso ante una sospecha: (1) retire la entrada MCP de la configuración de Claude Code, (2) detenga el proceso, (3) haga rotar o revocar la credencial en el sistema de origen por los canales de la organización. El E-Stack no puede ni debe hacerlo por usted.

## Retención y borrado

| Artefacto | Dónde vive | Retención | Borrado |
|---|---|---|---|
| Evidencia saneada del gateway | memoria del proceso (TTL 1 h) | hasta el fin de la sesión | automático al terminar el proceso |
| Paquete de evidencias de release | directorio **fuera del repositorio** | según la política del proyecto (por ejemplo hasta la siguiente versión aprobada) | manual, aprobado por el responsable de release |
| Log crudo de la corrida (`<paquete>.private`) | junto al paquete, **nunca** dentro | mínimo necesario; contiene rutas locales | manual, aprobado; no se comparte |
| Registro de auditoría redirigido | ubicación elegida por el operador | ≤ 30 días recomendado | manual, aprobado |

El borrado siempre lo decide y lo ejecuta una persona autorizada; ninguna herramienta de este repositorio borra evidencias. Antes de borrar, compruebe que ningún registro de gobierno o de piloto las referencia.

## Desinstalación

1. Retire la entrada del gateway de la configuración MCP de Claude Code.
2. Detenga cualquier proceso `mcp_gateway` en ejecución.
3. Elimine el checkout local y, si procede, los paquetes de evidencias y el registro de auditoría redirigido, con la aprobación descrita arriba.
4. No hay estado en el sistema (servicios, tareas programadas, registro de Windows ni variables de entorno) que limpiar: el E-Stack no instala nada fuera de su directorio.
