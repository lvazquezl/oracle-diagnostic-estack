---
name: connection-path
id: network/connection-path
version: 1.0.0
domain: network
status: active
---

# Purpose

Analizar el connect descriptor completo del cliente (SCAN/host, puerto, service_name) frente a la topología real, clasificando el punto probable de falla sin adivinar a ciegas.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`network/scan-resolution` (si RAC) y `network/service-registration` resueltos.

# Required evidence

- Evidencia agregada de `network/listeners`, `network/service-registration`, `network/scan-resolution`.

# Optional evidence

- collector `get_name_resolution` para el path de resolución específico usado por el cliente.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No modifica el connect descriptor del cliente ni la configuración de red.

# Decision logic

1. Verificar en orden: resolución de nombre → listener alcanzable → servicio registrado → handler disponible.
2. Clasificar el punto de falla más probable: `NAME_RESOLUTION|LISTENER|NETWORK_PATH|FIREWALL_SUSPECTED|CLIENT_APPLICATION|RESOURCE_EXHAUSTION|INSUFFICIENT_EVIDENCE`.
3. `FIREWALL_SUSPECTED` sólo se reporta cuando las etapas anteriores están confirmadas correctas y no hay otra explicación disponible — nunca como primera hipótesis (`# 51` del prompt de Fase 4).

# Confidence model

`FACT` para cada etapa verificada directamente. `HYPOTHESIS` para la clasificación del punto de falla con 1 señal. `PROBABLE_CAUSE` con 2+ etapas descartadas.

# Output schema

```yaml
findings:
  - classification: NAME_RESOLUTION|LISTENER|NETWORK_PATH|FIREWALL_SUSPECTED|CLIENT_APPLICATION|RESOURCE_EXHAUSTION|INSUFFICIENT_EVIDENCE
    confidence: HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`network/scan-resolution`, `network/service-registration`, `network/tns-errors`.

# Escalation

`FIREWALL_SUSPECTED`/`NETWORK_PATH` → recomendación manual al equipo de red, nunca confirmado sin evidencia directa de captura de tráfico (fuera de alcance de este stack).

# Data sensitivity

Media-alta — todo el connect descriptor se enmascara por defecto.

# Context budget

Media.

# Tests

`tests/test_tns_12541_path.sh`, `tests/test_tns_12537_path.sh`, `tests/test_tns_12170_path.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

Nuevas etapas de verificación vía `/change query`.
