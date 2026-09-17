# Capacity Horizontal / Vertical Model — Fase 10

## Horizontal

```text
add nodes
add VMs
add instances
add storage devices
scale-out topology
```

Sólo como análisis/recomendación — nunca se ejecuta scale-out (`# 610`-`# 625` del prompt de
Fase 10).

## Vertical

```text
increase CPU
increase memory
increase storage
increase VM allocation
increase database storage ceiling
```

Sólo como análisis/recomendación (`# 628`-`# 641` del prompt).

## Decision model

No se recomienda horizontal/vertical sólo por porcentaje de utilización. Factores considerados:

```text
current topology
resource bottleneck
growth rate
platform limits
licensing impact
HA architecture
RAC architecture
virtualization
operational complexity
cost-awareness
```

Si la evidencia es insuficiente → `INSUFFICIENT_EVIDENCE` (`# 644`-`# 667` del prompt).

## Referencias

`skills/capacity/horizontal/SKILL.md`, `skills/capacity/vertical/SKILL.md`,
`skills/capacity/manual-capacity-plan/SKILL.md`.
