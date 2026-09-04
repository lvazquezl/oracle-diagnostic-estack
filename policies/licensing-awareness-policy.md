# Licensing Awareness Policy

## Regla

Ninguna recomendación asume licencia disponible. Antes de recomendar el uso o profundizar en una feature potencialmente sujeta a licenciamiento Oracle, el hallazgo/recomendación se marca `license_check_required: true` y, si la capability queda efectivamente bloqueada por no poder confirmarse la licencia, el estado formal es `LICENSE_RESTRICTED` (ver `docs/CONTRACTS.md#capability-status-model`, `policies/capability-degradation-policy.md`).

## Licensing como gate explícito (Foundation Hardening)

Toda capability pasa por esta secuencia, en orden, antes de recolectar evidencia:

```text
Capability requested
        ↓
Version check            (¿la versión Oracle soporta esto? → core/version-awareness)
        ↓
Architecture check        (¿RAC/CDB/rol aplican? → container_scope / database_role_scope)
        ↓
Capability support         (config/capability-matrix.yaml → SUPPORTED/PARTIAL/UNSUPPORTED/...)
        ↓
License check               (¿depende de una feature de la lista abajo? ¿se puede confirmar?)
        ↓
Privilege check               (¿ESTACK_DIAGNOSTIC_ROLE alcanza?)
        ↓
Security policy                 (policies/forbidden-operations.md, policies/identity-model.md)
        ↓
Cost policy                       (policies/query-cost-policy.md → cost_class permitido en este workflow)
        ↓
Evidence collection
```

Si cualquier paso falla, el resultado es el `capability_status` correspondiente (`UNSUPPORTED`, `LICENSE_RESTRICTED`, `INSUFFICIENT_PRIVILEGES`, `POLICY_BLOCKED`, etc.) — nunca un fallo silencioso ni una recolección que ignore el paso fallido.

## Features típicamente sujetas a licenciamiento adicional

- **Diagnostics Pack**: AWR, ASH (`V$ACTIVE_SESSION_HISTORY` histórico vía `DBA_HIST_ACTIVE_SESS_HISTORY`), ADDM.
- **Tuning Pack**: SQL Tuning Advisor, SQL Access Advisor.
- **Real Application Testing** (SQL Performance Analyzer, Database Replay).
- **Active Data Guard** (lectura en standby, `real-time query`).
- **Real Application Clusters (RAC)** — la topología en sí puede estar cubierta según el acuerdo, pero ciertas features (ej. RAC One Node en algunos acuerdos) no.
- **Multitenant** — más de una PDB por CDB en ediciones que lo limitan.
- **Advanced Security** (TDE, network encryption avanzado), **Database Vault**, Label Security, Unified Audit avanzado.
- **Partitioning**, In-Memory, **Advanced Compression**.

Cuando un agente detecta uso o necesidad de alguna de estas, marca el finding/recomendación correspondiente en vez de asumir que está cubierto.

## Alternativa cuando la licencia no se puede confirmar

Si una capability queda `LICENSE_RESTRICTED`, el skill/agente busca una ruta alternativa no licenciada cuando existe, y la declara explícitamente en `alternative` (ver `policies/capability-degradation-policy.md`). Ejemplo ya implementado en el catálogo (`skills/performance/wait-events/SKILL.md`):

```text
AWR unavailable/restricted → considerar Statspack o vistas dinámicas de performance (V$SYSTEM_EVENT)
```

Si no existe alternativa razonable, el hallazgo se reporta como `LICENSE_RESTRICTED` con `required_action: LICENSE_CHECK_REQUIRED` y el análisis continúa con el resto de la evidencia disponible — nunca se bloquea el análisis completo por una sola capability restringida.

## Prioridad de fuentes (nunca se inventan)

1. Evidencia directa del ambiente (ej. `V$OPTION`, `DBA_FEATURE_USAGE_STATISTICS` — sólo lectura, para saber qué está *en uso*, no para determinar si está *licenciado*: eso es una decisión contractual del cliente).
2. Documentación Oracle oficial.
3. Oracle Support / MOS — disponible al DBA humano, nunca fabricado por el e-stack.
4. Documentación oficial del OS/vendor.
5. Knowledge base interna validada (`knowledge/`).
6. Fuentes externas — última prioridad, siempre citadas explícitamente si se usan.

## Prohibiciones explícitas

- Nunca se inventa un número de MOS Note.
- Nunca se afirma "esto está incluido en tu licencia" — el e-stack no tiene visibilidad del contrato de licenciamiento del cliente.
- El hallazgo se limita a: "esta feature parece estar en uso/recomendada; `LICENSE_CHECK_REQUIRED` antes de proceder."

## Referencia

`SECURITY.md#licensing-awareness`, `docs/CONTRACTS.md#capability-status-model`, `policies/capability-degradation-policy.md`, `docs/CAPABILITY_MATRIX.md` (columna `LICENSE_DEPENDENT`), agentes `oracle-performance-analyst`, `oracle-multitenant-analyst`, `oracle-dataguard-analyst`, `oracle-security-analyst`, `change-advisor`.
