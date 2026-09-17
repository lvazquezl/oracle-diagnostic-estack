# Capacity Oracle Model — Fase 10

## Alcance

Database size, tablespaces, datafiles, diskgroups ASM, FRA, crecimiento de archivelog, histórico
AWR/performance cuando esté licenciado, SGA/PGA, awareness de crecimiento de sesión/proceso
(`# 481`-`# 498` del prompt de Fase 10). **Nunca consulta business data.**

## ASM capacity

`TOTAL_MB`, `FREE_MB`, `USABLE_FILE_MB` (métrica correcta de capacidad utilizable, considerando
redundancia), `required_mirror_free_mb` awareness, redundancy awareness. Nunca usar `FREE_MB /
TOTAL_MB` simple cuando `USABLE_FILE_MB` es la métrica correcta (`# 501`-`# 519` del prompt). Ver
`skills/capacity/asm/SKILL.md`.

## Tablespace capacity

Distingue `allocated`, `maxsize`, `autoextend`, `used`, `free`. Nunca declara capacidad usando
sólo el espacio actualmente asignado si autoextend cambia el techo real (`# 523`-`# 536` del
prompt). Ver `skills/capacity/tablespace/SKILL.md`.

## FRA capacity

Integrado con Fase 7 — `space_limit`, `space_used`, `space_reclaimable`, crecimiento de
archivelog, interacción con retención de backup. Nunca borra/reclaim automáticamente (`# 539`-
`# 554` del prompt).

## Storage layer model (anti double-counting)

```text
physical / datastore
        ↓
volume / filesystem / ASM
        ↓
database logical layer
        ↓
tablespace / datafile
```

Nunca se suman capas lógicas y físicas como si fueran capacidad independiente (`# 463`-`# 479`
del prompt). Ver `skills/capacity/storage/SKILL.md`.

## ASM disk normalization

No se asume universalmente tamaño fijo por disco — si una policy/fuente específica declara (ej.
"ASM disk unit = 32 GiB"), se trata como configuración del target/source, nunca como regla global
(`# 1442`-`# 1452` del prompt).

## Oracle Target Profile

```yaml
oracle_capacity:
  include_asm:
  include_tablespaces:
  include_fra:
  include_sga_pga:
  include_database_growth:
```

## Referencias

`skills/capacity/oracle/SKILL.md`, `skills/capacity/asm/SKILL.md`,
`skills/capacity/tablespace/SKILL.md`.
