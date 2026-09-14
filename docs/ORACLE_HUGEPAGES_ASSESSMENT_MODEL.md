# Oracle HugePages Assessment Model — Fase 9

## Principio

`os/hugepages` calcula si HugePages están correctamente dimensionadas para la **SGA total del
host** (todas las bases de datos + overhead ASM/GI cuando aplique), nunca sólo la base de datos
principal (`# 18` del prompt: "Soportar múltiples SGAs por host").

## Fórmula certificada

```text
required_pages = ceil(total_SGA_bytes / hugepage_size_bytes)
```

`total_SGA_bytes` es la **suma** de la SGA de cada instancia/base de datos activa en el host, más
overhead ASM/GI cuando el Target Profile lo declare explícitamente. Sin margen porcentual fijo
salvo policy explícita (`# 17` del prompt: "No inventar porcentaje fijo").

## Múltiples bases de datos

```text
DB1 SGA
DB2 SGA
DB3 SGA
+ overhead ASM/GI (si aplica)
= total_SGA_bytes
```

Nunca calculado usando sólo la instancia principal (`# 18`: "No calcular usando sólo la
principal"). Sin conocer la SGA total completa (alguna instancia sin evidencia) →
`INSUFFICIENT_EVIDENCE`, nunca calculado con una SGA parcial disfrazada de total.

## Cálculo derivado

```text
configured_pages = HugePages_Total
free_pages = HugePages_Free
reserved_pages = HugePages_Rsvd
unused_pages = HugePages_Free - HugePages_Rsvd
shortfall_pages = max(0, required_pages - configured_pages)
```

## Estados

```text
shortfall_pages > 0                                    → HIGH
configured > 0 pero mismatch con USE_LARGE_PAGES        → MEDIUM
configured >= required, uso consistente                  → HEALTHY
SGA total no completamente conocida                        → INSUFFICIENT_EVIDENCE
```

## Transparent HugePages — mecanismo distinto

THP (`os/transparent-hugepages`) es un mecanismo del kernel completamente distinto a HugePages
tradicionales (`vm.nr_hugepages`) — nunca confundidos. THP se evalúa por separado
(`always|madvise|never`) contra la recomendación aplicable citada por versión/plataforma, nunca
una regla universal sin fuente.

## Windows / Large Pages

Windows tiene un mecanismo de Large Pages distinto (`Lock Pages in Memory` privilege +
`use_large_pages` de Oracle) — fuera del alcance de `os/hugepages` (`NOT_APPLICABLE` en Windows),
awareness documentada aquí para no confundir ambos modelos.

## Manual remediation

`manual_action` sugiere `vm.nr_hugepages=<required_pages>` — siempre `NOT_EXECUTED`,
`reboot_required` declarado honestamente (frecuentemente requiere reinicio en producción para
garantizar contigüidad de memoria).
