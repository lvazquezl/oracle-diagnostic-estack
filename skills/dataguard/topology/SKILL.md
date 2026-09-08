---
name: topology
id: dataguard/topology
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Construir el modelo estructurado de configuración Data Guard (`configuration`, `primary`, `standbys`, `protection_mode`, `broker_enabled`, `fsfo_enabled`) — la base sobre la que se apoyan el resto de skills Data Guard de la sesión (`# 10` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC en cualquiera de los sitios. NON-CDB y CDB (Data Guard a nivel CDB completo, nunca por PDB individual).

# Prerequisites

Target Profile con `dataguard.enabled = true`.

# Required evidence

- `Q-DG-ROLE-001` (`V$DATABASE`: `DB_UNIQUE_NAME`, `DATABASE_ROLE`)

# Optional evidence

- collector `get_dataguard_configuration` (`SHOW CONFIGURATION`, cuando Broker está habilitado) — confirma miembros de la configuración de forma más completa que sólo `V$DATABASE`.

# Read-only operations

Lectura de `V$DATABASE` y, cuando corresponde, salida estructurada de `SHOW CONFIGURATION`.

# Forbidden operations

No agrega/quita miembros de la configuración Data Guard.

# Decision logic

1. Identificar el primary (`DATABASE_ROLE = PRIMARY`) y el/los standby(s) conocido(s).
2. Si el sitio primary o algún standby es RAC (`target_profile.rac.enabled`), modelar a nivel de base de datos, no de instancia — el rol es de la base lógica completa (`# 10`, `# 16`).
3. Publicar la topología para que el resto de skills Data Guard la reutilicen sin recalcularla.

# Normal state

Primary con `DATABASE_ROLE = PRIMARY`, uno o más standbys con roles reportados consistentemente (`PHYSICAL STANDBY`/`LOGICAL STANDBY`/`SNAPSHOT STANDBY`), configuración Broker (si habilitada) coincidente con lo observado vía SQL.

# Abnormal patterns

Standby conocido en Target Profile ausente de la configuración Broker; roles inconsistentes entre `V$DATABASE` y `SHOW CONFIGURATION`.

# False positives

Un standby deliberadamente removido de Broker temporalmente (mantenimiento) no es necesariamente un error — correlacionar con ventana de mantenimiento conocida antes de escalar.

# Correlation rules

Cruza con `dataguard/broker` cuando Broker está habilitado — nunca determina topología dos veces.

# Confidence model

`FACT` para roles/topología leídos directamente.

# Severity

Discrepancia de topología entre SQL y Broker → `MEDIUM`; standby crítico ausente inesperadamente → `HIGH`.

# Output schema

```yaml
findings:
  - configuration_name: string
    primary: {db_unique_name: string, role: string}
    standbys: [{db_unique_name: string, role: string}]
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/role`, `dataguard/broker`, `dataguard/configuration-drift`.

# Escalation

Standby crítico ausente sin explicación → `incident-root-cause-analyst`.

# Manual remediation guidance

Ninguna acción ejecutable — cualquier cambio de topología (agregar/quitar standby) es `manual_action`.

# Security

Identidad `ESTACK_DIAG_*` en ambos sitios. `db_unique_name`/hostnames enmascarados por defecto.

# Tests

`tests/test_dataguard_role_query.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `dataguard-topology.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
