# Tests — oracle-performance-analyst

Los tests ejecutables viven en el directorio global `tests/` del repositorio (convención de todo el e-stack — ver `tests/run-all.sh`, que recorre `tests/test_*.sh` de forma plana). Esta carpeta existe como referencia de qué tests validan específicamente el contrato de este agente — no duplica scripts.

## Contrato del agente (`# 32 AGENT TESTS`)

- `tests/test_performance_agent_manifest.sh` — valida `../manifest.yaml`.
- `tests/test_performance_agent_routing.sh` — valida `../routing.yaml`.
- `tests/test_performance_agent_context_policy.sh` — valida `../context-policy.yaml`.
- `tests/test_performance_agent_collaboration.sh` — valida `../collaboration.yaml`.
- `tests/test_performance_agent_output_schema.sh` — valida `../output-schema.yaml`.
- `tests/test_performance_agent_no_execution_capability.sh` — valida que el agente nunca declare capacidad de ejecución/escritura.
- `tests/test_performance_agent_no_delegation_loop.sh` — valida que `must_not_delegate_to` se respete y no exista ciclo de delegación.

## Tests generales de Fase 3 que también cubren a este agente

Ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#security-validation` y `docs/PHASE_3_COMPLETION_HARDENING.md#test-results` para la lista completa (Licensing Gate, SQL text policy, parsers, Statspack, portabilidad).
