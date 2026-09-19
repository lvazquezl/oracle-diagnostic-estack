# Tests — technical-documentation-manager

Todos los tests viven en `tests/` (convención del proyecto). Este directorio existe por consistencia estructural con el Agent Contract.

- `tests/test_p12_documentation_factory.sh`
- `tests/test_p12_phase11_integration.sh`
- `tests/test_p12_security_threat_model.sh`
- `tests/test_document_traceability.sh (Foundation)`

Los tests `test_p12_*.sh` son **funcionales**: ejecutan el CLI/API real de `change_documentation_knowledge` sobre fixtures sintéticos y afirman sobre el JSON/Markdown/KB producido.
