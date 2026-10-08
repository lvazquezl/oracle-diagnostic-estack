---
name: assessment
version: 1.1.0
status: active
---

# Trigger/intent

Comando `/assessment`. Evaluación integral y más profunda que un healthcheck — típicamente para onboarding de un ambiente nuevo, auditoría periódica, o antes de un cambio mayor. `/assessment rac` (Fase 4) acota el alcance a `rac/assessment` — arquitectura, versiones, nodos/instancias/servicios, load-balancing, SCAN, listeners, interconnect, resumen ASM, hallazgos de configuración, riesgos y recomendaciones (`# 42` del prompt de Fase 4). `/assessment dataguard` (Fase 5) acota el alcance a `dataguard/assessment` — arquitectura, roles, versiones, protección, transporte, apply, lag, gaps, SRL, Broker, FSFO, dependencias de red/RAC/storage, riesgos, recomendaciones, readiness (`# 47` del prompt de Fase 5). `/assessment multitenant` (Fase 6) acota el alcance a `multitenant/assessment` — arquitectura, versión, estado CDB, inventario PDB, open modes, servicios, RAC placement, storage, TEMP/UNDO, parameter scope, componentes, plug-in violations, Resource Manager, lockdown profiles, riesgos y recomendaciones (`# 42` del prompt de Fase 6). `/assessment backup-recovery` (Fase 7) acota el alcance a `oracle-backup-recovery-analyst` — configuración RMAN, inventario/estado/frescura de backups, retención, FRA, canales/SBT, restore/recovery readiness, PITR/PDB PITR awareness, riesgos y recomendaciones (`# 39` del prompt de Fase 7). `/assessment security` (Fase 8) acota el alcance a `oracle-security-analyst` — executive summary, scope, account posture, privilege posture, password/profile posture, password-strength policy posture, audit posture, encryption posture, network-security posture, compliance mapping, critical findings, high-risk privilege concentrations, licensing notes, manual recommendations, evidence manifest (`# 50` del prompt de Fase 8). `/assessment os-platform` (Fase 9) acota el alcance a `os-platform-analyst` — plataforma/distribución/kernel, CPU/NUMA, memoria/swap, HugePages/THP, límites/IPC/AIO, filesystems/inodes/dispositivos de bloque/multipath, red/bonding/VLAN/MTU/routing/DNS, time sync, SSH/SSHD posture, grupos/procesos Oracle/Grid, integración RAC/Data Guard/RMAN/Security por referencia, Health Model de 25 dimensiones, manual hardening plan, riesgos y recomendaciones. `/assessment capacity --period quarterly|semiannual` (Fase 10) acota el alcance a `capacity-analyst` — source inventory, data quality, Common Metric Model (CPU/memoria/storage transversal Oracle/Linux/Windows/SQL Server/VMware), capacidad Oracle/ASM/tablespace/FRA por referencia, análisis horizontal/vertical, trend analysis, forecasting 1/3/6 meses con confidence, threshold crossing, capacity change events, source reconciliation, risk (siempre con confidence), resumen ejecutivo, manual capacity plan — `--period` determina la ventana de comparación para change detection frente al assessment previo, nunca altera la metodología de cálculo (`# 1926`-`# 1936` del prompt de Fase 10).

# Prerequisites

Target identificado; ventana de tiempo disponible mayor que un healthcheck (assessment es intencionalmente más costoso).

# Discovery requirements

`oracle-discovery-analyst` obligatorio siempre (no se reutiliza cache más allá de la sesión, para garantizar una foto actual completa).

# Minimum agents

`oracle-operations-orchestrator`, `oracle-discovery-analyst`, `oracle-dba-analyst`, `oracle-performance-analyst`, `oracle-security-analyst`, `capacity-analyst`.

# Optional agents

`oracle-rac-analyst`, `oracle-asm-storage-analyst`, `oracle-dataguard-analyst`, `oracle-multitenant-analyst`, `oracle-backup-recovery-analyst`, `oracle-security-analyst`, `oracle-network-analyst`, `os-platform-analyst` — activados según topología detectada (misma lógica que `healthcheck.md#activation-conditions`), pero en `assessment` se activan **todos** los que apliquen a la topología, no sólo bajo demanda.

# Activation conditions

Idénticas a `healthcheck.md`, con la diferencia de que un assessment activa automáticamente todo agente cuya "Activation condition" se cumpla (no requiere que el DBA lo pida explícitamente), porque el objetivo es cobertura integral.

# Skills

Todos los skills `active` de los dominios cuyos agentes se activaron, más `capacity/forecasting` siempre (assessment incluye forecast por defecto — `capacity/forecast` de Foundation fue absorbido en `capacity/forecasting` en Fase 10, ver `skills/REGISTRY.md#capacity-28`).

# Evidence required

Todas las queries certificadas relevantes a los dominios activados, con ventanas de tiempo más amplias que `healthcheck` (hasta el máximo de `policies/rate-limiting-policy.md`).

**Reloj y alcance (CHG-ESTACK-ASSESSMENT-ACCURACY-001).**
- **Reloj:** el discovery incluye `Q-DISC-CLOCK-001`. Si el gateway marca `CLOCK_SKEW` (desfase > 300 s entre el reloj del host de la base y el del gateway), todo "horas desde…" calculado en la base se reporta con esa limitación y la causa se deriva a `os-platform-analyst` (sincronización de tiempo).
- **Alcance multitenant:** en CDB, `Q-CDB-CONTAINER-DATA-001` declara qué contenedores alcanzan las vistas `CDB_*` y las `V$` filtradas por `CONTAINER_DATA`.

# Stop conditions

Igual que `healthcheck.md`. Adicionalmente: si un dominio activo (ej. RAC) no puede completarse por falta de acceso, el assessment continúa con el resto de dominios y declara ese dominio `UNDETERMINED` explícitamente, en vez de abortar completo.

# Confidence threshold

Igual que `healthcheck.md`, con exigencia adicional de que `recommendations` de un assessment prioricen por severidad y por riesgo de capacidad a 1/3/6 meses.

# Escalation

Cualquier hallazgo `HIGH` activa `incident-root-cause-analyst` si hay indicios de estar activo, o `change-advisor` si es puramente una recomendación de mejora.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` completo, más `recommendations.md` extendido con matriz de riesgo. Base típica para `/document assessment --format pptx` (executive assessment).

**Revisión por especialistas (paso fijo, CHG-ESTACK-ASSESSMENT-ACCURACY-001).** Antes de cerrar el análisis, el orquestador revisa el informe actuando como cada agente especialista activado (roles en el mismo contexto, con Task Package; no se abren sesiones de modelo aparte). Como mínimo, revisan el dominio con el hallazgo de mayor severidad, `oracle-discovery-analyst` (alcance y confianza del contexto) y `technical-documentation-manager` (contrato, trazabilidad, conteos).

Cada revisor:
- contrasta cada cifra con la evidencia saneada (`diagnostics.get_evidence`), sin recolectar de nuevo;
- marca como error toda afirmación fuera del alcance observado (contenedor, ventana, top-N), toda confianza mayor que la evidencia y toda recomendación que pida una vía inexistente (query no certificada o inactiva, comandos del SO por la ruta humana);
- emite `ADECUADO | ADECUADO_CON_CAMBIOS | INADECUADO`.

Las correcciones producen la revisión 2 del análisis, con la sección "Revisión por especialistas" en `analysis.md`. Antecedente: en `ANA-20261007-001` y `ANA-20261008-001` la revisión encontró errores reales en el 100 % de los informes consolidados.

# Token/context budget

Alto — es el workflow más costoso en cobertura; se gestiona activando agentes en paralelo con Task Packages independientes, nunca un contexto monolítico.

# Security constraints

READ-ONLY ALWAYS. Identidad `ESTACK_DIAG_*`. Ventanas más amplias de evidencia respetan igual los límites de `policies/rate-limiting-policy.md` (no hay excepción por ser assessment).

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml evaluado por cada dominio candidato; dominios UNSUPPORTED/PLANNED para esta versión no se activan (se reportan como tal, no se omiten silenciosamente)
  architecture: cada agente opcional se activa sólo si su Activation condition se cumple (misma lógica que healthcheck.md, pero aplicada exhaustivamente)
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      dominios LICENSE_DEPENDENT (AWR/ASH/ADDM, Active Data Guard, multi-PDB) se marcan LICENSE_RESTRICTED si no se confirma licencia; el assessment continúa con el resto
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para cada dominio activado; si no, ese dominio queda INSUFFICIENT_PRIVILEGES
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         queries cost_class HIGH permitidas (ventana amplia es esperada en assessment), siempre con timeout/max_rows reforzados
  evidence:     assessment fuerza discovery nuevo (no reutiliza cache) para garantizar una foto actual completa
  capacity:     capacity-analyst opera en modo --period quarterly|semiannual; source_priority/thresholds no declarados en target_profile.capacity degradan a SOURCE_CONFLICT/INSUFFICIENT_POLICY explícitos, nunca bloquean el resto del assessment; forecast nunca se produce desde historia insuficiente sin limitación explícita
```
