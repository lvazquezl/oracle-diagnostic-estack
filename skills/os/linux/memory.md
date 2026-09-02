---
name: memory
id: os/linux/memory
version: 1.0.0
domain: os
status: active
---

# Purpose

Evaluar uso de memoria física, swap, HugePages y su alineación con el sizing de SGA/PGA en hosts Linux, para detectar riesgo de swapping o HugePages mal dimensionadas.

# Supported Oracle versions

N/A directo — aplica a cualquier versión Oracle corriendo sobre el host Linux analizado.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE (implementación específica de Linux; Solaris/AIX/Windows/HP-UX tienen su propio skill bajo `skills/os/<plataforma>/memory.md`, registrados en `skills/REGISTRY.md`, no materializados en Fase 1).

# Supported architectures

Standalone y RAC (por nodo). N/A para storage/tenancy/role directamente — aplica igual a hosts primary o standby.

# Prerequisites

Requiere que `core/context-discovery` haya confirmado `os_platform` como una variante Linux para esta implementación.

# Required evidence

- query_id: `Q-OS-LINUX-MEM-001` (`get_os_memory`: `/proc/meminfo` equivalente vía collector certificado)

# Optional evidence

- query_id: `Q-OS-LINUX-HUGEPAGES-001` (`Hugepagesize`, `HugePages_Total/Free/Rsvd` de `/proc/meminfo`, y `vm.nr_hugepages`)
- query_id: `Q-ORACLE-SGA-001` (tamaño de SGA configurado, para correlacionar con HugePages)

# Read-only operations

Lectura de `/proc/meminfo`, `/proc/sys/vm/nr_hugepages` y equivalentes vía collector certificado (nunca edición de `/etc/sysctl.conf` ni `sysctl -w`).

# Forbidden operations

No ejecuta `sysctl -w`, no edita `/etc/sysctl.conf`/`/etc/security/limits.conf`, no reinicia servicios.

# Decision logic

1. Calcular `swap_used_pct`. Si `> 0` de forma sostenida (no un pico transitorio) en un host con SGA configurada → señal de posible sub-dimensionamiento de RAM o mala configuración de HugePages.
2. Si Oracle usa SGA >= umbral de política (ej. 8GB) y HugePages no está habilitado/reservado (`HugePages_Total = 0` o `HugePages_Free < SGA requerida en páginas`) → `MEDIUM`/`HIGH` según brecha.
3. Si `HugePages_Total > 0` pero `HugePages_Rsvd`/`HugePages_Free` indican que la instancia no está usándolas efectivamente (mismatch con `Use_Large_Pages` de Oracle) → señalar configuración inconsistente.
4. Correlacionar swapping sostenido con degradación reportada por `oracle-performance-analyst` en la misma ventana.

# Confidence model

`FACT` para las métricas leídas directamente de `/proc/meminfo`. `PROBABLE_CAUSE` cuando el swapping sostenido coincide temporalmente con degradación de performance reportada.

# Output schema

```yaml
findings:
  - metric: swap_used_pct|hugepages_configured|hugepages_effective
    value: string
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`os/linux/swap`, `os/linux/numa`, `performance/sga`, `performance/pga`.

# Escalation

Swapping sostenido con SGA grande escala a `oracle-performance-analyst` (impacto) y a `change-advisor` (propuesta de configurar HugePages, ejecución manual).

# Data sensitivity

Baja: métricas de memoria del host, sin datos de negocio. Hostname enmascarado por defecto.

# Context budget

Bajo: `/proc/meminfo` es compacto; se agrega por nodo en RAC.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_os_detection.sh`, `tests/test_platform_abstraction.sh`.

# Documentation requirements

Alimenta `findings.md` con métricas de memoria/HugePages por nodo.

# Evolution via `/change`

Umbral de SGA para requerir HugePages vía `/change policy`; equivalentes para Solaris/AIX/Windows/HP-UX vía `/change compatibility` + `/change skill`.
