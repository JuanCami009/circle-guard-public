Feature: Journey B — Riesgo de salud bloquea el acceso (RED)

  Flujo completo cross-service: auth → form (síntomas) → promotion (Kafka → SUSPECT) → gateway (RED)
  Verifica que declarar síntomas resulta en acceso denegado al campus.

  Background:
    * def authCtx = getAuthContext()
    * def skipJourney = authCtx == null
    * if (skipJourney) karate.log('[SKIP] Journey B: no hay contexto autenticado (TEST_JWT/E2E_USERNAME no configurados)')

  Scenario: Usuario con fiebre es marcado SUSPECT y se le niega el acceso
    * if (skipJourney) karate.abort()
    * def jwt = authCtx.jwt
    * def anonId = authCtx.anonId

    # Paso 1 — Enviar encuesta con síntomas (fiebre) → promotion promoverá a SUSPECT vía Kafka
    Given url baseUrlForm
    And path '/api/v1/surveys'
    And header Authorization = 'Bearer ' + jwt
    And request
      """
      {
        "anonymousId": "#(anonId)",
        "hasFever": true,
        "hasCough": false,
        "otherSymptoms": "e2e-test-risk",
        "responses": {}
      }
      """
    When method POST
    Then assert responseStatus == 200 || responseStatus == 201

    # Paso 2 — Esperar a que promotion-service cambie el estado a SUSPECT vía Kafka
    * configure retry = { count: 15, interval: 2500 }
    Given url baseUrlPromotion
    And path '/api/v1/health/status/' + anonId
    And header Authorization = 'Bearer ' + jwt
    When method GET
    And retry until responseStatus == 200 && (response.status == 'SUSPECT' || response.status == 'PROBABLE' || response.status == 'CONFIRMED')

    Then status 200
    * def riskStatus = response.status
    * karate.log('Estado de salud con riesgo: ' + riskStatus)
    * assert riskStatus == 'SUSPECT' || riskStatus == 'PROBABLE' || riskStatus == 'CONFIRMED'

    # Paso 3 — Generar QR token (el token se genera aunque el estado sea de riesgo)
    Given url baseUrlAuth
    And path '/api/v1/auth/qr/generate'
    And header Authorization = 'Bearer ' + jwt
    When method GET
    Then status 200
    And match response.qrToken == '#notnull'
    * def qrToken = response.qrToken

    # Paso 4 — Validar QR en el gateway (debe ser RED — acceso denegado)
    Given url baseUrlGateway
    And path '/api/v1/gate/validate'
    And request { token: '#(qrToken)' }
    When method POST
    Then status 200
    And match response.valid == false
    And match response.status == 'RED'
    * karate.log('Acceso denegado: ' + response.message)
