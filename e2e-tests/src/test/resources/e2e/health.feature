Feature: Suite de Humo — Disponibilidad de los 8 microservicios

  Verifica que cada servicio responde sin errores 5xx.
  Acepta 401/403 (autenticación requerida) como prueba de que el servicio está vivo.

  Scenario: notification-service responde
    Given url baseUrlNotification
    And path '/api/v1/notifications'
    When method GET
    Then assert responseStatus < 500

  Scenario: identity-service responde
    Given url baseUrlIdentity
    And path '/api/v1/identities/lookup/00000000-0000-0000-0000-000000000000'
    When method GET
    Then assert responseStatus < 500

  Scenario: dashboard-service responde
    Given url baseUrlDashboard
    And path '/api/v1/analytics/summary'
    When method GET
    Then assert responseStatus < 500

  Scenario: file-service responde
    Given url baseUrlFile
    And path '/api/v1/files'
    When method GET
    Then assert responseStatus < 500

  Scenario: form-service responde
    Given url baseUrlForm
    And path '/api/v1/questionnaires'
    When method GET
    Then assert responseStatus < 500

  Scenario: gateway-service responde
    Given url baseUrlGateway
    And path '/api/v1/gate/health'
    When method GET
    Then assert responseStatus < 500

  Scenario: promotion-service responde
    Given url baseUrlPromotion
    And path '/api/v1/health/status/ping'
    When method GET
    Then assert responseStatus < 500

  Scenario: auth-service responde
    Given url baseUrlAuth
    And path '/api/v1/auth/login'
    And request { username: 'probe', password: 'probe' }
    When method POST
    # 401 = servicio vivo (creds incorrectas esperadas), 200 = OK también
    Then assert responseStatus == 200 || responseStatus == 401
