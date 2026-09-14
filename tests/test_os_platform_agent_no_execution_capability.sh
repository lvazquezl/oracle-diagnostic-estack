#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING. Valida que
# agents/os-platform-analyst/manifest.yaml prohíbe explícitamente todas las capacidades de
# mutación del dominio OS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
M="$ROOT/agents/os-platform-analyst/manifest.yaml"

for cap in "shell arbitrario" "PowerShell arbitrario" "lector de archivo genérico" "root/sudo/privileged shell" "sysctl -w" "limits.conf" "instalación de paquetes" "reinicio/start/stop de servicios" "interfaz de red/bonding/VLAN/MTU/rutas/firewall/DNS" "mount/unmount" "LVM/ZFS/VxVM" "SELinux/AppArmor" "sshd_config" "usuario/grupo OS" "permisos de archivo" "Windows Registry" "servicio Windows" "CPU affinity" "kernel boot parameters"; do
  grep -qi "$cap" "$M" \
    && echo "[PASS] manifest.yaml prohíbe explícitamente: $cap" \
    || { echo "[FAIL] falta la prohibición explícita: $cap"; FAIL=1; }
done

exit $FAIL
