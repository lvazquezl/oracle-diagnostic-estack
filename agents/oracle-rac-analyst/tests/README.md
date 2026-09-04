# Tests — oracle-rac-analyst

Los tests reales viven en el `tests/` plano de nivel repositorio (convención de glob de `tests/run-all.sh`), no dentro de esta carpeta — mismo patrón que `agents/oracle-performance-analyst/tests/README.md`.

Tests de contrato de este agente: `tests/test_rac_agent_manifest.sh`, `tests/test_rac_agent_routing.sh`, `tests/test_rac_agent_no_execution_capability.sh`, `tests/test_rac_agent_no_delegation_loop.sh`.

Tests de dominio (topología/servicios/load balancing/interconnect/healthcheck): ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#rac-tests`.
