# Tests — oracle-dataguard-analyst

Los tests reales viven en el `tests/` plano de nivel repositorio (convención de glob de `tests/run-all.sh`), no dentro de esta carpeta — mismo patrón que `agents/oracle-rac-analyst/tests/README.md`.

Tests de contrato de este agente: `tests/test_dataguard_agent_manifest.sh`, `tests/test_dataguard_agent_routing.sh`, `tests/test_dataguard_agent_no_execution_capability.sh`, `tests/test_dataguard_agent_no_delegation_loop.sh`.

Tests de dominio (rol/transporte/apply/lag/gaps/SRL/Broker/readiness): ver `docs/PHASE_5_ORACLE_DATAGUARD.md#test-results`.
