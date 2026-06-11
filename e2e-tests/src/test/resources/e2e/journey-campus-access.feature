Feature: Journey A — Acceso a campus (usuario sin síntomas obtiene GREEN)

  Flujo completo cross-service: auth → form → promotion (vía Kafka) → gateway
  Verifica que un usuario sano puede generar un QR válido y pasar la validación de acceso.

  Background:
    * def authCtx = getAuthContext()
    * def skipJourney = authCtx == null
    * if (skipJourney) karate.log('[SKIP] Journey A: no hay contexto autenticado (TEST_JWT/E2E_USERNAME no configurados)')

  Scenario: Usuario sin síntomas obtiene acceso GREEN al campus
    * if (skipJourney) karate.abort()
    * def jwt = authCtx.jwt
    * def anonId = authCtx.anonId

    # Paso 1 — Enviar encuesta de salud sin síntomas
    Given url baseUrlForm
    And path '/api/v1/surveys'
    And header Authorization = 'Bearer ' + jwt
    And request
      """
      {
        "anonymousId": "#(anonId)",
        "hasFever": false,
        "hasCough": false,
        "otherSymptoms": "",
        "responses": {}
      }
      """
    When method POST
    Then assert responseStatus == 200 || responseStatus == 201

    # Paso 2 — Esperar a que promotion-service procese el evento Kafka y actualice el estado
    * configure retry = { count: 12, interval: 2500 }
    Given url baseUrlPromotion
    And path '/api/v1/health/status/' + anonId
    And header Authorization = 'Bearer ' + jwt
    When method GET
    # Reintentar hasta que el estado no sea SUSPECT/PROBABLE/CONFIRMED
    And retry until responseStatus != 404 && response.status != 'SUSPECT' && response.status != 'PROBABLE' && response.status != 'CONFIRMED'

    Then assert responseStatus == 200
    * def healthStatus = response.status
    * karate.log('Estado de salud tras encuesta: ' + healthStatus)

    # Paso 3 — Generar QR token para acceso
    Given url baseUrlAuth
    And path '/api/v1/auth/qr/generate'
    And header Authorization = 'Bearer ' + jwt
    When method GET
    Then status 200
    And match response.qrToken == '#notnull'
    * def qrToken = response.qrToken

    # Paso 4 — Validar QR en el gateway (debe ser GREEN)
    Given url baseUrlGateway
    And path '/api/v1/gate/validate'
    And request { token: '#(qrToken)' }
    When method POST
    Then status 200
    And match response.valid == true
    And match response.status == 'GREEN'
    * karate.log('Acceso al campus: ' + response.message)
