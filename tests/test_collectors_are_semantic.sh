#!/usr/bin/env bash
# Valida que cada collector de docs/GI_READONLY_COLLECTORS.md mapea a un comando semántico
# específico, no a un parámetro de comando libre.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/GI_READONLY_COLLECTORS.md"

for cid in get_cluster_nodes get_cluster_resources get_cluster_version get_scan_configuration \
           get_vip_configuration get_service_configuration get_listener_configuration \
           get_network_configuration get_ocr_status get_voting_status; do
  if grep -q "\`$cid\`" "$DOC"; then
    echo "[PASS] $cid documentado en el catálogo de collectors"
  else
    echo "[FAIL] $cid no está documentado en $DOC"
    FAIL=1
  fi
done

exit $FAIL
