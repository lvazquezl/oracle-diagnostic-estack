# Capacity Manual Action Model — Fase 10

## Principio

Toda recomendación operativa del dominio capacity es un `manual_action` — nunca ejecutado por el
e-stack (`# 1831`-`# 1849` del prompt de Fase 10).

## Manual Action Contract

```yaml
manual_action:
  action_id: string
  target: string
  resource: string
  reason: string
  forecast_horizon: 1|3|6|null
  trigger: string
  recommended_capacity: string|null
  owner_role: string
  prechecks: [string]
  risk: string
  rollback_or_contingency: string
  execution_status: NOT_EXECUTED
```

`execution_status: NOT_EXECUTED` es un campo fijo, nunca condicional.

## Recommended capacity

No se dimensiona únicamente "hasta quedar por debajo del threshold". Policy:

```yaml
capacity:
  target_headroom_percent:
```

El cálculo siempre se explica (`# 1853`-`# 1864` del prompt).

## Licensing / cost awareness

Cuando aplique (Oracle licensing, VMware licensing, cloud/infra cost), aparece como
`REQUIRES_REVIEW` si no hay datos suficientes — nunca se calculan costos inventados (`# 1868`-
`# 1886` del prompt).

## Categorías de safety

```text
No resize VM
No add CPU/memory
No extend filesystem/ASM diskgroup
No add ASM disk
No ALTER TABLESPACE / CREATE DATAFILE
No modify VMware allocation
No change database parameters
No change OS resource controls
No modify monitoring tools
```

Cada `manual_action` declara su categoría explícitamente — nunca genérica.

## Verificado por tests

`test_no_vm_resize.sh`, `test_no_storage_extension.sh`, `test_no_asm_add_disk.sh`,
`test_no_tablespace_extend.sh`, `test_no_monitoring_mutation.sh`, `test_no_arbitrary_sql.sh`,
`test_no_arbitrary_shell.sh`, `test_capacity_read_only.sh`.

## Referencias

`skills/capacity/manual-capacity-plan/SKILL.md`, `skills/capacity/horizontal/SKILL.md`,
`skills/capacity/vertical/SKILL.md`.
