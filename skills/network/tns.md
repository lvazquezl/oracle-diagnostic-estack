---
name: tns
id: network/tns
version: 1.0.0
domain: network
status: active
---

# Purpose

Diagnosticar problemas de resolución y conexión TNS (`tnsnames.ora`, Easy Connect, LDAP) interpretando errores comunes (TNS-12154, TNS-12541, TNS-12514, TNS-12170) a partir de evidencia ya recolectada, sin modificar ninguna configuración.

# Supported Oracle versions

10g–23ai. Sintaxis de `tnsnames.ora` estable; Easy Connect Plus desde 12c ampliando opciones.

# Supported OS/platforms

Todas — la ubicación de `TNS_ADMIN` y el formato de archivo cambian por plataforma (`\` vs `/`, variables de entorno vs. registro en Windows), documentado por query.

# Supported architectures

Standalone y RAC (SCAN entries tienen tratamiento propio en `network/scan-listener`, este skill cubre TNS genérico). NON-CDB y CDB (el service name puede apuntar a un PDB). Primary y Physical Standby (conectividad entre sitios).

# Prerequisites

Ninguno específico, aunque se beneficia de `core/context-discovery` para saber si el target es RAC (y por tanto validar contra `network/scan-listener` en paralelo).

# Required evidence

- query_id: `Q-NET-TNS-CONFIG-001` (lectura de `tnsnames.ora`/`sqlnet.ora` con hostnames/IPs enmascarados por defecto)

# Optional evidence

- query_id: `Q-NET-LISTENER-LOG-001` (extracto de listener.log acotado por ventana de tiempo, para correlacionar errores TNS)

# Read-only operations

Lectura de archivos de configuración Oracle Net y del listener log, vía collector certificado (nunca `cat`/`type` libre).

# Forbidden operations

No modifica `tnsnames.ora`/`sqlnet.ora`/`listener.ora`, no reinicia el listener, no prueba conectividad activa fuera de lo que el collector certificado ya expone.

# Decision logic

1. Parsear el error reportado (TNS-12154 = no resuelve el alias; TNS-12541 = no listener en el puerto; TNS-12514 = listener activo pero no conoce el service; TNS-12170 = timeout de conexión).
2. TNS-12154 → verificar que el alias exista en `tnsnames.ora`/LDAP visible y que `TNS_ADMIN` apunte al archivo correcto.
3. TNS-12541 → correlacionar con `network/listener` (¿el listener está arriba en ese host/puerto?).
4. TNS-12514 → correlacionar con `get_listener_status` (¿el servicio está registrado? ¿instancia caída o `service_names` mal configurado?).
5. TNS-12170 → correlacionar con `network/timeouts`/`network/latency` y, si es RAC, con `network/rac-interconnect`.

# Confidence model

`FACT` para el contenido de configuración leído directamente. `PROBABLE_CAUSE` cuando el patrón de error + configuración + estado del listener coinciden de forma consistente. `UNDETERMINED` si el error reportado no tiene evidencia de log correlacionable en la ventana solicitada.

# Output schema

```yaml
findings:
  - tns_error: string
    likely_cause: string
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE|UNDETERMINED
    evidence_refs: [EVD-...]
```

# Related skills

`network/listener`, `network/scan-listener`, `network/dns`, `network/hosts`, `network/tns-125xx`.

# Escalation

Si la causa apunta a DNS/firewall fuera del alcance de evidencia Oracle, se declara `UNDETERMINED` y se recomienda verificación manual del equipo de red — no se inventa una causa de infraestructura no observada.

# Data sensitivity

Media: `tnsnames.ora` puede contener hostnames/IPs/nombres de servicio internos — enmascarados por defecto (`sanitizers/data-classification-policy.md`); si contiene credenciales embebidas (mal hábito legacy), el sanitizer las bloquea antes de llegar al modelo.

# Context budget

Bajo: archivos de configuración y extractos de log acotados por ventana.

# Tests

`tests/test_hostname_masking.sh`, `tests/test_secret_detection.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `findings.md` con el error, causa probable y evidencia enmascarada.

# Evolution via `/change`

Nuevos patrones de error vía `/change knowledge` (una vez validados) y `/change skill` para la lógica de decisión.
