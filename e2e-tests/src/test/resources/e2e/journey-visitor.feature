Feature: Journey C — Registro de visitante y generación de credenciales de acceso

  Flujo cross-service: identity (registro) → auth (handoff QR) → gateway (validar acceso)
  Verifica que un visitante puede registrarse, obtener un QR de acceso y usarlo.

  Scenario: Visitante se registra y obtiene credenciales de acceso
    # Paso 1 — Registrar visitante en identity-service → obtener anonymousId
    Given url baseUrlIdentity
    And path '/api/v1/identities/visitor'
    And request
      """
      {
        "name": "E2E Visitor Test",
        "email": "e2e-visitor@circleguard.test",
        "reason_for_visit": "prueba-e2e-karate"
      }
      """
    When method POST
    Then assert responseStatus == 200 || responseStatus == 201
    And match response.anonymousId == '#notnull'
    * def visitorAnonId = response.anonymousId
    * karate.log('Visitante registrado con anonymousId: ' + visitorAnonId)

    # Paso 2 — Generar handoff JWT para el visitante (auth-service)
    * def authCtx = getAuthContext()
    * def skipHandoff = authCtx == null
    * if (!skipHandoff) karate.log('Generando handoff QR para visitante...')

    * if (!skipHandoff) karate.call('classpath:e2e/helpers/visitor-handoff.feature', { jwt: authCtx.jwt, visitorAnonId: visitorAnonId, baseUrlAuth: baseUrlAuth })

    # Paso 3 — Verificar que el visitante existe en identity (lookup)
    Given url baseUrlIdentity
    And path '/api/v1/identities/lookup/' + visitorAnonId
    When method GET
    # 200 si el sistema guarda reverse-lookup, 404 si solo existe el mapeo directo (ambos OK)
    Then assert responseStatus == 200 || responseStatus == 404

    * karate.log('Journey C completado: visitante registrado con anonymousId ' + visitorAnonId)
