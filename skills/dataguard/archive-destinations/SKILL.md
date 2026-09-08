---
name: archive-destinations
id: dataguard/archive-destinations
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Extraer de forma segura la configuración declarada de `LOG_ARCHIVE_DEST_n`/`LOG_ARCHIVE_DEST_STATE_n`: `SERVICE`, `SYNC`/`ASYNC`, `AFFIRM`/`NOAFFIRM`, `VALID_FOR`, `DB_UNIQUE_NAME`, `NET_TIMEOUT`, `REOPEN`, `MAX_FAILURE`, alternate awareness — según versión, sin imprimir secretos ni connect descriptors completos cuando la política lo prohíba (`# 33` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai. Propiedades adicionales (`MAX_FAILURE`, `NET_TIMEOUT` moderno) varían por versión — documentadas en `docs/DATAGUARD_READONLY_QUERIES.md`.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY (foco); aplica igual a cualquier destino remoto.

# Prerequisites

`dataguard/transport` resuelto (esta skill provee la configuración declarada; `dataguard/transport` provee el estado runtime).

# Required evidence

- `Q-DG-DEST-001` (`V$ARCHIVE_DEST`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-DEST-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$ARCHIVE_DEST`.

# Forbidden operations

No modifica ninguna propiedad de destino.

# Decision logic

1. Extraer las propiedades declaradas por destino, sanitizando `SERVICE`/connect descriptor según `sanitizers/data-classification-policy.md`.
2. Nunca exponer credenciales embebidas en el connect descriptor — bloqueado por el sanitizer antes de llegar al modelo.
3. Publicar la configuración para que `dataguard/transport` la use en su análisis de estado runtime.

# Normal state

Configuración declarada consistente con la topología esperada (`dataguard/topology`).

# Abnormal patterns

Destino declarado sin `VALID_FOR` coherente con el rol actual de la base; `MAX_FAILURE` bajo en un ambiente con problemas de red conocidos (candidato a discusión, nunca a cambio automático).

# False positives

Ninguno específico — este skill es puramente de visibilidad de configuración.

# Correlation rules

Alimenta `dataguard/transport` con la configuración declarada; correlaciona con `dataguard/configuration-drift` para comparar entre nodos RAC del mismo sitio.

# Confidence model

`FACT` para toda propiedad leída directamente.

# Severity

N/A propio — la severidad la determina `dataguard/transport` con el estado runtime.

# Output schema

```yaml
findings:
  - destination: string      # MASK
    service: string          # MASK — connect descriptor sanitizado
    mode: SYNC|ASYNC
    affirm: bool
    valid_for: string
    db_unique_name: string    # MASK
    net_timeout: number|null
    reopen: number|null
    max_failure: number|null
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/transport`, `dataguard/configuration-drift`.

# Escalation

Ninguna propia.

# Manual remediation guidance

Cambio de cualquier propiedad de destino es `manual_action`.

# Security

`SERVICE`/connect descriptors siempre enmascarados; credenciales embebidas bloqueadas por el sanitizer, nunca enviadas al modelo (`# 33`, `# 52`).

# Tests

`tests/test_destination_configuration.sh`, `tests/test_no_secrets.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_archive_dest_modify.sh`.

# Documentation requirements

Alimenta `transport-analysis.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
