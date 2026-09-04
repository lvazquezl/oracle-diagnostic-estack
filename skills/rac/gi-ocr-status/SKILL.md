---
name: gi-ocr-status
id: rac/gi-ocr-status
version: 1.0.0
domain: rac
status: active
---

# Purpose

Visibilidad, estado y placement básico de OCR (`ocrcheck`) — Fase 4 sólo hace visibility/status/placement/basic health, nunca reparación (`# 37` del prompt de Fase 4: no replace, no restore, no modify OCR configuration).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_ocr_status` (`ocrcheck`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `ocrcheck` (sin flags de reparación).

# Forbidden operations

No reemplaza/restaura OCR, no modifica su configuración. Si `ocrcheck` requiere privilegio no disponible → `INSUFFICIENT_PRIVILEGES` + `MANUAL COLLECTION INSTRUCTION`.

# Decision logic

1. Leer estado de integridad reportado por `ocrcheck` (`Device/File integrity check succeeded`) y ubicación de cada copia.
2. Fallo de integridad reportado → `CRITICAL`, escala inmediatamente — nunca se intenta ninguna reparación desde este stack.

# Confidence model

`FACT` para el estado leído directamente. `INSUFFICIENT_PRIVILEGES` cuando el collector no puede ejecutarse.

# Output schema

```yaml
findings:
  - ocr_status: KNOWN|UNKNOWN|INSUFFICIENT_PRIVILEGES
    integrity_check: string|null
    copies: [{location: string, status: string}]|null
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-voting-status`, `rac/gi-cluster-health`.

# Escalation

Fallo de integridad OCR → `incident-root-cause-analyst`, severity `CRITICAL`, inmediato.

# Data sensitivity

Media — paths de OCR enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_ocrcheck_parser.sh`, `tests/test_no_ocr_change.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.
