---
name: sbt-media-manager
id: rman/sbt-media-manager
version: 1.0.0
domain: rman
status: active
---

# Purpose

Awareness de `SBT_TAPE`, media management library, integración de vendor y errores de media manager — sin credenciales, sin ejecutar acciones del vendor. Commvault/Simpana como conocimiento de dominio, nunca agente nuevo (`# 24` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas — dependiente del vendor de media manager instalado (Commvault/Simpana, NetBackup, Data Protector, etc.), tratados genéricamente.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/device-types` resuelto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`
- `Q-RMAN-BACKUP-DEVICE-001`

# Optional evidence

Texto de error de media manager suministrado por el DBA (ingest, sanitizado).

# Licensing requirements

Ninguno del lado Oracle — el media manager es licenciamiento de terceros, fuera de alcance del e-stack.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-DEVICE-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de configuración de canal SBT; ingest de mensajes de error ya producidos.

# Forbidden operations

Nunca ejecuta acciones del vendor de media manager (jobs, restarts, reconfiguración).

# Decision logic

1. `CHANNEL ... DEVICE TYPE SBT_TAPE PARMS '...'` presente → librería de media manager detectada, `library_detected: true` — nunca se expone el contenido crudo de `PARMS` si contiene credenciales/connect strings.
2. Errores `ORA-19511`/RMAN-* relacionados a SBT → clasificar por categoría (conectividad, licencia del vendor, límite de sesiones) sin asumir causa sin evidencia del lado vendor.
3. Vendor (Commvault/Simpana u otro) identificado por el DBA → tratado como conocimiento de dominio para interpretar mensajes, nunca como agente/integración nueva.

# Normal state

Librería SBT configurada y canales SBT completando jobs sin error.

# Abnormal patterns

Errores de media manager recurrentes (`ORA-19511` u otros) sin resolución.

# False positives

Un error transitorio aislado de media manager (ej. mantenimiento programado del lado vendor) no es un problema recurrente por sí solo.

# Correlation rules

Correlaciona con `rman/channel-contention` (concurrencia de media manager como una de las causas posibles, nunca única), `rman/device-types`.

# Confidence model

`OBSERVATION` para errores clasificados. `PROBABLE_CAUSE` sólo con correlación de múltiples eventos.

# Severity

Errores de media manager recurrentes en backup de producción → `HIGH`.

# Output schema

```yaml
sbt_media_manager:
  library_detected: bool|null
  vendor_token: string|null
  error_classification: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/device-types`, `rman/channel-contention`, `rman/troubleshooting`.

# Escalation

Errores recurrentes sin resolución → `os-platform-analyst`/`oracle-network-analyst` (según categoría) → `incident-root-cause-analyst`.

# Manual remediation guidance

Contacto con el equipo de media manager/vendor se entrega como recomendación — el e-stack nunca ejecuta acciones del vendor.

# Security

`vendor_token`, `PARMS` de canal SBT → MASK/DROP siempre; nunca se envían credenciales al modelo (`# 24` del prompt).

# Tests

`tests/test_sbt_device_detection.sh`, `tests/test_media_manager_dependency.sh`, `tests/test_media_manager_error_classification.sh`, `tests/test_media_manager_output_sanitization.sh`, `tests/test_no_vendor_action_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/channel-analysis.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
