# Oracle Audit Diagnostic Model — Fase 8

## Principio

`security/audit-configuration` consolida el mecanismo de auditoría activo (Unified vs. Traditional) — nunca habilita/deshabilita políticas, nunca purga el audit trail.

## Unified Auditing (12.1+)

Verificado disponible desde 12.1 (WebFetch/WebSearch, `UNIFIED_AUDIT_TRAIL`/`AUDIT_UNIFIED_ENABLED_POLICIES`/`AUDIT_UNIFIED_POLICIES`). `security/unified-auditing` detecta disponibilidad, `enabled_mode` (`NONE|PURE_UNIFIED|MIXED|UNKNOWN`), políticas habilitadas, cobertura de actividad privilegiada. En 10g/11g, `capability_status: UNSUPPORTED` — Traditional Auditing es la única vía certificada.

## Traditional Auditing (todas las versiones)

`AUDIT_TRAIL` (parámetro: `NONE|OS|DB|DB_EXTENDED|XML|XML_EXTENDED`), `DBA_AUDIT_TRAIL`, `DBA_AUDIT_SESSION`. Certificado en todo el rango del catálogo (10g–23ai). `Q-SEC-TRADITIONAL-AUDIT-001` tiene variantes legacy (`ROWNUM`)/modern (`FETCH FIRST`) por sintaxis de row-limiting.

## Privileged audit visibility

`security/privileged-audit` evalúa visibilidad de operaciones SYS, uso de privilegio administrativo, logon/logoff, cambios de DDL/seguridad — sólo cuando la política del cliente lo requiere (`Target Profile.security.audit_requirements`). Nunca inventa política corporativa.

## Audit trail budget (`# 61` del prompt)

`UNIFIED_AUDIT_TRAIL`/`DBA_AUDIT_TRAIL` nunca se consultan completos — `Q-SEC-UNIFIED-AUDIT-TRAIL-001`/`Q-SEC-TRADITIONAL-AUDIT-001` usan binds obligatorios `:time_window_days`/`:max_rows`, filtrando por actividad privilegiada (`SYS`, `GRANT`/`REVOKE`, `CREATE/ALTER/DROP USER|ROLE`, `AUDIT`/`NOAUDIT`).

## Volume / retention

`security/audit-configuration` detecta `audit disabled`, `audit volume risk`, `trail saturation`, `retention unknown` — nunca purga el audit trail (`DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL` explícitamente prohibido).

## Prohibido

`AUDIT`/`NOAUDIT` (cualquier variante, unified o traditional) nunca ejecutados. Toda recomendación de política de auditoría se genera como `manual_action` con `execution_status: NOT_EXECUTED`.
