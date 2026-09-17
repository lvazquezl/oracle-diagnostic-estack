# Capacity VMware Model — Fase 10

## Alcance

vCPU, memoria asignada, capacidad del host, capacidad de datastore, asignación por VM, awareness
de oversubscription (`# 576`-`# 589` del prompt de Fase 10). **Nunca realiza cambios de VM.**

## Estado en Fase 10 (MVP)

Contract diseñado (`skills/capacity/vmware/SKILL.md`), sin collector runtime certificado en esta
fase — fuente `NOT_CERTIFIED` por defecto, disponible sólo vía `MANUAL_IMPORT` cuando el DBA/
equipo de virtualización aporte datos exportados.

## Prohibiciones

```text
resize de VM (vCPU/memoria)
cambio de reservations/limits/shares
modificación de asignación de recursos VMware de cualquier tipo
```

## Output

```yaml
vmware_capacity:
  status: NOT_CERTIFIED|MANUAL_IMPORT|CONNECTED
  vcpu_allocated:
  memory_allocated:
  host_capacity:
  datastore_capacity:
  vm_allocation: [...]
  oversubscription_ratio_cpu:
  oversubscription_ratio_memory:
```

## Referencias

`skills/capacity/vmware/SKILL.md`, `docs/CAPACITY_DATA_SOURCE_MODEL.md`.
