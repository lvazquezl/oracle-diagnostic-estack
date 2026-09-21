# MCP Diagnostic Gateway (local) — diseño

Estado: el diseño de la Fase 1 sigue vigente. La **Fase 13** entrega un servidor MCP local real por stdio (`python -m mcp_gateway`, ver [`docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md`](../docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md)) con datos **sintéticos de fixture**; los adaptadores contra Oracle/OS reales están `DISABLED` o `CONTRACT_ONLY` y `NOT_INTEGRATION_TESTED` hasta que un humano apruebe un laboratorio.

## Principio

No se expone SQL ni shell arbitrario al modelo. Sólo tools semánticas, parametrizadas, certificadas (`queries/REGISTRY.md`).

## Posición en la arquitectura

```
Claude (modelo)
  → MCP Diagnostic Gateway (este componente, LOCAL)
    → Security/Data Sanitization Layer (sanitizers/)
      → Certified Read-Only Collectors (collectors/)
        → Oracle / RAC / GI / ASM / Data Guard / OS
```

## Responsabilidades del Gateway

1. Exponer únicamente las tools declaradas en [`tool-manifest.md`](tool-manifest.md).
2. Validar que cada invocación tenga parámetros dentro de los límites certificados (`timeout`, `max_rows` del `queries/REGISTRY.md`).
3. Enrutar la invocación al collector certificado correspondiente (`collectors/`), nunca a un canal de ejecución libre.
4. Pasar el resultado crudo por el Sanitizer local (`sanitizers/`) antes de devolverlo a quien invocó la tool.
5. Aplicar rate limiting y control de concurrencia por identidad `ESTACK_DIAG_*` (ver `policies/rate-limiting-policy.md`).
6. Registrar auditoría local de cada invocación (tool, target, timestamp, resultado — sin contenido sensible) para trazabilidad.

## Qué el Gateway NUNCA expone

- `execute_sql(sql: string)` genérico.
- `execute_shell(cmd: string)` genérico.
- Cualquier tool cuyo verbo subyacente sea de escritura (`srvctl start/stop/modify`, `crsctl modify/start/stop`, `systemctl start/stop/restart`, `ALTER/CREATE/DROP/DML`, operaciones ASM de escritura, switchover/failover, restore/recover).

Ver `tests/test_no_write_operations.*`, que valida estáticamente que `tool-manifest.md` no declare ninguna tool con esos verbos.

## Certificación de una nueva tool

Toda tool nueva nace en `queries/REGISTRY.md` como propuesta vía `/change query`, pasa por `estack-evolution-architect` (gap/impact analysis, implementación, tests, `oracle-security-analyst` SECURITY VALIDATION) y sólo se agrega a `tool-manifest.md` tras HUMAN REVIEW.

## Configuración local

`config/estack.config.example.yaml` define el endpoint local del Gateway (siempre `localhost`, nunca expuesto a red), timeouts globales por defecto, y el directorio de auditoría local.

## Implementación local (Fase 13)

- Código: `mcp_gateway/` (Python stdlib, sin dependencias de red). Transporte: JSON-RPC 2.0 por stdio; `stdout` sólo protocolo, `stderr` auditoría sanitizada.
- Cinco tools semánticas y estáticas: `diagnostics.list_capabilities`, `diagnostics.describe_collector`, `diagnostics.collect`, `diagnostics.get_evidence`, `diagnostics.analyze_incident`. Esquemas cerrados; ningún parámetro admite SQL, comandos, rutas, URL ni datos de conexión.
- Adaptadores: `fixture` (`VERIFIED_FIXTURE`, único habilitado), `oracle_sql` (`DISABLED`), `oracle_diag_file` y `os_readonly` (`CONTRACT_ONLY`).
- Configuración de ejemplo para Claude Code, sin credenciales: [`claude-code.mcp.example.json`](claude-code.mcp.example.json) (cópiela usted mismo; el repositorio no modifica su configuración).
- «MCP local» no equivale a «modelo local»: la evidencia saneada que recibe el cliente puede salir del equipo según el producto que la consuma.
- Pruebas: `tests/test_p13_*.sh` y, desde la Fase 14, `tests/test_p14_*.sh`.
- Límites opcionales (sólo a la baja; fuera de rango el arranque se rechaza): `--operation-timeout`, `--max-session-calls`, `--max-rows`, `--max-message-bytes`. Operación, logging, recuperación y retención: [`docs/OPERATIONS_RUNBOOK.md`](../docs/OPERATIONS_RUNBOOK.md).
