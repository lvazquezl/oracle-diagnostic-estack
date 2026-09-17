---
name: vmware
id: capacity/vmware
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Contract de capacidad para VMware — vCPU, memoria asignada, capacidad del host, capacidad de
datastore, asignación por VM, awareness de oversubscription. Sin collector runtime certificado en
esta fase — fuente `NOT_CERTIFIED` por defecto, disponible vía `MANUAL_IMPORT`. **Nunca realiza
cambios de VM.**

# Supported Oracle versions

N/A — dominio de infraestructura, no Oracle.

# Supported OS/platforms

N/A directo — hypervisor, no OS guest.

# Supported architectures

N/A directo.

# Prerequisites

Fuente `MANUAL_IMPORT` o adapter certificado (fuera de alcance de Fase 10 MVP) declarado en el
Target Profile.

# Required evidence

- Datos aportados vía `MANUAL_IMPORT` con `source_id` explícito, o `NOT_CERTIFIED`.

# Optional evidence

Ninguna.

# Read-only operations

Lectura de datos ya exportados/importados — ningún acceso directo a vCenter/ESXi en esta fase.

# Forbidden operations

Nunca redimensiona VM, nunca cambia reservations/limits/shares, nunca modifica asignación de
recursos VMware de ningún tipo (`# 576`-`# 589` del prompt de Fase 10).

# Decision logic

1. Normalizar (cuando disponible) `vCPU`, `allocated memory`, `host capacity`, `datastore
   capacity`, `VM allocation` al Common Metric Model.
2. Awareness de `oversubscription` — reportar la relación `vCPU asignado / pCPU físico` y
   `memoria asignada / memoria física` del host cuando la fuente lo provea, nunca calculado desde
   datos parciales/inventados.
3. Sin fuente `CONNECTED`/`MANUAL_IMPORT`, el recurso queda `NOT_CERTIFIED` — el resto del
   assessment continúa con `PARTIAL_CAPACITY_ASSESSMENT`.

# Normal state

Datos disponibles vía `MANUAL_IMPORT` con calidad `ACCEPTABLE`/`GOOD`; oversubscription dentro de
rangos declarados por el DBA (sin umbral universal impuesto).

# Abnormal patterns

Oversubscription alta con headroom del host reducido — reportado sólo con evidencia real, nunca
estimado.

# False positives

Ninguno — sin evidencia no se reporta ningún hallazgo, sólo `NOT_CERTIFIED`.

# Correlation rules

Alimenta `capacity/cpu`, `capacity/memory`, `capacity/storage`, `capacity/horizontal`,
`capacity/vertical`.

# Confidence model

`UNDETERMINED` sin evidencia; `FACT` sobre datos efectivamente importados.

# Severity

N/A sin evidencia.

# Output schema

```yaml
vmware_capacity:
  status: NOT_CERTIFIED|MANUAL_IMPORT|CONNECTED
  vcpu_allocated: number|null
  memory_allocated: number|null
  host_capacity: number|null
  datastore_capacity: number|null
  vm_allocation: [{vm: string, vcpu: number|null, memory: number|null}]|null
  oversubscription_ratio_cpu: number|null
  oversubscription_ratio_memory: number|null
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/cpu`, `capacity/memory`, `capacity/storage`, `capacity/horizontal`, `capacity/vertical`,
`capacity/data-source-inventory`.

# Escalation

Ninguna sin evidencia real.

# Manual remediation guidance

N/A directa — cualquier cambio VMware es decisión/acción del administrador de virtualización.

# Security

Sin datos sensibles — sólo metadata de capacidad cuando exista.

# Tests

`tests/test_no_vm_resize.sh`, `tests/test_capacity_read_only.sh`.

# Documentation requirements

Alimenta `capacity-summary.md` (sección VMware, `NOT_CERTIFIED` cuando aplique).

# Change history

v1.0.0 — Fase 10, creación inicial.
