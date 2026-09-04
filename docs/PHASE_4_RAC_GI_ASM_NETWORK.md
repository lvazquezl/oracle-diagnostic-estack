# Phase 4 — RAC / Grid Infrastructure / ASM / Network

Branch: `phase/4-rac-gi-asm-network`. Baseline: `v0.3.0-performance`. Objetivo del baseline resultante: `v0.4.0-rac-gi-asm-network`.

## Scope

Capa especializada de diagnóstico RAC, Grid Infrastructure/Clusterware, ASM y Oracle Net: topología, membership, recursos Clusterware, servicios y su placement/load balancing (CLB/RLB), SCAN/VIP/listeners (recurso Clusterware y conectividad, dominios separados), interconnect y Cache Fusion, OCR/voting (visibilidad), disk groups/capacidad/redundancia/discos/rebalance ASM, y troubleshooting de conectividad TNS. No reconstruye Foundation/Oracle Core/Performance, no avanza a Data Guard, no implementa auto-remediation, no introduce un Execution Plane.

## RAC Agent

`agents/oracle-rac-analyst/` (v2.0.0) — materializado en contrato estructurado completo (`AGENT.md`/`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`/`tests/README.md`/`CHANGELOG.md`, mismo patrón que `oracle-performance-analyst` v4.0.0 de Fase 3 Completion Hardening). Absorbe Grid Infrastructure — no existe agente GI separado (`# 2`).

## ASM Agent

`agents/oracle-asm-storage-analyst/` (v2.0.0) — mismo patrón de contrato estructurado. 12 skills `asm/*`.

## Network Agent

`agents/oracle-network-analyst/` (v2.0.0) — mismo patrón de contrato estructurado. 14 skills `network/*`. Boundary explícito con `oracle-rac-analyst` documentado en ambos `AGENT.md` (Clusterware vs. conectividad).

## OS Agent changes

`agents/os-platform-analyst.md` (v1.1.0) — extensión ligera, sin restructurar a carpeta: nuevas líneas de colaboración con `oracle-rac-analyst` (interconnect OS-level) y `oracle-network-analyst` (TCP/firewall del host).

## RAC skills

19 skills materializados: `topology, instance-state, node-membership, cluster-resources, services, service-placement, session-distribution, service-session-distribution, load-balancing, clb, rlb, failover, interconnect, global-cache, instance-eviction, configuration-drift, healthcheck, assessment, troubleshooting`.

## GI skills

12 skills materializados bajo el dominio `rac` con prefijo `gi-`: `gi-version, gi-node-status, gi-resource-status, gi-resource-properties, gi-scan, gi-vip, gi-listeners, gi-network-interfaces, gi-ocr-status, gi-voting-status, gi-cluster-health, gi-configuration-consistency` — ver `docs/RAC_DIAGNOSTIC_MODEL.md#gi-absorbido-no-un-agente-separado` para la justificación de la ubicación.

## ASM skills

12 skills materializados: `topology, instances, diskgroups, capacity, redundancy, disks, failure-groups, rebalance, operations, healthcheck, assessment, troubleshooting`.

## Network skills

14 skills materializados: `oracle-net, listeners, scan, scan-resolution, service-registration, local-listener, remote-listener, connection-path, tns-errors, timeouts, name-resolution, interconnect, healthcheck, troubleshooting`.

## RAC query catalog

`queries/rac/` — `Q-RAC-TOPOLOGY-001` (2 variantes, pre/post-multitenant), `Q-RAC-SERVICES-001`, `Q-RAC-INTERCONNECT-001`, `Q-RAC-GES-GCS-001`, más `Q-RAC-SESSION-DIST-001` relocalizada desde `queries/` plano (mismo ID, sin duplicar).

## ASM query catalog

`queries/asm/` — `Q-ASM-TOPOLOGY-001` (`V$ASM_DISKGROUP_STAT` por defecto), `Q-ASM-DISKS-001` (sólo discos anómalos), `Q-ASM-REBALANCE-001`.

Corrección de un gap pre-existente: las filas Foundation `Q-RAC-SERVICE-PLACEMENT-001`/`Q-ASM-DG-USAGE-001`/`Q-ASM-OPERATION-001` en `queries/REGISTRY.md` nunca tuvieron un archivo `.md` real pese a figurar en la sección "materializadas" — detectado durante esta fase y corregido reemplazándolas por las 7 queries genuinamente materializadas arriba (ver `queries/REGISTRY.md` nota de Fase 4).

## Query variants

`Q-RAC-TOPOLOGY-001` reutiliza el mismo patrón pre/post-multitenant que `Q-DISC-RAC-001` (V1 11.2 sin `con_id`, V2 12.1+ con `con_id`). `Q-RAC-SERVICES-001` declara una única variante (11.2+, `GV$ACTIVE_SERVICES`) — 10g/11gR1 queda sin variante (no certificado), mismo criterio que el resto del catálogo RAC. El resto de queries RAC/ASM son `implicit_full_range` (11.2+, validadas contra `compatibility/oracle-dictionary/views.yaml`).

## Semantic collectors

`docs/GI_READONLY_COLLECTORS.md` — 11 collectors GI/Clusterware/ASM (`get_cluster_nodes`, `get_cluster_resources`, `get_cluster_version`, `get_scan_configuration`, `get_vip_configuration`, `get_service_configuration`, `get_listener_configuration`, `get_network_configuration`, `get_ocr_status`, `get_voting_status`, `get_diskgroup_listing`) + 5 collectors de red OS (`get_interfaces`, `get_routes`, `get_socket_summary`, `get_name_resolution`, `get_host_identity`) — todos mapean a un comando allowlisted específico, ninguno acepta parámetros de comando libres.

## Collector Contract

Schema completo en `docs/GI_READONLY_COLLECTORS.md#collector-contract-schema--28-20-del-prompt-de-fase-4`: `collector_id, semantic_purpose, command_family, supported_versions, gi_home_requirement, oracle_home_requirement, required_os_identity, required_group_membership, required_privileges, timeout_seconds, max_output_bytes, sanitization, cost, side_effect_class, validation_status, parser, fallback`. `side_effect_class` es siempre `READ_ONLY` para todo collector habilitado — `BLOCKED` para lo que no pueda garantizarse, nunca otro valor.

## Collector version compatibility

Familias declaradas en `agents/oracle-rac-analyst/manifest.yaml#supported_versions`: 10g legacy CRS/RAC (`PARTIALLY_SUPPORTED`), 11gR2 GI–23ai (`KNOWN_SUPPORTED`), futuro (`UNKNOWN_FUTURE`, nunca auto-compatible vía `latest`).

## Arbitrary shell protection

`tests/test_no_arbitrary_shell.sh` — verificación estática sobre `parsers/`, `mcp/`, `collectors/`, `docs/GI_READONLY_COLLECTORS.md`; ningún patrón `execute_shell|run_command|shell_exec|os.system(|subprocess.*(` fuera de contexto de prohibición documentada. Complementado por `tests/test_collector_prompt_injection_safe.sh` (prueba viva con fixture de intento de inyección real).

## RAC topology / Instance state / Cluster resources

Ver `docs/RAC_DIAGNOSTIC_MODEL.md`.

## Services / Service placement / Session distribution / CLB / RLB / Failover awareness

Ver `docs/RAC_DIAGNOSTIC_MODEL.md#session-imbalance-nunca-una-sola-métrica` y `#clb-vs-rlb-vs-taf-vs-application-continuity`.

## SCAN / VIP / Listeners / Service registration / Name resolution

Ver `docs/ORACLE_NETWORK_DIAGNOSTIC_MODEL.md`.

## Interconnect

Ver `docs/RAC_DIAGNOSTIC_MODEL.md#cache-fusion-topología-no-impacto` y `docs/ORACLE_NETWORK_DIAGNOSTIC_MODEL.md#interconnect-dos-capas-una-responsabilidad-compartida`.

## OCR visibility / Voting visibility

`rac/gi-ocr-status`/`rac/gi-voting-status` — sólo visibilidad/status/placement/basic health (`# 37`); nunca replace/restore/add/remove. Quorum en riesgo (`located_count < 3`) → `CRITICAL`, escalado inmediato.

## ASM diskgroups / capacity / redundancy / disk health / rebalance

Ver `docs/ASM_DIAGNOSTIC_MODEL.md`.

## Healthcheck RAC / ASM / Network

`/healthcheck rac|asm|network` orquestan `rac/healthcheck`/`asm/healthcheck`/`network/healthcheck` respectivamente — cada uno produce un Cluster/ASM/Network Health Model por dimensión (`HEALTHY|DEGRADED|WARNING|CRITICAL|UNKNOWN`), nunca un score opaco único (`# 38`).

## Assessment RAC

`/assessment rac` orquesta `rac/assessment` — arquitectura, versiones, nodos/instancias/servicios, load-balancing, SCAN, listeners, interconnect, resumen ASM, hallazgos de configuración, riesgos, recomendaciones (`# 42`).

## Troubleshooting workflows

`/diagnose` extendido con los escenarios `rac`, `service`, `scan`, `listener`, `interconnect`, `asm`, `connection` (`# 43`) — enrutados a `rac/troubleshooting`/`asm/troubleshooting`/`network/troubleshooting` según el síntoma, sin crear un comando slash por código de error individual.

## Evidence model

`cluster/node/instance/service/container/time/source/query_id/collector_id/variant_id/sanitization/cost/validation_status` (`# 45`) — mismos Evidence IDs (`EVD-*`) y trazabilidad `EVD → FND → REC → CHG` que el resto del stack.

## Sanitization

`parsers/rac/common.py.Sanitizer` — tokenización determinista de `node`/`instance`/`service`/`scan_name`/`path`, scrub de IPs. Consistente dentro de una misma sesión de análisis (`NODE_TOKEN_001`, `SERVICE_TOKEN_001`, etc.), igual patrón que `parsers/performance/common.py.Sanitizer` de Fase 3.

## Token/context optimization

`context-policy.yaml` de los 3 agentes declara `top_n` por defecto (10) y reglas explícitas de "no full dump" (`no_full_crsctl_dump`, `no_full_listener_log`, `no_full_disk_listing`) — un healthcheck de 5 nodos/120 recursos se resume a `total_resources: 120, online: 120` salvo anomalía (`# 76`).

## Capability Matrix

`config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` actualizados: RAC topology/services/load-balancing `SUPPORTED` desde 11gR2 (`PARTIALLY_SUPPORTED` en 10g/11gR1 legacy), GI resource visibility `SUPPORTED`, ASM health `SUPPORTED`, ASM write operations `PROHIBITED`, SCAN/Oracle Net diagnostics `SUPPORTED`, interconnect diagnostics `SUPPORTED`/`PARTIAL` según evidencia disponible, OCR/Voting repair `PROHIBITED`, RAC deep performance `DELEGATES_TO_PERFORMANCE`, Data Guard `PLANNED`.

## Documentation

Nuevos: `docs/PHASE_4_RAC_GI_ASM_NETWORK.md` (este documento), `docs/RAC_DIAGNOSTIC_MODEL.md`, `docs/GI_READONLY_COLLECTORS.md`, `docs/ASM_DIAGNOSTIC_MODEL.md`, `docs/ORACLE_NETWORK_DIAGNOSTIC_MODEL.md`. Actualizados: `README.md`, `ARCHITECTURE.md`, `SECURITY.md`, `docs/CAPABILITY_MATRIX.md`, `CHANGELOG.md`, `docs/ORACLE_READONLY_PRIVILEGES.md`, `docs/TARGET_PROFILE.md` (schema 2.1.0), `queries/REGISTRY.md`, `skills/REGISTRY.md`, `agents/REGISTRY.md`, `mcp/tool-manifest.md`, `collectors/README.md`, `EVOLUTION.md` (`/change parser` sección 15), workflows `rac.md`/`healthcheck.md`/`assessment.md`/`diagnose.md`, `knowledge/errors/{tns,ora,crs}/` (9 entradas nuevas).

## Security validation

Todos los tests de seguridad de fases anteriores siguen pasando sin modificación de su lógica. Nuevos: 16 tests de collector/parser safety (`# 64`), 14 tests de seguridad específicos de Fase 4 (`# 68`) — `test_no_crsctl_modify`, `test_no_srvctl_modify_execution/start/stop/relocate`, `test_no_asmcmd_write_operation`, `test_no_listener_reload/stop`, `test_no_root`, `test_no_sudo`, `test_no_network_change`, `test_no_ocr_change`, `test_no_voting_change`, `test_no_kill_session` — todos `PASS`. Verificados para distinguir capacidad ejecutable de recomendación manual documentada (varios falsos positivos de negación textual encontrados y corregidos durante la construcción — ver `# Known limitations`).

## Test results

68 tests nuevos: 16 collector/parser, 11 RAC, 8 ASM, 11 Network, 14 seguridad, 8 contrato de agente (3 agentes × ~2-3 tests cada uno). Todos `PASS` tras corregir los bugs de test autoinfligidos documentados abajo.

## Regression results

Ver el reporte de cierre final para el resultado agregado de `tests/run-all.sh` sobre el árbol completo (Foundation + Foundation Hardening + Oracle Core + Compatibility Hardening + Performance + Performance Completion + Fase 4), ejecutado después de la construcción completa de esta fase.

## Known limitations

- `awr_parser.py`/similares de Fase 3 sin cambios — no forman parte de esta fase.
- Los parsers `parsers/rac/*.py` son primera versión funcional — fidelidad validada contra fixtures propios (`tests/fixtures/collectors/`), no contra la diversidad completa de formatos de salida `crsctl`/`srvctl` entre versiones GI (11gR2 vs. 23ai pueden diferir en detalles menores de formato no cubiertos por esta fase).
- `TAF`/`Application Continuity` se documentan narrativamente en `AGENT.md` pero no tienen `skill_id`/query/collector propio — candidato a `/change query` futuro si se requiere evidencia estructurada.
- `network/oracle-net` cubre `tcp`/`ports`/`ephemeral-ports`/`latency` (nombres Foundation) sólo narrativamente — sin collector de latencia de red certificado en esta fase (medir latencia activamente excede el alcance read-only-de-evidencia-ya-existente).
- Gap pre-existente de Multitenant (`Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001`, detectado en la fase de Performance Completion Hardening) sin cambios — no corresponde a esta fase.

## NOT_CERTIFIED queries

`Q-RAC-SERVICE-PLACEMENT-001`, `Q-ASM-DG-USAGE-001`, `Q-ASM-OPERATION-001` (nombres Foundation, nunca materializados, reemplazados — ver "RAC query catalog"/"ASM query catalog" arriba).

## NOT_CERTIFIED collectors

Ninguno — los 16 collectors documentados en `docs/GI_READONLY_COLLECTORS.md` están todos `FIXTURE_VALIDATED`. Ninguno alcanza `RUNTIME_VALIDATED` (ejecución real contra ambiente vivo es Fase 7, Gateway MCP).

## Manual Action Contract

Todo comando `srvctl`/`crsctl`/`asmcmd`/cambio de configuración de red recomendado por cualquier agente de esta fase usa el siguiente esquema (`# 69` del prompt de Fase 4):

```yaml
manual_action:
  action_id: string
  purpose: string
  owner_role: string           # DBA | Grid Administrator | SysAdmin | Network Administrator
  command: string
  prechecks: [string]
  expected_result: string
  risk: string
  rollback: string
  postchecks: [string]
  execution_status: NOT_EXECUTED   # nunca EXECUTED
```

Presentado siempre con las etiquetas `MANUAL DBA ACTION` / `NOT EXECUTED` visibles (`# 17`). Ningún agente de esta fase ejecuta el comando — sólo lo genera como texto para revisión y ejecución humana.

## Next phase

Fase 5+ — Data Guard, Multitenant profundo, RMAN/backup profundo, según el orden de `README.md`. Explícitamente fuera de alcance de esta fase.
