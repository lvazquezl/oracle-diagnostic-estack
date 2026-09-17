# Capacity OS Model — Fase 10

## Principio

Integra Fase 9 (OS Platform Diagnostics & Hardening) para CPU, memoria, swap, filesystems,
inodes, process constraints — **nunca duplica collectors**, consume evidencia por referencia
(`# 557`-`# 573` del prompt de Fase 10).

## CPU capacity

Allocated, effective, used, peak, average, p95, p99 cuando justificado. Nunca un único pico
puntual como baseline (`# 410`-`# 425` del prompt). Ver `skills/capacity/cpu/SKILL.md`.

## Memory capacity

Physical/allocated, used, available, working-set equivalente, awareness de presión swap/pagefile,
contexto SGA/PGA de Oracle, asignación de memoria VM. **Nunca trata el page cache de Linux como
consumo irreclamable** (`# 428`-`# 443` del prompt). Ver `skills/capacity/memory/SKILL.md`.

## Linux

`SUPPORTED` — reutiliza `os/cpu-topology`, `os/memory`, `os/swap`, `os/filesystems`, `os/inodes`,
`os/process-limits` (Fase 9). Ver `skills/capacity/linux/SKILL.md`.

## Windows Server

`PARTIALLY_SUPPORTED` — reutiliza evidencia Windows de `os-platform-analyst` (collectors WMI
`DOCUMENTATION_VALIDATED`, Fase 9); `ulimits`/`hugepages`/`aio` `NOT_APPLICABLE`, consistente con
Fase 9. Ver `skills/capacity/windows/SKILL.md`.

## Reutilización de collectors

Ningún collector nuevo se crea en Fase 10 para CPU/memoria/swap/filesystems/inodes/process
limits — todos provienen de `docs/OS_READONLY_COLLECTOR_MODEL.md` (Fase 9), consumidos por
`evidence_refs`.

## Referencias

`skills/capacity/os/SKILL.md`, `skills/capacity/linux/SKILL.md`,
`skills/capacity/windows/SKILL.md`, `docs/OS_READONLY_COLLECTOR_MODEL.md` (Fase 9).
