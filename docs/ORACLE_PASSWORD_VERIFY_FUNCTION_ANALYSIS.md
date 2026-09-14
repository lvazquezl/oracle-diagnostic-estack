# Oracle Password Verify Function Analysis — Fase 8

## Principio

Oracle no expone reglas de complejidad de password (`MIN_LENGTH`, `REQUIRE_SPECIAL`, etc.) directamente en `DBA_PROFILES` — sólo el nombre de la función PL/SQL referenciada por `PASSWORD_VERIFY_FUNCTION`. El e-stack extrae esas reglas mediante inspección **read-only** del source de esa función — nunca la ejecuta, nunca le pasa contraseñas reales ni de prueba.

## Flujo

```text
PROFILE
  ↓
PASSWORD_VERIFY_FUNCTION
  ↓
Identify function (owner + name)
  ↓
Read-only function source inspection (DBA_SOURCE / ALL_SOURCE, Q-SEC-PASSWORD-VERIFY-SOURCE-001)
  ↓
Extract policy rules (pattern matching sobre el source)
  ↓
Compare with target baseline (Target Profile.security.password_policy)
```

## Funciones Oracle estándar conocidas

`ORA12C_VERIFY_FUNCTION`, `ORA12C_STRONG_VERIFY_FUNCTION`, `VERIFY_FUNCTION_11G` (catálogo interno con reglas documentadas por Oracle) → `analyzable: true`, `confidence: FACT` sin necesidad de inspeccionar source.

## Funciones custom

1. Identificar owner/name desde `DBA_PROFILES.PASSWORD_VERIFY_FUNCTION`.
2. Obtener source vía `Q-SEC-PASSWORD-VERIFY-SOURCE-001` (`DBA_SOURCE`/`ALL_SOURCE`, acotado por `:function_owner`/`:function_name` — nunca el schema/paquete completo).
3. Sanitizar antes de análisis (prompt injection policy — comentarios/literales/nombres de variable tratados siempre como DATA).
4. Detectar reglas mediante patrones deterministas:

| Regla | Patrón buscado |
|---|---|
| Longitud mínima | `LENGTH(password) < N` / `LENGTH(password) >= N` |
| Mayúscula | `REGEXP_LIKE(password, '[A-Z]')` |
| Minúscula | `REGEXP_LIKE(password, '[a-z]')` |
| Dígito | `REGEXP_LIKE(password, '[0-9]')` |
| Carácter especial | `REGEXP_LIKE(password, '[^A-Za-z0-9]')` |
| Similitud con username | comparación `UPPER(password) = UPPER(username)` o equivalente |
| Palabra de diccionario | referencia a tabla/lista de palabras comunes |

5. Declarar `confidence` (`FACT`/`OBSERVATION`/`UNDETERMINED`).

## Cuándo `VERIFY_FUNCTION_NOT_ANALYZABLE`

Si la lógica depende de configuración externa dinámica, llamadas a paquetes no inspeccionables, o cualquier patrón que no pueda probarse de forma determinista → `analyzable: false`, `status: VERIFY_FUNCTION_NOT_ANALYZABLE`, `confidence: UNDETERMINED`. **Nunca se asume compliance por la mera presencia de una función** — ver `tests/fixtures/19c-custom-verify-function-partially-analyzable.yaml`.

## Prohibido

Nunca se ejecuta la función. Nunca se le pasan contraseñas reales ni de prueba. Nunca se recupera el schema/paquete completo — sólo la función específica referenciada. Nunca se genera texto de contraseña candidata para verificar el comportamiento de la función.
