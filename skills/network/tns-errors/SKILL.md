---
name: tns-errors
id: network/tns-errors
version: 1.0.0
domain: network
status: active
---

# Purpose

Aplicar la taxonomía certificada de `knowledge/errors/tns/` (y `knowledge/errors/ora/` para `ORA-3136`) — códigos `TNS-12541`, `TNS-12537`, `TNS-12170`, `TNS-01199`, `ORA-3136` — a un error reportado, clasificando el dominio probable sin adivinar (`# 32`, `# 51`, `# 52` del prompt de Fase 4).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno — puede invocarse directamente con sólo el código de error como insumo.

# Required evidence

Ninguna propia — consulta `knowledge/errors/tns/`/`knowledge/errors/ora/` y delega la verificación a `network/connection-path`.

# Optional evidence

- Evidencia de `network/listeners`/`network/scan-resolution` si están disponibles en la sesión.

# Read-only operations

Ninguna propia.

# Forbidden operations

Ninguna acción — es puramente de clasificación.

# Decision logic

1. Buscar el código de error en `knowledge/errors/tns/`/`knowledge/errors/ora/`.
2. Aplicar el patrón de correlación certificado (ej. `TNS-12537` → no reducir automáticamente a listener; solicitar evidencia de los 6 dominios posibles: listener/red, exhaustion de recursos, límites OS, cliente/aplicación, dispositivo intermedio, terminación de proceso Oracle).
3. Si no hay evidencia suficiente para descartar dominios, reportar `INSUFFICIENT_EVIDENCE` explícitamente.

# Confidence model

`HYPOTHESIS` para clasificación de dominio con 1 señal. `PROBABLE_CAUSE` con 2+. `INSUFFICIENT_EVIDENCE` cuando no hay suficiente correlación.

# Output schema

```yaml
findings:
  - error_code: string
    domain_classification: string
    confidence: HYPOTHESIS|PROBABLE_CAUSE|INSUFFICIENT_EVIDENCE
    evidence_refs: [EVD-...]
```

# Related skills

`network/connection-path`, `network/timeouts`.

# Escalation

Correlacionable con múltiples dominios (red + aplicación) → `incident-root-cause-analyst`.

# Data sensitivity

Media.

# Context budget

Bajo — la taxonomía es texto compacto, no evidencia cruda.

# Tests

`tests/test_tns_12541_path.sh`, `tests/test_tns_12537_path.sh`, `tests/test_tns_12170_path.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

Nuevos códigos de error vía `/change knowledge`.
