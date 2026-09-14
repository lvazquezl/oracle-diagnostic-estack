# OS Storage & Filesystem Model — Fase 9

## Principio

Visibilidad de filesystem/inodes/mount options/block devices/multipath/I/O — nunca ejecuta
mount/unmount, nunca modifica LVM/ZFS/VxVM, nunca reconfigura multipath.

## Filesystem

`os/filesystems` correlaciona cada mount con su rol Oracle cuando identificable (binarios,
`diagnostic_dest`, FRA, backups, logs, wallet) — el umbral de severidad depende del rol, nunca
uniforme (`# 29` del prompt).

## Inodes — escenario distinto de capacidad

`os/inodes` detecta escenarios de muchos archivos pequeños (trace/log/archivelog fragmentado) que
agotan inodes antes que el espacio en bytes — reportado independientemente del hallazgo de
capacidad, nunca asumido cubierto por ese chequeo (`# 30` del prompt). Filesystems sin modelo de
inodes fijo (ZFS) → `NOT_APPLICABLE`, nunca un falso positivo/negativo.

## Mount options

`noexec`/`nosuid`/`ro` sólo son `CRITICAL` cuando el mount confirmadamente aloja binarios Oracle
o datafiles activos — nunca declarado como mala configuración sin ese contexto (`# 31` del
prompt).

## Block devices / Multipath

Visibilidad de dispositivo relacionado con ASM — nunca reemplaza a `oracle-asm-storage-analyst`
(diskgroups/redundancia), correlaciona por referencia (`# 32` del prompt). Multipath: sólo si hay
collector certificado disponible; nunca `multipathd reconfigure` (`# 33`).

## I/O performance — nunca util% aislado

`os/io-performance` nunca concluye storage root cause con `util%` aislado — requiere
correlación de latencia + cola + wait events Oracle reportados (`# 34` del prompt).

## RMAN/media manager awareness

`os/rman-media-manager-awareness` correlaciona open files/process limits/filesystem/red con
canales RMAN paralelos y procesos SBT — nunca ejecuta jobs del vendor (`# 49`).

## Security filesystem awareness

`os/security-filesystem-awareness` correlaciona permisos del wallet TDE/binarios Oracle con
`oracle-security-analyst` — nunca lee contenido del wallet, nunca modifica permisos (`# 50`).

## Manual remediation

Cambios de mount/LVM/ZFS/VxVM/multipath quedan siempre `NOT_EXECUTED`, dirigidos al administrador
de storage.
