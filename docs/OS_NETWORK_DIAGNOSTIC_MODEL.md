# OS Network Diagnostic Model — Fase 9

## Principio

Visibilidad de interfaz/bonding/VLAN/MTU/routing/DNS/ephemeral ports a nivel OS — nunca modifica
ninguna configuración de red. Correlaciona con RAC interconnect y Data Guard network, nunca
duplica `oracle-network-analyst`/`oracle-rac-analyst`.

## Reutilización de collectors (Fase 4)

`get_interfaces`, `get_routes`, `get_socket_summary`, `get_name_resolution`, `get_host_identity`
ya certificados desde Fase 4 (`docs/GI_READONLY_COLLECTORS.md#os-network-collectors`) — Fase 9 los
formaliza como collectors reales de `os/network-interfaces`, `os/routing`,
`os/tcp-socket-awareness`, `os/dns`, `os/discovery`, nunca duplicados.

## Cadena de consistencia física → bond → VLAN

```text
Physical interface (speed, duplex, MTU)
        ↓
Bond/team (mode, active slave, link failures)
        ↓
VLAN (ID, parent, MTU)
        ↓
MTU efectivo = mínimo de toda la cadena
```

Un mismatch en cualquier capa limita el MTU real al valor más bajo (fragmentación silenciosa).
Nunca se recomienda jumbo frames sin evidencia end-to-end de que toda la ruta lo soporta (`# 38`
del prompt).

## Ephemeral ports

`ip_local_port_range` correlacionado con `TIME_WAIT`/churn de conexiones — nunca un umbral fijo
sin contexto. Correlacionado con `ORA-27530`/`ORA-27501`/`ORA-27300`, nunca atribuido
automáticamente sin evidencia de agotamiento real (`# 27` del prompt).

## TCP/socket — acotado, nunca tuning genérico

`os/tcp-socket-awareness` cubre únicamente `somaxconn`/`tcp_max_syn_backlog`/`rmem`/`wmem` —
deliberadamente NO se convierte en tuning genérico de red (`# 28` del prompt).

## RAC interconnect awareness

`os/rac-interconnect-awareness` consolida interfaz + bonding + VLAN + MTU + routing + ephemeral
ports + time sync específicamente para la(s) interfaz(ces) del interconnect — reportado a
`oracle-rac-analyst` con evidence_refs, nunca modifica GI/red (`# 47`).

## Data Guard network awareness

`os/dataguard-network-awareness` correlaciona routing/DNS/socket pressure con transport lag/
timeouts reportados por `oracle-dataguard-analyst` — lag de aplicación (apply lag) nunca se
atribuye a la red sin evidencia de transport lag específica (`# 48`).

## Sanitización

Direcciones IP/MAC → `TOKENIZE` por defecto (`# 35` del prompt: "No exponer IP real si policy
requiere tokenización"). Hostnames → `MASK`.

## Manual remediation

Cualquier cambio de bond/VLAN/MTU/ruta/firewall/DNS queda bajo "MANUAL NETWORK/OS ADMIN ACTION",
siempre `NOT_EXECUTED` (`# 64` del prompt).
