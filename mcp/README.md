# MCP Diagnostic Gateway (local) — diseño

Estado en Fase 1: **diseño y tool manifest**. La implementación ejecutable (servidor MCP real conectando a Oracle/OS) es Fase 7.

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
