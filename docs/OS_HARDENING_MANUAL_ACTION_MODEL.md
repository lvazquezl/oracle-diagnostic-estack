# OS Hardening Manual Action Model — Fase 9

## Principio

Toda recomendación operativa del dominio OS es un `manual_action` — nunca ejecutado por el
e-stack, siempre dirigido a un administrador OS/red/storage/Windows autorizado.

## Manual Action Contract

```yaml
manual_action:
  action_id: string
  purpose: string
  owner_role: string
  platform: string
  command: string|null
  config_file: string|null
  prechecks: [string]
  expected_result: string
  risk: string
  rollback: string
  postchecks: [string]
  reboot_required: bool
  execution_status: NOT_EXECUTED
```

`execution_status: NOT_EXECUTED` es un campo fijo, nunca condicional (`# 61` del prompt).

## Categorías de safety (`# 62`-`# 65` del prompt)

```text
sysctl -w ...                          → MANUAL OS ADMIN ACTION
limits.conf / systemd unit overrides    → procedimiento manual
bond/VLAN/MTU/route/firewall/DNS         → MANUAL NETWORK/OS ADMIN ACTION
registry/servicio/pagefile/firewall/adaptador Windows → sólo manual
```

Cada `manual_action` declara su categoría explícitamente — nunca genérica.

## reboot_required — honestidad obligatoria

HugePages/kernel boot args (THP) frecuentemente requieren reinicio para garantía real
(contigüidad de memoria, boot params) — `reboot_required` se declara honestamente, nunca se
afirma "aplica en caliente" sin esa certeza.

## Nunca ejecutado bajo ninguna circunstancia

`os/manual-hardening-plan` es el único skill que redacta estos procedimientos — nunca los
ejecuta. Ningún `command`/`config_file` se interpola en una llamada real; se presentan como
texto para lectura humana.

## Manual Collection Contract (PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH
HARDENING)

Distinto de `manual_action` (que propone un *cambio*): `manual_collection` propone la
**obtención** de evidencia que el e-stack no pudo leer por permisos insuficientes — nunca
escalamiento de privilegios (`sudo`/`su`/`runuser`) como acción del e-stack, sólo la instrucción
para que un administrador autorizado ejecute el comando y entregue la salida.

```yaml
manual_collection:
  owner_role: OS_ADMIN
  purpose: string
  command: string
  expected_output: string
  sanitization: string
  execution_status: NOT_EXECUTED
```

Se genera típicamente cuando `get_process_effective_limits(pid)` no es legible con la identidad
diagnóstica de sólo lectura (`collection_status: INSUFFICIENT_PRIVILEGES`, ver
`os/process-limits`) — nunca se sustituye silenciosamente por el `ulimit` del usuario de
diagnóstico ni por ningún valor inferido.

## Verificado por tests

`test_no_sysctl_execution.sh`, `test_no_limits_change_execution.sh`,
`test_no_network_change_execution.sh`, `test_no_mount_execution.sh`,
`test_no_storage_change_execution.sh`, `test_no_sshd_change_execution.sh`,
`test_no_group_change_execution.sh` — verifican que ningún artefacto del dominio OS declara
capacidad real de ejecutar estas acciones. `test_process_limits_insufficient_privileges.sh`,
`test_process_limits_manual_collection_fallback.sh`, `test_process_limits_no_sudo_fallback.sh` —
verifican el fallback `manual_collection` sin escalamiento de privilegios.
