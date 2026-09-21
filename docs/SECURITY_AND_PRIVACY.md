# Security and Privacy — modelo de amenazas de producción, flujo de evidencia y privacidad

Actualiza el modelo de amenazas de las Fases 11–13 para el conjunto **gateway MCP local + herramientas de release**. Complementa [`SECURITY.md`](../SECURITY.md) y [`PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md`](PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md). Estado real: sólo se ejecutan fixtures sintéticos; los adaptadores reales están `DISABLED`/`CONTRACT_ONLY` ([`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md)).

> READ-ONLY ALWAYS. Ninguna herramienta de este repositorio escribe en Oracle, ejecuta SQL o shell arbitrarios, usa `SYSDBA`/`SYSASM`/root/sudo, abre puertos ni envía telemetría.

## Modelo de amenazas

**Activos:** integridad de los sistemas administrados (nada se cambia), confidencialidad de datos e identificadores, integridad de las conclusiones (RCA, asesoría) y de la evidencia de release, disponibilidad del proceso local.
**Actores:** el modelo (puede ser manipulado por datos), datos no confiables (logs, alertas, filas, documentos, nombres), un usuario o proceso local malicioso del mismo host, configuración o archivos alterados.

| Amenaza | Control | Prueba |
|---|---|---|
| Invocaciones MCP con SQL, comandos, rutas, URL o conexión | herramientas estáticas con esquemas cerrados (`additionalProperties:false`); ningún parámetro admite esos valores; el gate lo verifica por stdio real | `test_p13_security.sh`, `test_p14_release_gate.sh` |
| Ampliar el conjunto de herramientas mediante nombres/argumentos | registro estático; herramienta desconocida → error fijo; `tools/list` antes de `initialize` rechazado; `resources/*` y `prompts/*` inexistentes | `test_p14_security_threat_model.sh` |
| Prompt injection en logs/alertas/documentos | el texto libre es `DROP` (no tiene camino al modelo); las firmas desconocidas se tokenizan; los datos nunca cambian catálogo ni política | `test_p13_sanitization.sh`, `test_p14_security_threat_model.sh` |
| Inyección/traversal de rutas, symlinks, TOCTOU | gramática estricta de identificadores + `confine()` que rechaza `..` y enlaces en **cada** lectura; el fixture reemplazado por un enlace tras el arranque se deniega | `test_p14_security_threat_model.sh` |
| JSON desmesurado, anidado o ancho; flood de mensajes | límites de bytes, profundidad y nodos; línea sobredimensionada descartada sin almacenarla; llamadas por sesión acotadas; procesamiento secuencial | `test_p13_mcp_protocol.sh`, `test_p14_operability.sh` |
| Agotamiento de recursos por un adaptador lento | plazo duro por operación (`E_TIMEOUT`) sin bloquear el bucle; sin reintentos | `test_p14_operability.sh` |
| Secretos en cualquier campo, subcampo, firma, clave, error o log | política por campo con denegación por defecto; auditoría estructurada final; mensajes de error fijos; registro de auditoría sin argumentos | `test_p13_sanitization.sh` |
| Variables de entorno, subprocess, red | el gateway no lee el entorno, no importa `subprocess`/`socket`/red y no evalúa código; el gate lo comprueba con un **escaneo AST** de todos los paquetes; ejecución con sockets bloqueados | `test_p14_security_threat_model.sh`, `test_p14_packaging_reproducibility.sh` |
| Habilitar un adaptador real por flag, variable o archivo | no existe el camino; un adaptador no verificado nunca se ejecuta; el registro rechaza estados sin evidencia | `test_p14_inventory_registry.sh` |
| Compatibilidad asumida (`latest`, versiones lexicográficas, metadatos ausentes) | resolución numérica de versiones; metadatos ausentes ⇒ cero versiones soportadas | `test_p14_inventory_registry.sh` |
| Evidencia de release alterada, truncada o de otro árbol | verificador independiente con hashes, fingerprint antes/después, re-derivación del veredicto y de los conteos | `test_p14_release_gate.sh` |
| Fuga de rutas personales o secretos en informes | redacción de rutas + auditoría estructurada antes de emitir; un log con contenido tipo secreto se **retiene** | `test_p14_evidence_packager.sh`, `test_p14_security_threat_model.sh` |
| Herramientas de release que modifican Git | `release_readiness` sólo ejecuta subcomandos de Git de lectura (lista permitida) y el runner del repositorio; no hay commit, merge, push ni tag | `test_p14_evidence_packager.sh` |
| Defensas desactivadas en silencio | controles de mutación: al desactivar cada defensa, la prueba que la protege debe fallar | `test_p14_mutation_controls.sh` |

## Flujo de evidencia

```text
fuente (fixture hoy; adaptador real en el futuro)
  → filas NO confiables
  → validación de forma (fail closed)
  → política por campo KEEP / MASK / HASH / TOKENIZE / DROP (denegar por defecto)
  → minimización → digest → referencia opaca EVR-… atada a sesión y destino
  → auditoría estructurada final
  → modelo (nunca datos crudos)
  → RCA (Fase 11) → asesoría/documentos/candidato KB (Fase 12)  [sin ejecutar, sin aprobar, sin publicar]
```

Trazabilidad: `INC → EVD → FND → HYP → RCA → REC → CHG` con estados de incertidumbre preservados; una hipótesis inconclusa nunca se eleva a hecho, y una correlación temporal no es causalidad. La evidencia cruda no se almacena, no se modifica y no se entrega al modelo.

## Frontera de confianza

| Qué protege el acceso | Cómo |
|---|---|
| Al proceso y a los archivos | la **cuenta del sistema operativo** y los permisos del host: quien puede ejecutar `python -m mcp_gateway` con esa cuenta habla con el gateway |
| A los datos administrados | no se accede a ellos hoy; un adaptador real futuro exigirá una cuenta de diagnóstico de sólo lectura y mínimo privilegio, gestionada **fuera** del E-Stack |
| A la evidencia de release | directorio fuera del repositorio con permisos restringidos + hashes (integridad, no autenticidad) |

**Qué no está cubierto (declarado, no oculto):**

- stdio local **no autentica a la persona**: no hay identidad del solicitante ni autorización por usuario;
- una **aprobación estructural local no es firma, autenticación ni verificación de identidad**: las aprobaciones se registran como `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`; la aprobación externa requerida es la revisión humana en Git por personas identificadas y, si la organización lo exige, su sistema de cambios;
- un host comprometido, otro proceso con la misma cuenta o credenciales externas quedan fuera del alcance;
- el E-Stack no introduce telemetría remota, envío de datos ni dependencias externas.

## Retención y privacidad

- **Minimización:** el modelo sólo recibe evidencia saneada y acotada; los identificadores salen como alias/tokens con sal **por sesión** (no correlacionan entre sesiones).
- **Raw:** nunca se almacena en el gateway ni se entrega por MCP.
- **Retención:** evidencia del gateway en memoria (TTL 1 h, máximo 300 entradas); paquetes de evidencias y logs según [`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md#retención-y-borrado); borrado siempre manual y aprobado.
- **Privacidad de los artefactos:** ningún informe, log publicado ni manifiesto contiene rutas personales absolutas (se reemplazan por `<REPO_ROOT>`/`<USER_HOME>`), secretos ni datos de negocio; el log crudo se conserva aparte, fuera del paquete.
- **MCP local ≠ modelo local:** la evidencia saneada que recibe el cliente puede procesarse fuera del equipo según el producto; por eso se minimiza antes de salir.

## Riesgos residuales

Registro completo, con responsable por rol y condición de cierre: [`config/governance/risk-register.json`](../config/governance/risk-register.json) (validado por `python -m release_readiness governance-check`).

| ID | Riesgo | Rol responsable |
|---|---|---|
| RSK-001 | No existen adaptadores reales certificados | estack-maintainer |
| RSK-002 | stdio local no autentica a la persona | security-reviewer |
| RSK-003 | Las aprobaciones son declaraciones estructurales | release-manager |
| RSK-004 | La sanitización es heurística | security-reviewer |
| RSK-005 | MCP local no es modelo local | security-reviewer |
| RSK-006 | La evidencia prueba integridad, no autenticidad | release-manager |
| RSK-007 | Sólo se validó Windows con Git Bash | estack-maintainer |
| RSK-008 | El SQL certificado nunca se ejecutó contra una base real | dba-lead |
| RSK-009 | Los fixtures pueden divergir de las salidas reales | estack-maintainer |

Límite conocido de la defensa contra TOCTOU: cada lectura de fixture se confina y verifica en el momento del acceso, pero entre la verificación y la apertura existe una ventana que un proceso local con permisos de escritura sobre el directorio podría aprovechar; la mitigación es no compartir ese directorio (véase la frontera de confianza).
