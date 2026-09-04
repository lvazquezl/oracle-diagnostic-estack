# GI Read-Only Collectors — Fase 4 (RAC/GI/ASM/Network)

Extiende el modelo de collectors de `collectors/README.md` (Fase 1/2) con el **Collector Contract** para comandos Clusterware/GI/ASM/red — el mismo principio (`# 88` del prompt de Fase 4): *RAC/GI/ASM/Network diagnosis can be performed with certified read-only queries and semantic allowlisted collectors without granting the e-stack administrative execution capabilities.*

## Principio

Ningún collector de esta fase es `execute_shell(command)`. Cada uno mapea **exclusivamente** a un comando allowlisted, sin concatenación arbitraria de parámetros no validados — igual disciplina que `oracle-sql-collector` con SQL certificado (`collectors/README.md#contrato-de-un-collector`).

## Collector Contract (schema, `# 20` del prompt de Fase 4)

Cada collector declara:

```yaml
collector_id: string
semantic_purpose: string
command_family: string            # ej. "crsctl stat res -t", sin flags de cambio
supported_versions: [string]      # familias GI/RAC (# 11)
gi_home_requirement: bool
oracle_home_requirement: bool
required_os_identity: string      # identidad diagnóstica, nunca root/grid con capacidad de cambio
required_group_membership: [string]|null
required_privileges: [string]
timeout_seconds: number
max_output_bytes: number
sanitization: string              # referencia a sanitizers/data-classification-policy.md
cost: LOW|MEDIUM|HIGH|BLOCKED
side_effect_class: READ_ONLY|BLOCKED   # BLOCKED si no puede garantizarse READ_ONLY — nunca se habilita
validation_status: DOCUMENTATION_VALIDATED|FIXTURE_VALIDATED|LAB_VALIDATED|RUNTIME_VALIDATED
parser: string                    # módulo en parsers/rac/
fallback: string                  # qué hacer si el collector no puede ejecutarse
```

`side_effect_class` es siempre `READ_ONLY` para todo collector habilitado en esta fase — si no puede garantizarse, el collector queda `BLOCKED`, nunca se habilita "por ahora" (`# 20`).

## Catálogo de collectors GI/Clusterware/ASM (`# 18`, `# 19`)

| collector_id | comando | parser | cost | validation_status |
|---|---|---|---|---|
| `get_cluster_nodes` | `olsnodes` | `parsers/rac/olsnodes_parser.py` | LOW | FIXTURE_VALIDATED |
| `get_cluster_resources` | `crsctl stat res -t` (y `-p` para propiedades) | `parsers/rac/crsctl_resource_parser.py` | MEDIUM | FIXTURE_VALIDATED |
| `get_cluster_version` | `crsctl query crs activeversion`/`softwareversion` | `parsers/rac/crsctl_resource_parser.py` (sección version) | LOW | FIXTURE_VALIDATED |
| `get_scan_configuration` | `srvctl config scan`, `srvctl status scan`, `srvctl config scan_listener`, `srvctl status scan_listener` | `parsers/rac/srvctl_scan_parser.py` | LOW | FIXTURE_VALIDATED |
| `get_vip_configuration` | `srvctl config vip` | `parsers/rac/srvctl_scan_parser.py` (reutiliza el mismo parser de formato `srvctl config`) | LOW | FIXTURE_VALIDATED |
| `get_service_configuration` | `srvctl config service`, `srvctl status service` | `parsers/rac/srvctl_service_parser.py` | LOW | FIXTURE_VALIDATED |
| `get_listener_configuration` | `lsnrctl status`, lectura de `listener.ora`/`sqlnet.ora` (enmascarada) | `parsers/rac/lsnrctl_status_parser.py` | LOW | FIXTURE_VALIDATED |
| `get_network_configuration` | `oifcfg getif` | `parsers/rac/crsctl_resource_parser.py` (sección oifcfg) | LOW | FIXTURE_VALIDATED |
| `get_ocr_status` | `ocrcheck` | `parsers/rac/ocrcheck_parser.py` | LOW | FIXTURE_VALIDATED |
| `get_voting_status` | `crsctl query css votedisk` | `parsers/rac/voting_parser.py` | LOW | FIXTURE_VALIDATED |
| `get_diskgroup_listing` (respaldo/discovery de `asm/topology`) | `asmcmd lsdg` | `parsers/rac/asmcmd_lsdg_parser.py` | LOW | FIXTURE_VALIDATED |

Ninguno alcanza `RUNTIME_VALIDATED` en esta fase — la ejecución real contra un ambiente vivo es Fase 7 (Gateway MCP), igual que el resto del catálogo (`collectors/README.md`: "especificación certificada, no runtime ejecutable").

## OS Network Collectors (`# 34`)

Delegados a `os-platform-analyst`, invocados por `network/interconnect`/`rac/gi-network-interfaces`:

| collector_id | comando (según plataforma) | side_effect_class |
|---|---|---|
| `get_interfaces` | `ip addr`/equivalente | READ_ONLY |
| `get_routes` | `ip route`/equivalente | READ_ONLY |
| `get_socket_summary` | `ss`/equivalente | READ_ONLY |
| `get_name_resolution` | `getent hosts`/`nslookup`/equivalente | READ_ONLY |
| `get_host_identity` | lectura de `/etc/hostname` o equivalente | READ_ONLY |

Nunca cambian bonding, VLAN, route, MTU, firewall ni sysctl (`# 34`).

## Report ingest model

`FILE/COMMAND OUTPUT → TYPE DETECTION (por collector_id, no por extensión) → LOCAL PARSER (parsers/rac/*.py) → STRUCTURED EVIDENCE → SANITIZER → EVIDENCE → SKILL → AGENT` — mismo principio que `parsers/performance/` (Fase 3 Completion Hardening): Python 3 stdlib-only, ningún parser llama `eval`/`exec`/`subprocess`/`os.system`/`compile()` sobre el contenido capturado, el contenido de `crsctl`/`srvctl`/`lsnrctl`/`asmcmd`/logs es siempre DATA, nunca instrucción (`# 47` del prompt de Fase 4). Verificado por `tests/test_no_arbitrary_shell.sh`, `tests/test_collector_prompt_injection_safe.sh`.

## GI Identity Model (`# 22`)

Sin `root`/`sudo`/`grid` con capacidad de cambio. Collectors diseñados para ejecutarse con identidad diagnóstica de sólo lectura. Si un comando requiere privilegio no disponible: `INSUFFICIENT_PRIVILEGES` + `MANUAL COLLECTION INSTRUCTION` para que un administrador autorizado lo ejecute y entregue la salida — nunca escalamiento automático de privilegios.

## Certificación

Un collector nuevo o modificado sigue `/change parser` (para el parser) + `/change compatibility` (si introduce una versión/plataforma nueva) — ver `EVOLUTION.md#15-change-parser--checklist-obligatorio-fase-4`.

## Límites obligatorios

`timeout_seconds`/`max_output_bytes` heredados del Collector Contract de cada entrada — ver `policies/rate-limiting-policy.md`. Salida excesiva → `TRUNCATED` (preserva `collector_status`, tamaño original estimado cuando esté disponible, y razón de truncamiento — nunca se descarta en silencio, `# 60`).
