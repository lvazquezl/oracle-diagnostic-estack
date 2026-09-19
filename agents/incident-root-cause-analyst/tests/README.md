# Tests — incident-root-cause-analyst

Ver `tests/test_incident_*.sh`, `tests/test_no_session_kill.sh`,
`tests/test_no_process_kill.sh`, `tests/test_no_restart_execution.sh`,
`tests/test_no_failover_execution.sh`, `tests/test_no_switchover_execution.sh`,
`tests/test_no_parameter_change.sh`, `tests/test_temporal_proximity_not_causation.sh`,
`tests/test_change_correlation_not_causation.sh`, `tests/test_recovery_action_not_root_cause.sh`,
`tests/test_symptom_not_root_cause.sh` en la raíz del repositorio (convención del proyecto: todos
los tests viven en `tests/`, no por agente). Este directorio existe por consistencia estructural
con el Agent Contract (mismo patrón que `agents/capacity-analyst/tests/README.md`).
