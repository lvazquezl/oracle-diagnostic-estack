# OS Platform Diagnostic Model — Fase 9

## OS version model

```yaml
os_target:
  family: linux|solaris|windows|unknown
  distribution: string|null       # Oracle Linux|RHEL|SUSE|LinuxONE|Solaris|Windows Server
  version: string|null
  kernel: string|null
  architecture: string|null       # x86_64|s390x|sparc|...
  virtualization: string|null     # VMware|KVM|Hyper-V|LPAR|bare_metal|unknown
  hostname_token: string          # MASK por defecto
```

Modelo propio, normalizado por `os/discovery` — **nunca reutiliza `scripts/lib/version.sh`**
(`# 6` del prompt: "No usar version resolver Oracle para OS versions"), porque el dominio de
comparación es distinto (familias de distribución Linux/kernel, no releases Oracle). No existe
resolver de variante SQL en este dominio (no hay SQL) — el "resolver" aquí es de **capability por
plataforma** (`SUPPORTED|PARTIALLY_SUPPORTED|NOT_APPLICABLE|COMPATIBILITY_VALIDATION_REQUIRED`),
resuelto por `os/platform-version` contra `agents/os-platform-analyst/manifest.yaml#supported_platforms`.

## Health Model

25 dimensiones (`# 51` del prompt), nunca un score único opaco:

```text
OS IDENTITY          CPU                 NUMA                MEMORY
SWAP                 HUGEPAGES           THP                 PROCESS LIMITS
OPEN FILES           IPC                 AIO                 EPHEMERAL PORTS
FILESYSTEM           INODES              BLOCK DEVICES       MULTIPATH
I/O                  NETWORK             BONDING             VLAN
MTU                  DNS                 TIME SYNC           ORACLE GROUPS
ORACLE PROCESSES     CGROUPS             SECURITY POSTURE
```

Estados: `HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|PARTIALLY_SUPPORTED`.

## Evidence model

```text
collector_id
platform
version
host_token
timestamp
scope
validation_status
sanitization
cost
```

Trazabilidad: `EVD → FND → REC → CHG` (mismo modelo que el resto del e-stack).

## Reconciliación de skills (Fase 9)

Foundation registró `skills/os/<plataforma>/<skill>` (18 skills × 5 plataformas: linux, solaris,
aix, windows, hpux — sólo `os/linux/memory` materializado). Fase 9 reemplaza ese modelo
**platform-per-skill-id** por un modelo **domain-per-skill-id** (`os/<capability>`), consistente
con `network/*`/`security/*`: un skill por capacidad diagnóstica, awareness de plataforma interna
vía el campo `platforms:` del manifest — nunca un archivo separado por plataforma. El contenido
de `os/linux/memory.md` se fusionó en `os/memory` (v2.0.0) como base Linux, ampliado con Windows/
Solaris. AIX/HP-UX quedan fuera del alcance explícito de Fase 9 — sus 36 entradas `registered`
(18 × 2) permanecen intactas para una fase futura.

## Sanitización / tokenización

```text
hostnames               MASK
IP addresses            TOKENIZE
MAC addresses            TOKENIZE
mount paths               MASK/TOKENIZE
filesystem paths            MASK/TOKENIZE
usernames                     TOKENIZE
group names (sensibles)          TOKENIZE
process arguments                   DROP por defecto
wallet paths                          TOKENIZE
vendor paths                            TOKENIZE
```

Ver `docs/OS_READONLY_PRIVILEGES.md` para el detalle de sanitización por collector.

## Context/token policy

Nunca se envía `/proc` completo, todos los procesos, todos los mounts con paths crudos, ni todos
los sockets/device stats. Preferir: summaries + anomalías + evidence refs (`# 60` del prompt).
`process arguments` nunca se envían completos por defecto (`# 58`) — podrían contener passwords/
connection strings/tokens/wallet paths; se prefiere process family/name.

## Cross-domain integration

`os/rac-interconnect-awareness`, `os/dataguard-network-awareness`,
`os/rman-media-manager-awareness`, `os/security-filesystem-awareness` correlacionan evidencia OS
con RAC/Data Guard/RMAN/Security **por referencia** — cada dominio Oracle consume esta evidencia,
nunca duplica su propio collector OS (`# 91` del prompt).

## Manual hardening

Ver `docs/OS_HARDENING_MANUAL_ACTION_MODEL.md` — Manual Action Contract completo (`action_id,
purpose, owner_role, platform, command, config_file, prechecks, expected_result, risk, rollback,
postchecks, reboot_required, execution_status: NOT_EXECUTED`).
